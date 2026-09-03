/// 회의 안건 모델
class MeetingAgenda {
  const MeetingAgenda({
    required this.id,
    required this.meetingId,
    this.orderIndex = 0,
    required this.title,
    this.presenterId,
    this.presenterName,
    this.durationMinutes = 10,
    this.relatedProjectId,
    this.description,
    this.createdAt,
  });

  final String id;
  final String meetingId;
  final int orderIndex;
  final String title;
  final String? presenterId;
  final String? presenterName;
  final int durationMinutes;
  final String? relatedProjectId;
  final String? description;
  final DateTime? createdAt;

  factory MeetingAgenda.fromJson(Map<String, dynamic> json) {
    return MeetingAgenda(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      title: json['title'] as String,
      presenterId: json['presenter_id'] as String?,
      presenterName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      durationMinutes: json['duration_minutes'] as int? ?? 10,
      relatedProjectId: json['related_project_id'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'meeting_id': meetingId,
      'order_index': orderIndex,
      'title': title,
      'presenter_id': presenterId,
      'duration_minutes': durationMinutes,
      'related_project_id': relatedProjectId,
      'description': description,
    };
  }
}
