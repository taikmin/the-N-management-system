import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/file_attachment.dart';
import '../providers/file_provider.dart';
import '../utils/file_downloader.dart';

/// 재사용 가능한 파일 첨부 섹션 위젯
class FileAttachmentSection extends ConsumerStatefulWidget {
  const FileAttachmentSection({
    super.key,
    required this.entityType,
    required this.entityId,
    this.title = '첨부 파일',
    this.compact = false,
  });

  final String entityType;
  final String entityId;
  final String title;
  final bool compact;

  @override
  ConsumerState<FileAttachmentSection> createState() =>
      _FileAttachmentSectionState();
}

class _FileAttachmentSectionState extends ConsumerState<FileAttachmentSection> {
  bool _uploading = false;

  ({String entityType, String entityId}) get _key =>
      (entityType: widget.entityType, entityId: widget.entityId);

  Future<void> _pickAndUpload() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() => _uploading = true);

    try {
      final notifier = ref.read(entityFilesProvider(_key).notifier);
      for (final file in result.files) {
        if (file.bytes == null) continue;
        await notifier.uploadFile(file: file, uploaderId: user.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.files.length}개 파일 업로드 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업로드 오류: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _downloadFile(FileAttachment file) async {
    try {
      final notifier = ref.read(entityFilesProvider(_key).notifier);

      if (kIsWeb) {
        // 웹: 바이트 다운로드 → Blob → 원본 파일명으로 저장
        final bytes = await notifier.downloadBytes(file);
        await saveFileToDevice(bytes: bytes, fileName: file.fileName);
      } else {
        // 기타 플랫폼: Signed URL로 외부 앱에서 열기
        final url = await notifier.getDownloadUrl(file);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${file.fileName} 다운로드 완료')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('다운로드 오류: $e')));
      }
    }
  }

  Future<void> _deleteFile(FileAttachment file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('${file.fileName}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(entityFilesProvider(_key).notifier).deleteFile(file);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일이 삭제되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 오류: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(entityFilesProvider(_key));
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              widget.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_uploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('업로드'),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),

        // 파일 목록
        filesAsync.when(
          data: (files) {
            if (files.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                child: Text(
                  '첨부 파일이 없습니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            if (widget.compact) {
              return Wrap(
                spacing: AppSizes.xs,
                runSpacing: AppSizes.xs,
                children: files
                    .map(
                      (f) => _CompactFileTile(
                        file: f,
                        onTap: () => _downloadFile(f),
                        onDelete: user != null ? () => _deleteFile(f) : null,
                      ),
                    )
                    .toList(),
              );
            }

            return Column(
              children: files
                  .map(
                    (f) => _FileTile(
                      file: f,
                      onTap: () => _downloadFile(f),
                      onDelete: user != null ? () => _deleteFile(f) : null,
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('파일 로딩 오류: $e'),
        ),
      ],
    );
  }
}

/// 파일 목록 타일
class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onTap, this.onDelete});

  final FileAttachment file;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          _fileIcon(file.extension),
          color: _fileColor(file.extension),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.fileTypeLabel} · ${file.fileSizeDisplay}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 20),
              tooltip: '다운로드',
              onPressed: onTap,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: '삭제',
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 컴팩트 파일 칩
class _CompactFileTile extends StatelessWidget {
  const _CompactFileTile({
    required this.file,
    required this.onTap,
    this.onDelete,
  });

  final FileAttachment file;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        _fileIcon(file.extension),
        size: 16,
        color: _fileColor(file.extension),
      ),
      label: Text(
        file.fileName.length > 20
            ? '${file.fileName.substring(0, 17)}...'
            : file.fileName,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
    );
  }
}

IconData _fileIcon(String ext) {
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'doc':
    case 'docx':
    case 'hwp':
    case 'hwpx':
      return Icons.description;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
      return Icons.image;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip;
    default:
      return Icons.insert_drive_file;
  }
}

Color _fileColor(String ext) {
  switch (ext) {
    case 'pdf':
      return Colors.red;
    case 'doc':
    case 'docx':
      return Colors.blue;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Colors.green;
    case 'ppt':
    case 'pptx':
      return Colors.orange;
    case 'hwp':
    case 'hwpx':
      return Colors.teal;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}
