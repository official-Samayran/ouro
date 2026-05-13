import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

class YoutubeExplodeSingleton {
  static final yt_explode.YoutubeExplode instance = yt_explode.YoutubeExplode();
}

class YoutubeAudioSource extends StreamAudioSource {
  final String videoId;
  final yt_explode.YoutubeExplode _yt = YoutubeExplodeSingleton.instance;
  yt_explode.StreamInfo? _streamInfo;

  YoutubeAudioSource(this.videoId, {super.tag});

  Future<void> _ensureInitialized() async {
    try {
      if (_streamInfo != null) return;
      print('OURO [Source]: Initializing manifest for $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      _streamInfo = manifest.audioOnly.where((s) => s.container == yt_explode.StreamContainer.mp4).withHighestBitrate()
          ?? manifest.audioOnly.withHighestBitrate();
      print('OURO [Source]: Manifest initialized.');
    } catch (e) {
      print('OURO [Source]: Initialization error: $e');
      rethrow;
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      print('OURO [Source]: Request received for $videoId (start: $start)');
      await _ensureInitialized();
      final streamInfo = _streamInfo!;
      
      final effectiveStart = start ?? 0;
      final effectiveEnd = end ?? streamInfo.size.totalBytes;
      
      final stream = _yt.videos.streamsClient.get(streamInfo);
      
      Stream<List<int>> byteStream = stream;
      if (effectiveStart > 0) {
        int bytesSkipped = 0;
        byteStream = stream.expand((chunk) {
          if (bytesSkipped >= effectiveStart) return [chunk];
          
          if (bytesSkipped + chunk.length <= effectiveStart) {
            bytesSkipped += chunk.length;
            return [];
          } else {
            final startOffset = effectiveStart - bytesSkipped;
            bytesSkipped = effectiveStart;
            return [chunk.sublist(startOffset)];
          }
        });
      }

      return StreamAudioResponse(
        stream: byteStream,
        contentLength: effectiveEnd - effectiveStart,
        sourceLength: streamInfo.size.totalBytes,
        offset: effectiveStart,
        contentType: streamInfo.container == yt_explode.StreamContainer.mp4 ? 'audio/mp4' : 'audio/webm',
      );
    } catch (e) {
      print('OURO [Source]: Request error: $e');
      rethrow;
    }
  }
}
