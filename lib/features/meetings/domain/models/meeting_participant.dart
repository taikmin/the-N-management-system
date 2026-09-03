/// 회의 참석자 모델
class MeetingParticipant {
  const MeetingParticipant({
    required this.id,
    required this.meetingId,
    required this.userId,
    this.userName,
    this.userEmail,
    this.institution,
    this.attendance = AttendanceStatus.pending,
    this.role = ParticipantRole.attendee,
    this.createdAt,
  });

  final String id;
  final String meetingId;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? institution;
  final AttendanceStatus attendance;
  final ParticipantRole role;
  final DateTime? createdAt;

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) {
    return MeetingParticipant(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      userId: json['user_id'] as String,
      userName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      userEmail: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['email'] as String?
          : null,
      institution: json['institution'] as String?,
      attendance: AttendanceStatus.fromString(
          json['attendance'] as String? ?? 'pending'),
      role: ParticipantRole.fromString(json['role'] as String? ?? 'attendee'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'meeting_id': meetingId,
      'user_id': userId,
      'institution': institution,
      'attendance': attendance.dbValue,
      'role': role.dbValue,
    };
  }
}

enum AttendanceStatus {
  pending('미응답'),
  confirmed('참석'),
  declined('불참');

  const AttendanceStatus(this.label);
  final String label;

  String get dbValue => name;

  static AttendanceStatus fromString(String value) {
    return AttendanceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AttendanceStatus.pending,
    );
  }
}

enum ParticipantRole {
  organizer('주관'),
  presenter('발표자'),
  attendee('참석자');

  const ParticipantRole(this.label);
  final String label;

  String get dbValue => name;

  static ParticipantRole fromString(String value) {
    return ParticipantRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ParticipantRole.attendee,
    );
  }
}
