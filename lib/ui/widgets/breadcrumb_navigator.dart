import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/folder.dart';
import '../../services/storage_service.dart';

class BreadcrumbNavigator extends ConsumerWidget {
  final String currentFolderId;
  final Function(String) onFolderTap;

  const BreadcrumbNavigator({
    super.key,
    required this.currentFolderId,
    required this.onFolderTap,
  });

  List<Folder> _getPath() {
    List<Folder> path = [];
    String? nextId = currentFolderId;
    while (nextId != null) {
      final folder = StorageService.foldersBox.get(nextId);
      if (folder != null) {
        path.insert(0, folder);
        nextId = folder.parentFolderId;
      } else {
        break;
      }
    }
    return path;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = _getPath();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: path.length,
        separatorBuilder: (context, index) => const Icon(
          Icons.chevron_right,
          color: Colors.white38,
          size: 16,
        ),
        itemBuilder: (context, index) {
          final folder = path[index];
          final isLast = index == path.length - 1;

          return GestureDetector(
            onTap: () => onFolderTap(folder.id),
            child: Center(
              child: Text(
                folder.name,
                style: TextStyle(
                  color: isLast ? Colors.white : Colors.white60,
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
