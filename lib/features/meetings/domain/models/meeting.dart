/// 회의 모델
class Meeting {
  const Meeting({
    required this.id,
    this.projectId,
    required this.title,
    this.meetingType = MeetingType.progressCheck,
    required this.meetingDate,
    this.location,
    this.roomName,
    this.status = MeetingStatus.preparing,
    this.mealReservation = false,
    this.mealLocation,
    this.expectedAttendees = 0,
    this.description,
    this.meetingMode = MeetingMode.inPerson,
    this.onlinePlatform,
    this.onlineLink,
    this.onlineMeetingId,
    this.onlinePassword,
    required this.creatorId,
    this.creatorName,
    this.projectTitle,
    this.meetingNotes,
    this.rawTranscript,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? projectId;
  final String title;
  final MeetingType meetingType;
  final DateTime meetingDate;
  final String? location;
  final String? roomName;
  final MeetingStatus status;
  final bool mealReservation;
  final String? mealLocation;
  final int expectedAttendees;
  final String? description;
  final MeetingMode meetingMode;
  final String? onlinePlatform;
  final String? onlineLink;
  final String? onlineMeetingId;
  final String? onlinePassword;
  final String creatorId;
  final String? creatorName;
  final String? projectTitle;
  final String? meetingNotes;
  final String? rawTranscript;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as String,
      projectId: json['project_id'] as String?,
      title: json['title'] as String,
      meetingType: MeetingType.fromString(
          json['meeting_type'] as String? ?? 'progress_check'),
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      location: json['location'] as String?,
      roomName: json['room_name'] as String?,
      status:
          MeetingStatus.fromString(json['status'] as String? ?? 'preparing'),
      mealReservation: json['meal_reservation'] as bool? ?? false,
      mealLocation: json['meal_location'] as String?,
      expectedAttendees: json['expected_attendees'] as int? ?? 0,
      description: json['description'] as String?,
      meetingMode: MeetingMode.fromString(
          json['meeting_mode'] as String? ??
              'in_person'),
      onlinePlatform:
          json['online_platform'] as String?,
      onlineLink: json['online_link'] as String?,
      onlineMeetingId:
          json['online_meeting_id'] as String?,
      onlinePassword:
          json['online_password'] as String?,
      creatorId: json['creator_id'] as String,
      creatorName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      projectTitle: json['projects'] != null
          ? (json['projects'] as Map<String, dynamic>)['title'] as String?
          : null,
      meetingNotes: json['meeting_notes'] as String?,
      rawTranscript: json['raw_transcript'] as String?,
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
      if (projectId != null) 'project_id': projectId,
      'title': title,
      'meeting_type': meetingType.dbValue,
      'meeting_date': meetingDate.toIso8601String(),
      'location': location,
      'room_name': roomName,
      'status': status.dbValue,
      'meal_reservation': mealReservation,
      'meal_location': mealLocation,
      'expected_attendees': expectedAttendees,
      'description': description,
      'meeting_mode': meetingMode.dbValue,
      'online_platform': onlinePlatform,
      'online_link': onlineLink,
      'online_meeting_id': onlineMeetingId,
      'online_password': onlinePassword,
      'creator_id': creatorId,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'meeting_type': meetingType.dbValue,
      'meeting_date': meetingDate.toIso8601String(),
      'location': location,
      'room_name': roomName,
      'status': status.dbValue,
      'meal_reservation': mealReservation,
      'meal_location': mealLocation,
      'expected_attendees': expectedAttendees,
      'description': description,
      'meeting_mode': meetingMode.dbValue,
      'online_platform': onlinePlatform,
      'online_link': onlineLink,
      'online_meeting_id': onlineMeetingId,
      'online_password': onlinePassword,
    };
  }

