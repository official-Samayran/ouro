import 'package:hive/hive.dart';
import 'song.dart';

part 'folder.g.dart';

@HiveType(typeId: 1)
class Folder extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String? parentFolderId;
  @HiveField(3)
  final List<Folder> subFolders;
  @HiveField(4)
  final List<Song> songs;

  Folder({
    required this.id,
    required this.name,
    this.parentFolderId,
    List<Folder>? subFolders,
    List<Song>? songs,
  })  : subFolders = subFolders ?? [],
        songs = songs ?? [];

  // Helper to get all songs recursively
  List<Song> getAllSongsRecursively() {
    List<Song> allSongs = List.from(songs);
    for (var folder in subFolders) {
      allSongs.addAll(folder.getAllSongsRecursively());
    }
    return allSongs;
  }
}
