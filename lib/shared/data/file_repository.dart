import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/supabase_config.dart';
import '../models/file_attachment.dart';

/// 파일 첨부 Repository (Supabase Storage + DB)
class FileRepository {
  final _client = SupabaseConfig.client;

  /// 버킷 이름 결정
  String _bucketFor(String entityType) {
    switch (entityType) {
      case 'project':
      case 'memo':
        return 'project-files';
      case 'task':
      case 'daily_log':
        return 'task-files';
      case 'meeting':
      case 'meeting_document':
        return 'meeting-files';
      default:
        return 'project-files';
    }
  }

  /// 엔티티에 연결된 파일 목록 조회
  Future<List<FileAttachment>> getFiles({
    required String entityType,
    required String entityId,
  }) async {
    final data = await _client
        .from('file_attachments')
        .select()
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => FileAttachment.fromJson(j))
        .toList();
  }

  /// 파일 확장자 추출 (ASCII safe)
  String _safeExt(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return '.${fileName.substring(dot + 1).toLowerCase()}';
  }

  /// 파일 업로드 (PlatformFile → Storage → DB)
  /// Storage 경로는 ASCII만 사용 (타임스탬프 기반)
  /// 원본 한국어 파일명은 DB file_name에 보존
  Future<FileAttachment> uploadFile({
    required PlatformFile file,
    required String entityType,
    required String entityId,
    required String uploaderId,
    String? description,
  }) async {
    final bucket = _bucketFor(entityType);
    final timestamp =
        DateTime.now().millisecondsSinceEpoch;
    final ext = _safeExt(file.name);
    final storagePath =
        '$entityType/$entityId/$timestamp$ext';

    // Storage에 업로드
    final Uint8List bytes = file.bytes!;
    await _client.storage
        .from(bucket)
        .uploadBinary(storagePath, bytes,
            fileOptions: FileOptions(
              contentType: _mimeType(file.name),
            ));

    // DB에 레코드 저장
    final attachment = FileAttachment(
      id: '',
      fileName: file.name,
      fileSize: file.size,
      mimeType: _mimeType(file.name),
      storagePath: storagePath,
      bucketName: bucket,
      entityType: entityType,
      entityId: entityId,
      uploaderId: uploaderId,
      description: description,
    );

    final data = await _client
        .from('file_attachments')
        .insert(attachment.toInsertJson())
        .select()
        .single();
    return FileAttachment.fromJson(data);
  }

  /// 파일 바이트 다운로드 (Storage에서 직접)
  Future<Uint8List> downloadBytes(
      FileAttachment file) async {
    return await _client.storage
        .from(file.bucketName)
        .download(file.storagePath);
  }

  /// 파일 다운로드 URL (Signed URL, 1시간 유효)
  Future<String> getDownloadUrl(
      FileAttachment file) async {
    final url = await _client.storage
        .from(file.bucketName)
        .createSignedUrl(file.storagePath, 3600);
    return url;
  }

  /// 파일 삭제 (Storage + DB)
  Future<void> deleteFile(FileAttachment file) async {
    // Storage에서 삭제
    await _client.storage
        .from(file.bucketName)
        .remove([file.storagePath]);

    // DB에서 삭제
    await _client
        .from('file_attachments')
        .delete()
        .eq('id', file.id);
  }

  /// MIME type 추론
  String _mimeType(String fileName) {
    final ext =
        fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'hwp':
        return 'application/x-hwp';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
}
