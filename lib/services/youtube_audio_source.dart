import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

class YoutubeExplodeSingleton {
  static yt_explode.YoutubeExplode instance = yt_explode.YoutubeExplode();
  
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
          const Duration(seconds: 20),
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
        
        // On third attempt, try refreshing the client
        if (retryCount == 2) {
          print('OURO [Singleton]: Refreshing YoutubeExplode client...');
          instance.close();
          instance = yt_explode.YoutubeExplode();
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
        const Duration(seconds: 40),
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
