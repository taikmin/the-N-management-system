import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/file_repository.dart';
import '../models/file_attachment.dart';

/// FileRepository Provider
final fileRepositoryProvider =
    Provider<FileRepository>((ref) => FileRepository());

/// 특정 엔티티의 파일 목록 Provider
final entityFilesProvider = AsyncNotifierProvider.family<
    EntityFilesNotifier,
    List<FileAttachment>,
    ({String entityType, String entityId})>(
  EntityFilesNotifier.new,
);

class EntityFilesNotifier extends FamilyAsyncNotifier<
    List<FileAttachment>,
    ({String entityType, String entityId})> {
  @override
  Future<List<FileAttachment>> build(
      ({String entityType, String entityId})
          arg) async {
    final repo = ref.read(fileRepositoryProvider);
    return repo.getFiles(
      entityType: arg.entityType,
      entityId: arg.entityId,
    );
  }

  Future<FileAttachment> uploadFile({
    required PlatformFile file,
    required String uploaderId,
    String? description,
  }) async {
    final repo = ref.read(fileRepositoryProvider);
    final attachment = await repo.uploadFile(
      file: file,
      entityType: arg.entityType,
      entityId: arg.entityId,
      uploaderId: uploaderId,
      description: description,
    );
    ref.invalidateSelf();
    return attachment;
  }

  Future<void> deleteFile(
      FileAttachment file) async {
    final repo = ref.read(fileRepositoryProvider);
    await repo.deleteFile(file);
    ref.invalidateSelf();
  }

  Future<Uint8List> downloadBytes(
      FileAttachment file) async {
    final repo = ref.read(fileRepositoryProvider);
    return repo.downloadBytes(file);
  }

  Future<String> getDownloadUrl(
      FileAttachment file) async {
    final repo = ref.read(fileRepositoryProvider);
    return repo.getDownloadUrl(file);
  }
}
