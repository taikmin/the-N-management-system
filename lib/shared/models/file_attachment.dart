/// 파일 첨부 모델
class FileAttachment {
  const FileAttachment({
    required this.id,
    required this.fileName,
    this.fileSize = 0,
    this.mimeType,
    required this.storagePath,
    required this.bucketName,
    required this.entityType,
    required this.entityId,
    required this.uploaderId,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fileName;
  final int fileSize;
  final String? mimeType;
  final String storagePath;
  final String bucketName;
  final String entityType;
  final String entityId;
  final String uploaderId;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FileAttachment.fromJson(
      Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int? ?? 0,
      mimeType: json['mime_type'] as String?,
      storagePath: json['storage_path'] as String,
      bucketName: json['bucket_name'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      uploaderId: json['uploader_id'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(
              json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(
              json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'storage_path': storagePath,
      'bucket_name': bucketName,
      'entity_type': entityType,
      'entity_id': entityId,
      'uploader_id': uploaderId,
      'description': description,
    };
  }

  /// 파일 크기 표시용
  String get fileSizeDisplay {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 이미지 파일 여부
  bool get isImage =>
      mimeType != null && mimeType!.startsWith('image/');

  /// 파일 확장자 추출
  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0
        ? fileName.substring(dot + 1).toLowerCase()
        : '';
  }

  /// 파일 타입 아이콘 추론
  String get fileTypeLabel {
    switch (extension) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'ppt':
      case 'pptx':
        return 'PPT';
      case 'hwp':
      case 'hwpx':
        return 'HWP';
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return '이미지';
      case 'zip':
      case 'rar':
      case '7z':
        return '압축';
      default:
        return '파일';
    }
  }
}
