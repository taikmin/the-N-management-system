/// 회의 문서 모델
class MeetingDocument {
  const MeetingDocument({
    required this.id,
    required this.meetingId,
    this.docType = DocType.other,
    required this.title,
    this.fileUrl,
    this.fileName,
    this.fileSize = 0,
    required this.uploaderId,
    this.uploaderName,
    this.targetUserId,
    this.targetUserName,
    this.dueDate,
    this.submitStatus = SubmitStatus.notSubmitted,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String meetingId;
  final DocType docType;
  final String title;
  final String? fileUrl;
  final String? fileName;
  final int fileSize;
  final String uploaderId;
  final String? uploaderName;
  final String? targetUserId;
  final String? targetUserName;
  final DateTime? dueDate;
  final SubmitStatus submitStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MeetingDocument.fromJson(Map<String, dynamic> json) {
    return MeetingDocument(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      docType: DocType.fromString(json['doc_type'] as String? ?? 'other'),
      title: json['title'] as String,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int? ?? 0,
      uploaderId: json['uploader_id'] as String,
      uploaderName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      targetUserId: json['target_user_id'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      submitStatus: SubmitStatus.fromString(
          json['submit_status'] as String? ?? 'not_submitted'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'meeting_id': meetingId,
      'doc_type': docType.dbValue,
      'title': title,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'uploader_id': uploaderId,
      'target_user_id': targetUserId,
      'due_date': dueDate?.toIso8601String(),
      'submit_status': submitStatus.dbValue,
    };
  }

  /// 제출 마감 초과 여부
  bool get isOverdue {
    if (dueDate == null) return false;
    if (submitStatus == SubmitStatus.submitted) return false;
    return DateTime.now().isAfter(dueDate!);
  }
}

enum DocType {
  template('양식 템플릿'),
  submission('제출 자료'),
  compiled('취합본'),
  minutes('회의록'),
  other('기타');

  const DocType(this.label);
  final String label;

  String get dbValue => name;

  static DocType fromString(String value) {
    return DocType.values.firstWhere(
      (d) => d.name == value || d.dbValue == value,
      orElse: () => DocType.other,
    );
  }
}

enum SubmitStatus {
  notSubmitted('미제출'),
  submitted('제출'),
  revisionRequested('수정요청');

  const SubmitStatus(this.label);
  final String label;

  String get dbValue {
    switch (this) {
      case SubmitStatus.notSubmitted:
        return 'not_submitted';
      case SubmitStatus.revisionRequested:
        return 'revision_requested';
      default:
        return name;
    }
  }

  static SubmitStatus fromString(String value) {
    switch (value) {
      case 'not_submitted':
        return SubmitStatus.notSubmitted;
      case 'submitted':
        return SubmitStatus.submitted;
      case 'revision_requested':
        return SubmitStatus.revisionRequested;
      default:
        return SubmitStatus.notSubmitted;
    }
  }
}
