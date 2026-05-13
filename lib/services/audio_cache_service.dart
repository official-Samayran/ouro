import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import 'youtube_audio_source.dart';

class AudioCacheService {
  static Future<String?> getCachedFile(String youtubeId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$youtubeId.m4a');
    if (await file.exists() && await file.length() > 0) {
      print('OURO [Cache]: Hit for $youtubeId');
      return file.path;
    }
    return null;
  }

  static Future<String?> downloadToCache(String youtubeId) async {
    try {
      final cachedPath = await getCachedFile(youtubeId);
      if (cachedPath != null) return cachedPath;

      print('OURO [Cache]: Downloading $youtubeId...');
      final manifest = await YoutubeExplodeSingleton.getManifest(youtubeId);
      final streamInfo = manifest.audioOnly.where((s) => s.container == yt_explode.StreamContainer.mp4).withHighestBitrate()
          ?? manifest.audioOnly.withHighestBitrate();

      final yt = YoutubeExplodeSingleton.instance;
      final stream = yt.videos.streamsClient.get(streamInfo);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$youtubeId.m4a');
      final fileStream = file.openWrite();

      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      print('OURO [Cache]: Download complete: ${file.path}');
      return file.path;
    } catch (e) {
      print('OURO [Cache]: Download failed: $e');
      return null;
    }
  }
}
