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

  static Future<void> deleteFolderRecursive(String folderId) async {
    final folder = foldersBox.get(folderId);
    if (folder == null || folderId == 'root') return;

    // Remove from parent
    if (folder.parentFolderId != null) {
      final parent = foldersBox.get(folder.parentFolderId);
      if (parent != null) {
        parent.subFolders.removeWhere((f) => f.id == folderId);
        await parent.save();
      }
    }

    // Recursively delete subfolders
    for (var subFolder in List.from(folder.subFolders)) {
      await deleteFolderRecursive(subFolder.id);
    }

    // Finally delete this folder
    await foldersBox.delete(folderId);
  }

  static Future<void> moveSong(
      String songId, String fromFolderId, String toFolderId) async {
    final fromFolder = foldersBox.get(fromFolderId);
    final toFolder = foldersBox.get(toFolderId);

    if (fromFolder != null && toFolder != null) {
      final songIndex = fromFolder.songs.indexWhere((s) => s.id == songId);
      if (songIndex != -1) {
        final song = fromFolder.songs.removeAt(songIndex);
        toFolder.songs.add(song);
        await fromFolder.save();
        await toFolder.save();
      }
    }
  }

  static Future<void> updateFolder(Folder folder) async {
    await foldersBox.put(folder.id, folder);
  }

  static Future<void> renameFolder(String folderId, String newName) async {
    final folder = foldersBox.get(folderId);
    if (folder != null) {
      final updatedFolder = Folder(
        id: folder.id,
        name: newName,
        parentFolderId: folder.parentFolderId,
        subFolders: folder.subFolders,
        songs: folder.songs,
      );
      await foldersBox.put(folderId, updatedFolder);
      
      // Update in parent
      if (folder.parentFolderId != null) {
        final parent = foldersBox.get(folder.parentFolderId);
        if (parent != null) {
          final index = parent.subFolders.indexWhere((f) => f.id == folderId);
          if (index != -1) {
            parent.subFolders[index] = updatedFolder;
            await parent.save();
          }
        }
      }
    }
  }

  static Future<void> moveFolder(String folderId, String toFolderId) async {
    final folder = foldersBox.get(folderId);
    final toFolder = foldersBox.get(toFolderId);

    if (folder != null && toFolder != null && folderId != toFolderId) {
      // Prevent moving to itself or its own children (recursive check simplified for now)
      if (toFolder.id == folderId) return;

      // Remove from old parent
      if (folder.parentFolderId != null) {
        final oldParent = foldersBox.get(folder.parentFolderId);
        if (oldParent != null) {
          oldParent.subFolders.removeWhere((f) => f.id == folderId);
          await oldParent.save();
        }
      }

      // Update folder's parent ID
      final movedFolder = Folder(
        id: folder.id,
        name: folder.name,
        parentFolderId: toFolderId,
        subFolders: folder.subFolders,
        songs: folder.songs,
      );
      await foldersBox.put(folderId, movedFolder);

      // Add to new parent
      toFolder.subFolders.add(movedFolder);
      await toFolder.save();
    }
  }
}
