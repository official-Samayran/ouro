import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/folder.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';

class FolderView extends ConsumerStatefulWidget {
  final Folder folder;
  final List<Folder> path;

  const FolderView({super.key, required this.folder, required this.path});

  @override
  ConsumerState<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends ConsumerState<FolderView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildBreadcrumbs(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle, color: Colors.white),
            onPressed: () {
              ref.read(playerProvider.notifier).playFolderRecursive(widget.folder);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < widget.folder.subFolders.length) {
                  final subFolder = widget.folder.subFolders[index];
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(subFolder.name),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FolderView(
                            folder: subFolder,
                            path: [...widget.path, subFolder],
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  final songIndex = index - widget.folder.subFolders.length;
                  final song = widget.folder.songs[songIndex];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        song.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    onTap: () {
                      ref.read(playerProvider.notifier).playSong(song);
                    },
                  );
                }
              },
              childCount: widget.folder.subFolders.length + widget.folder.songs.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.path.map((folder) {
          final isLast = folder == widget.folder;
          return Row(
            children: [
              Text(
                folder.name,
                style: TextStyle(
                  color: isLast ? Colors.white : Colors.white54,
                  fontSize: 16,
                ),
              ),
              if (!isLast)
                const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}
