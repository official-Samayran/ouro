import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../models/folder.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/storage_service.dart';
import '../../services/wormhole_service.dart';
import 'breadcrumb_navigator.dart';
import '../theme.dart';

final destinationFolderProvider = StateProvider<String?>((ref) => null);

class FolderView extends ConsumerStatefulWidget {
  final Folder folder;
  final List<Folder> path;

  const FolderView({super.key, required this.folder, required this.path});

  @override
  ConsumerState<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends ConsumerState<FolderView> {
  void _createOrbit() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        title: const Text('Create New Orbit', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Orbit Name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newFolder = Folder(
                  id: const Uuid().v4(),
                  name: controller.text,
                  parentFolderId: widget.folder.id,
                );
                await StorageService.addFolder(newFolder);
                widget.folder.subFolders.add(newFolder);
                setState(() {}); // Refresh view
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _renameOrbit(Folder folder) {
    final TextEditingController controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        title: const Text('Rename Orbit', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'New Name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await StorageService.renameFolder(folder.id, controller.text);
                final index = widget.folder.subFolders.indexWhere((f) => f.id == folder.id);
                if (index != -1) {
                  widget.folder.subFolders[index] = Folder(
                    id: folder.id,
                    name: controller.text,
                    parentFolderId: folder.parentFolderId,
                    subFolders: folder.subFolders,
                    songs: folder.songs,
                  );
                }
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destId = ref.watch(destinationFolderProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            floating: true,
            pinned: true,
            elevation: 0,
            title: BreadcrumbNavigator(
              currentFolderId: widget.folder.id,
              onFolderTap: (id) {
                if (id == widget.folder.id) return;
                // Navigation handled by popping or pushing
                // For simplicity in this widget, we just use Navigator
                final targetFolder = StorageService.foldersBox.get(id);
                if (targetFolder != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderView(
                        folder: targetFolder,
                        path: [], // Path will be reconstructed in BreadcrumbNavigator
                      ),
                    ),
                  );
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shuffle, color: Colors.white),
                onPressed: () {
                  ref.read(playerProvider.notifier).playFolderRecursive(widget.folder);
                },
              ),
            ],
          ),
          
          if (destId != null && destId != widget.folder.id)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.move_to_inbox, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Move songs here?')),
                    TextButton(
                      onPressed: () => ref.read(destinationFolderProvider.notifier).state = null,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < widget.folder.subFolders.length) {
                  final subFolder = widget.folder.subFolders[index];
                  return _buildFolderItem(subFolder);
                } else {
                  final songIndex = index - widget.folder.subFolders.length;
                  final song = widget.folder.songs[songIndex];
                  return _buildSongItem(song);
                }
              },
              childCount: widget.folder.subFolders.length + widget.folder.songs.length,
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createOrbit,
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
      ).animate().scale(delay: 400.ms, duration: 600.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildFolderItem(Folder folder) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: Colors.white70),
        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${folder.totalSongsCount} songs', style: const TextStyle(fontSize: 12, color: Colors.white38)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderView(
                folder: folder,
                path: [...widget.path, folder],
              ),
            ),
          );
        },
        onLongPress: () {
          _showFolderMenu(folder);
        },
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSongItem(Song song) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          song.thumbnailUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      onTap: () => ref.read(playerProvider.notifier).playFolderRecursive(widget.folder, initialSong: song),
      onLongPress: () {
        _showSongMenu(song);
      },
    );
  }

  void _showFolderMenu(Folder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (folder.id != 'root')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Orbit'),
                onTap: () {
                  Navigator.pop(context);
                  _renameOrbit(folder);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Generate Wormhole'),
              onTap: () {
                Navigator.pop(context);
                WormholeService.shareFolder(folder);
              },
            ),
            if (folder.id != 'root')
              ListTile(
                leading: const Icon(Icons.move_to_inbox),
                title: const Text('Set as Destination'),
                onTap: () {
                  ref.read(destinationFolderProvider.notifier).state = folder.id;
                  Navigator.pop(context);
                },
              ),
            if (folder.id != 'root')
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Orbit', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await StorageService.deleteFolderRecursive(folder.id);
                  setState(() {});
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSongMenu(Song song) {
    final destId = ref.read(destinationFolderProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (destId != null && destId != widget.folder.id)
              ListTile(
                leading: const Icon(Icons.move_to_inbox),
                title: const Text('Move to Destination'),
                onTap: () async {
                  await StorageService.moveSong(song.id, widget.folder.id, destId);
                  setState(() {});
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove from Orbit'),
              onTap: () {
                // TODO: Implement remove song from folder
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
