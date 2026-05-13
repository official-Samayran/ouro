import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String artist;
  @HiveField(3)
  final String thumbnailUrl;
  @HiveField(4)
  final int durationSeconds;
  @HiveField(5)
  final String youtubeId;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.youtubeId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'youtubeId': youtubeId,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        thumbnailUrl: json['thumbnailUrl'],
        durationSeconds: json['durationSeconds'],
        youtubeId: json['youtubeId'],
      );
}