  Meeting copyWith({
    String? id,
    String? Function()? projectId,
    String? title,
    MeetingType? meetingType,
    DateTime? meetingDate,
    String? location,
    String? roomName,
    MeetingStatus? status,
    bool? mealReservation,
    String? mealLocation,
    int? expectedAttendees,
    String? description,
    MeetingMode? meetingMode,
    String? Function()? onlinePlatform,
    String? Function()? onlineLink,
    String? Function()? onlineMeetingId,
    String? Function()? onlinePassword,
    String? creatorId,
    String? Function()? meetingNotes,
    String? Function()? rawTranscript,
  }) {
    return Meeting(
      id: id ?? this.id,
      projectId: projectId != null
          ? projectId()
          : this.projectId,
      title: title ?? this.title,
      meetingType: meetingType ?? this.meetingType,
      meetingDate: meetingDate ?? this.meetingDate,
      location: location ?? this.location,
      roomName: roomName ?? this.roomName,
      status: status ?? this.status,
      mealReservation:
          mealReservation ?? this.mealReservation,
      mealLocation:
          mealLocation ?? this.mealLocation,
      expectedAttendees:
          expectedAttendees ?? this.expectedAttendees,
      description: description ?? this.description,
      meetingMode: meetingMode ?? this.meetingMode,
      onlinePlatform: onlinePlatform != null
          ? onlinePlatform()
          : this.onlinePlatform,
      onlineLink: onlineLink != null
          ? onlineLink()
          : this.onlineLink,
      onlineMeetingId: onlineMeetingId != null
          ? onlineMeetingId()
          : this.onlineMeetingId,
      onlinePassword: onlinePassword != null
          ? onlinePassword()
          : this.onlinePassword,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName,
      projectTitle: projectTitle,
      meetingNotes: meetingNotes != null
          ? meetingNotes()
          : this.meetingNotes,
      rawTranscript: rawTranscript != null
          ? rawTranscript()
          : this.rawTranscript,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 24시간 이내 생성 여부
  bool get isNew =>
      createdAt != null &&
      DateTime.now().difference(createdAt!).inHours < 24;

  /// D-Day 계산
  int get daysUntil => meetingDate.difference(DateTime.now()).inDays;

  /// 지난 회의인지
  bool get isPast => meetingDate.isBefore(DateTime.now());

  /// 오늘 회의인지
  bool get isToday {
    final now = DateTime.now();
    return meetingDate.year == now.year &&
        meetingDate.month == now.month &&
        meetingDate.day == now.day;
  }
}

/// 회의 유형
enum MeetingType {
  progressCheck('진도점검'),
  kickoff('킥오프'),
  midPresentation('중간발표'),
  finalPresentation('최종발표'),
  other('기타');

  const MeetingType(this.label);
  final String label;

  String get dbValue {
    switch (this) {
      case MeetingType.progressCheck:
        return 'progress_check';
      case MeetingType.midPresentation:
        return 'mid_presentation';
      case MeetingType.finalPresentation:
        return 'final_presentation';
      default:
        return name;
    }
  }

  static MeetingType fromString(String value) {
    switch (value) {
      case 'progress_check':
        return MeetingType.progressCheck;
      case 'kickoff':
        return MeetingType.kickoff;
      case 'mid_presentation':
        return MeetingType.midPresentation;
      case 'final_presentation':
        return MeetingType.finalPresentation;
      default:
        return MeetingType.other;
    }
  }
}

/// 회의 모드 (대면/비대면/하이브리드)
enum MeetingMode {
  inPerson('대면'),
  online('비대면'),
  hybrid('하이브리드');

  const MeetingMode(this.label);
  final String label;

  String get dbValue {
    switch (this) {
      case MeetingMode.inPerson:
        return 'in_person';
      default:
        return name;
    }
  }

  static MeetingMode fromString(String value) {
    switch (value) {
      case 'in_person':
        return MeetingMode.inPerson;
      case 'online':
        return MeetingMode.online;
      case 'hybrid':
        return MeetingMode.hybrid;
      default:
        return MeetingMode.inPerson;
    }
  }
}

/// 회의 상태
enum MeetingStatus {
  preparing('준비중'),
  notified('공지완료'),
  inProgress('진행중'),
  completed('완료');

  const MeetingStatus(this.label);
  final String label;

  String get dbValue {
    switch (this) {
      case MeetingStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }

  static MeetingStatus fromString(String value) {
    switch (value) {
      case 'preparing':
        return MeetingStatus.preparing;
      case 'notified':
        return MeetingStatus.notified;
      case 'in_progress':
        return MeetingStatus.inProgress;
      case 'completed':
        return MeetingStatus.completed;
      default:
        return MeetingStatus.preparing;
    }
  }
}
