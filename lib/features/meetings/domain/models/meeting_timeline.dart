/// 회의 준비 타임라인 마일스톤 모델
class MeetingTimeline {
  const MeetingTimeline({
    required this.id,
    required this.meetingId,
    required this.milestone,
    required this.label,
    required this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.notificationSent = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String meetingId;
  final String milestone;
  final String label;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool notificationSent;
  final int sortOrder;
  final DateTime? createdAt;

  factory MeetingTimeline.fromJson(
    Map<String, dynamic> json,
  ) {
    return MeetingTimeline(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      milestone: json['milestone'] as String,
      label: json['label'] as String,
      dueDate: DateTime.parse(
        json['due_date'] as String,
      ),
      isCompleted:
          json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(
              json['completed_at'] as String,
            )
          : null,
      notificationSent:
          json['notification_sent'] as bool? ??
              false,
      sortOrder:
          json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(
              json['created_at'] as String,
            )
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'meeting_id': meetingId,
      'milestone': milestone,
      'label': label,
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted,
      'notification_sent': notificationSent,
      'sort_order': sortOrder,
    };
  }

  MeetingTimeline copyWith({
    String? label,
    DateTime? dueDate,
    bool? isCompleted,
    int? sortOrder,
    DateTime? Function()? completedAt,
  }) {
    return MeetingTimeline(
      id: id,
      meetingId: meetingId,
      milestone: milestone,
      label: label ?? this.label,
      dueDate: dueDate ?? this.dueDate,
      isCompleted:
          isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt: completedAt != null
          ? completedAt()
          : this.completedAt,
      notificationSent: notificationSent,
      createdAt: createdAt,
    );
  }

  /// 마감 초과 여부
  bool get isOverdue =>
      !isCompleted && DateTime.now().isAfter(dueDate);

  /// 기본 타임라인 템플릿 (회의일 기준 역산)
  static List<MeetingTimeline> generateDefaults({
    required String meetingId,
    required DateTime meetingDate,
  }) {
    return [
      MeetingTimeline(
        id: '',
        meetingId: meetingId,
        milestone: 'template_distribution',
        label: '양식 배포',
        dueDate: meetingDate.subtract(
          const Duration(days: 14),
        ),
        sortOrder: 0,
      ),
      MeetingTimeline(
        id: '',
        meetingId: meetingId,
        milestone: 'submission_deadline',
        label: '제출 마감',
        dueDate: meetingDate.subtract(
          const Duration(days: 7),
        ),
        sortOrder: 1,
      ),
      MeetingTimeline(
        id: '',
        meetingId: meetingId,
        milestone: 'compilation_complete',
        label: '취합 완료',
        dueDate: meetingDate.subtract(
          const Duration(days: 3),
        ),
        sortOrder: 2,
      ),
      MeetingTimeline(
        id: '',
        meetingId: meetingId,
        milestone: 'pre_review',
        label: '사전 검토',
        dueDate: meetingDate.subtract(
          const Duration(days: 1),
        ),
        sortOrder: 3,
      ),
      MeetingTimeline(
        id: '',
        meetingId: meetingId,
        milestone: 'meeting_day',
        label: '회의 당일',
        dueDate: meetingDate,
        sortOrder: 4,
      ),
    ];
  }
}
