import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:ytmusicapi_dart/enums.dart' as ytm;
import '../models/song.dart';
import 'package:uuid/uuid.dart';

class MusicService {
  final _yt = YoutubeExplode();
  late Future<YTMusic> _ytMusicFuture;
  final _uuid = Uuid();

  MusicService() {
    _ytMusicFuture = YTMusic.create();
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      final ytMusic = await _ytMusicFuture;
      final results = await ytMusic.search(query, filter: ytm.SearchFilter.songs);
      return results.map((item) {
        final data = item as Map<String, dynamic>;
        return Song(
          id: _uuid.v4(),
          title: data['title'] ?? 'Unknown',
          artist: (data['artists'] != null && (data['artists'] as List).isNotEmpty) 
              ? (data['artists'] as List).first['name'] ?? 'Unknown' 
              : 'Unknown',
          thumbnailUrl: (data['thumbnails'] != null && (data['thumbnails'] as List).isNotEmpty) 
              ? (data['thumbnails'] as List).last['url'] ?? '' 
              : '',
          durationSeconds: data['duration_seconds'] ?? 0,
          youtubeId: data['videoId'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  Future<String?> getStreamUrl(String youtubeId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(youtubeId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      print('Stream extraction error: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
    _ytMusicFuture.then((yt) => yt.close());
  }
}
