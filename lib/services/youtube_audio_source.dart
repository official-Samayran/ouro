import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

class SpoofedClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  static int _counter = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _counter++;
    // Modern Mobile Safari User-Agent to avoid "unknown client" throttling
    request.headers['user-agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';
    
    // Add spoofed IP headers to try and bypass simple IP bans
    final fakeIp = '104.28.${_counter % 255}.${(_counter * 3) % 255}';
    request.headers['X-Forwarded-For'] = fakeIp;
    request.headers['Client-IP'] = fakeIp;
    
    return _inner.send(request);
  }
}

class YoutubeExplodeSingleton {
  static yt_explode.YoutubeExplode instance = _createInstance();
  
  static yt_explode.YoutubeExplode _createInstance() {
    return yt_explode.YoutubeExplode(
      httpClient: yt_explode.YoutubeHttpClient(SpoofedClient())
    );
  }
  
  static final Map<String, yt_explode.StreamManifest> _manifestCache = {};
  static final Map<String, DateTime> _cacheTime = {};

  static Future<yt_explode.StreamManifest> getManifest(String videoId) async {
    final now = DateTime.now();
    if (_manifestCache.containsKey(videoId)) {
      final cachedAt = _cacheTime[videoId]!;
      if (now.difference(cachedAt).inMinutes < 30) {
        print('OURO [Singleton]: Using cached manifest for $videoId');
        return _manifestCache[videoId]!;
      }
    }

    int retryCount = 0;
    while (retryCount < 3) {
      try {
        print('OURO [Singleton]: Fetching manifest for $videoId (Attempt ${retryCount + 1})');
        final manifest = await instance.videos.streamsClient.getManifest(videoId).timeout(
          const Duration(seconds: 30), // Increased to 30s
        );
        
        _manifestCache[videoId] = manifest;
        _cacheTime[videoId] = now;
        
        if (_manifestCache.length > 50) {
          _manifestCache.remove(_manifestCache.keys.first);
          _cacheTime.remove(_cacheTime.keys.first);
        }
        return manifest;
      } catch (e) {
        retryCount++;
        print('OURO [Singleton]: Manifest fetch attempt $retryCount failed: $e');
        if (retryCount >= 3) rethrow;
        await Future.delayed(Duration(seconds: retryCount * 2));
        
        if (retryCount == 2) {
          print('OURO [Singleton]: Refreshing YoutubeExplode client...');
          instance.close();
          instance = _createInstance();
        }
      }
    }
    throw Exception('Failed to fetch manifest after retries');
  }
}

class YoutubeAudioSource extends StreamAudioSource {
  final String videoId;
  yt_explode.StreamInfo? _streamInfo;
  Future<void>? _initFuture;

  YoutubeAudioSource(this.videoId, {super.tag});

  Future<void> _ensureInitialized() {
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<void> _doInitialize() async {
    try {
      final manifest = await YoutubeExplodeSingleton.getManifest(videoId);
      _streamInfo = manifest.audioOnly.where((s) => s.container == yt_explode.StreamContainer.mp4).withHighestBitrate()
          ?? manifest.audioOnly.withHighestBitrate();
      
      if (_streamInfo == null) {
        throw Exception('No audio streams found for $videoId');
      }
    } catch (e) {
      _initFuture = null;
      print('OURO [Source]: Initialization error for $videoId: $e');
      rethrow;
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      print('OURO [Source]: Request for $videoId (offset: $start)');
      await _ensureInitialized().timeout(
        const Duration(seconds: 30), // Increased to 30s
        onTimeout: () => throw TimeoutException('Source initialization timed out'),
      );
      
      final streamInfo = _streamInfo!;
      final effectiveStart = start ?? 0;
      final effectiveEnd = end ?? streamInfo.size.totalBytes;
      
      final stream = YoutubeExplodeSingleton.instance.videos.streamsClient.get(streamInfo);
      
      return StreamAudioResponse(
        stream: stream,
        contentLength: effectiveEnd - effectiveStart,
        sourceLength: streamInfo.size.totalBytes,
        offset: effectiveStart,
        contentType: streamInfo.container == yt_explode.StreamContainer.mp4 ? 'audio/mp4' : 'audio/webm',
      );
    } catch (e) {
      print('OURO [Source]: Request failed for $videoId: $e');
      rethrow;
    }
  }
}
