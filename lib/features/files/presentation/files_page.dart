import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../domain/app_file.dart';

const List<String> _folders = <String>['All', 'Documents', 'Images', 'Audio', 'Videos', 'Other'];

String _inferFolder(String? extension) {
  final String ext = (extension ?? '').toLowerCase();
  if (<String>['jpg', 'jpeg', 'png', 'gif', 'heic', 'webp', 'bmp'].contains(ext)) {
    return 'Images';
  }
  if (<String>['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(ext)) {
    return 'Audio';
  }
  if (<String>['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
    return 'Videos';
  }
  if (<String>['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv'].contains(ext)) {
    return 'Documents';
  }
  return 'Other';
}

IconData _iconForFolder(String folder) {
  switch (folder) {
    case 'Images':
      return Icons.image_outlined;
    case 'Audio':
      return Icons.audio_file_outlined;
    case 'Videos':
      return Icons.video_file_outlined;
    case 'Documents':
      return Icons.description_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
  int unitIndex = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
}

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  String _selectedFolder = 'All';
  bool _isPicking = false;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _pickAndUpload() async {
    final String? userId = _userId;
    if (userId == null || _isPicking) {
      return;
    }
    setState(() => _isPicking = true);
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) {
        return;
      }
      for (final PlatformFile file in result.files) {
        if (file.path == null) {
          continue;
        }
        await ref.read(fileRepositoryProvider).addFile(
              userId,
              AppFile(
                id: '',
                name: file.name,
                folder: _inferFolder(file.extension),
                mimeType: file.extension != null ? 'application/${file.extension}' : 'application/octet-stream',
                localPath: file.path!,
                sizeBytes: file.size,
              ),
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.files.length} file(s) added.')),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _toggleFavorite(AppFile file) async {
    try {
      await ref.read(fileRepositoryProvider).toggleFavorite(file.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(AppFile file) async {
    try {
      await ref.read(fileRepositoryProvider).deleteFile(file.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _open(AppFile file) async {
    try {
      final OpenResult result = await OpenFilex.open(file.localPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppFile>> filesAsync = ref.watch(watchFilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Files & Storage')),
      body: filesAsync.when(
        data: (List<AppFile> files) {
          final List<AppFile> filtered = _selectedFolder == 'All'
              ? files
              : files.where((AppFile f) => f.folder == _selectedFolder).toList();

          return Column(
            children: <Widget>[
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _folders.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final String folder = _folders[index];
                    final int count = folder == 'All'
                        ? files.length
                        : files.where((AppFile f) => f.folder == folder).length;
                    return ChoiceChip(
                      label: Text('$folder ($count)'),
                      selected: _selectedFolder == folder,
                      onSelected: (_) => setState(() => _selectedFolder = folder),
                    );
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyStateView(
                        title: 'No files here',
                        message: 'Tap the upload button to add a file from your device.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final AppFile file = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              onTap: () => _open(file),
                              leading: CircleAvatar(child: Icon(_iconForFolder(file.folder))),
                              title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${_formatSize(file.sizeBytes)}'
                                '${file.createdAt != null ? ' · ${DateFormat.MMMd().format(file.createdAt!)}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    icon: Icon(
                                      file.isFavorite ? Icons.star : Icons.star_border,
                                      color: file.isFavorite ? Colors.amber : null,
                                    ),
                                    onPressed: () => _toggleFavorite(file),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(file),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorView(error: error),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isPicking ? null : _pickAndUpload,
        tooltip: 'Upload file',
        child: _isPicking
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.upload_file),
      ),
    );
  }
}
