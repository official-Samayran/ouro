import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

class YoutubeAudioSource extends StreamAudioSource {
  final String videoId;
  final yt_explode.YoutubeExplode _yt = yt_explode.YoutubeExplode();

  YoutubeAudioSource(this.videoId, {super.tag});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final streamInfo = manifest.audioOnly.where((s) => s.container == yt_explode.StreamContainer.mp4).withHighestBitrate()
        ?? manifest.audioOnly.withHighestBitrate();
    
    final stream = _yt.videos.streamsClient.get(streamInfo);
    
    return StreamAudioResponse(
      stream: stream,
      contentLength: streamInfo.size.totalBytes,
      sourceLength: streamInfo.size.totalBytes,
      offset: 0,
      contentType: 'audio/mpeg',
    );
  }
}
