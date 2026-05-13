import 'package:hive_flutter/hive_flutter.dart';
import '../models/song.dart';
import '../models/folder.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const String foldersBoxName = 'folders';
  static const String songsBoxName = 'songs';

  static Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    // Register Adapters
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(FolderAdapter());

    // Open Boxes
    await Hive.openBox<Folder>(foldersBoxName);
    await Hive.openBox<Song>(songsBoxName);
    
    // Ensure Root Folder exists
    final folderBox = Hive.box<Folder>(foldersBoxName);
    if (folderBox.isEmpty) {
      await folderBox.put('root', Folder(id: 'root', name: 'Origin'));
    }
  }

  static Box<Folder> get foldersBox => Hive.box<Folder>(foldersBoxName);
  static Box<Song> get songsBox => Hive.box<Song>(songsBoxName);

  static Future<void> addFolder(Folder folder) async {
    await foldersBox.put(folder.id, folder);
    if (folder.parentFolderId != null) {
      final parent = foldersBox.get(folder.parentFolderId);
      if (parent != null) {
        parent.subFolders.add(folder);
        await parent.save();
      }
    }
  }

  static Future<void> addSongToFolder(Song song, String folderId) async {
    final folder = foldersBox.get(folderId);
    if (folder != null) {
      folder.songs.add(song);
      await folder.save();
    }
  }
}
