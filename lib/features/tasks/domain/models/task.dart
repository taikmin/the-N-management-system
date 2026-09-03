/// 호텔 업무 모델
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.departmentId,
    this.departmentName,
    this.assignerId,
    this.assignerName,
    this.assigneeId,
    this.assigneeName,
    this.category,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.assigned,
    this.dueDate,
    this.dueTime,
    this.completedAt,
    this.completionNote,
    this.delayReason,
    this.showInCalendar = true,
    this.recurrencePattern,
    this.recurrenceTemplateId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? departmentId;
  final String? departmentName;
  final String? assignerId;
  final String? assignerName;
  final String? assigneeId;
  final String? assigneeName;
  final String? category;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? dueTime; // 'HH:mm'
  final DateTime? completedAt;
  final String? completionNote;
  final String? delayReason;
  final bool showInCalendar;

  /// 반복 패턴 (null = 일회성)
  final String? recurrencePattern;

  /// 반복 템플릿에서 생성된 인스턴스면 원본 템플릿 ID
  final String? recurrenceTemplateId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTemplate =>
      recurrencePattern != null && recurrenceTemplateId == null;
  bool get isInstance => recurrenceTemplateId != null;

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return d == today;
  }

  bool get isDelayed {
    if (status == TaskStatus.completed) return false;
    if (status == TaskStatus.delayed) return true;
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return d.isBefore(today);
  }

  int? get delayDays {
    if (!isDelayed || dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return today.difference(d).inDays;
  }

  int? get daysUntilDue {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return d.difference(today).inDays;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: json['department'] != null
          ? (json['department'] as Map<String, dynamic>)['name'] as String?
          : null,
      assignerId: json['assigner_id'] as String?,
      assignerName: json['assigner'] != null
          ? (json['assigner'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      assigneeId: json['assignee_id'] as String?,
      assigneeName: json['assignee'] != null
          ? (json['assignee'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      category: json['category'] as String?,
      priority: TaskPriority.fromString(
          json['priority'] as String? ?? 'normal'),
      status:
          TaskStatus.fromString(json['status'] as String? ?? 'assigned'),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      dueTime: json['due_time'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completionNote: json['completion_note'] as String?,
      delayReason: json['delay_reason'] as String?,
      showInCalendar: json['show_in_calendar'] as bool? ?? true,
      recurrencePattern: json['recurrence_pattern'] as String?,
      recurrenceTemplateId: json['recurrence_template_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'title': title,
        'description': description,
        'department_id': departmentId,
        'assigner_id': assignerId,
        'assignee_id': assigneeId,
        'category': category,
        'priority': priority.name,
        'status': status.name,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'due_time': dueTime,
        'completion_note': completionNote,
        'delay_reason': delayReason,
        'show_in_calendar': showInCalendar,
        'recurrence_pattern': recurrencePattern,
        'recurrence_template_id': recurrenceTemplateId,
      };

  Map<String, dynamic> toUpdateJson() => toInsertJson();

  Task copyWith({
    String? title,
    String? Function()? description,
    String? Function()? departmentId,
    String? Function()? assigneeId,
    String? Function()? category,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? Function()? dueDate,
    String? Function()? dueTime,
    DateTime? Function()? completedAt,
    String? Function()? completionNote,
    String? Function()? delayReason,
    bool? showInCalendar,
    String? Function()? recurrencePattern,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description != null ? description() : this.description,
      departmentId:
          departmentId != null ? departmentId() : this.departmentId,
      departmentName: departmentName,
      assignerId: assignerId,
      assignerName: assignerName,
      assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
      assigneeName: assigneeName,
      category: category != null ? category() : this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      dueTime: dueTime != null ? dueTime() : this.dueTime,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      completionNote:
          completionNote != null ? completionNote() : this.completionNote,
      delayReason: delayReason != null ? delayReason() : this.delayReason,
      showInCalendar: showInCalendar ?? this.showInCalendar,
      recurrencePattern: recurrencePattern != null
          ? recurrencePattern()
          : this.recurrencePattern,
      recurrenceTemplateId: recurrenceTemplateId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

enum TaskStatus {
  assigned('지시됨'),
  inProgress('진행중'),
  completed('완료'),
  incomplete('미완료'),
  delayed('지연');

  const TaskStatus(this.label);
  final String label;

  static TaskStatus fromString(String value) {
    switch (value) {
      case 'assigned':
        return TaskStatus.assigned;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'incomplete':
        return TaskStatus.incomplete;
      case 'delayed':
        return TaskStatus.delayed;
      default:
        return TaskStatus.assigned;
    }
  }

  String get dbValue {
    switch (this) {
      case TaskStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }
}

enum TaskPriority {
  low('낮음', 1),
  normal('보통', 2),
  high('높음', 3),
  urgent('긴급', 4);

  const TaskPriority(this.label, this.sortOrder);
  final String label;
  final int sortOrder;

  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => TaskPriority.normal,
    );
  }
}

/// 반복 패턴 인코딩 도우미
class RecurrencePattern {
  final RecurrenceKind kind;

  /// weekly: 요일 코드 (mon..sun)
  /// monthly: 일자 (1..31)
  final List<String> args;

  const RecurrencePattern(this.kind, [this.args = const []]);

  static const List<String> weekDayCodes = [
    'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'
  ];

  static const Map<String, String> weekDayLabels = {
    'mon': '월', 'tue': '화', 'wed': '수', 'thu': '목',
    'fri': '금', 'sat': '토', 'sun': '일',
  };

  static RecurrencePattern? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(':');
    final kindStr = parts[0];
    final args = parts.length > 1 ? parts[1].split(',') : <String>[];
    switch (kindStr) {
      case 'daily':
        return const RecurrencePattern(RecurrenceKind.daily);
      case 'weekly':
        return RecurrencePattern(RecurrenceKind.weekly, args);
      case 'monthly':
        return RecurrencePattern(RecurrenceKind.monthly, args);
      default:
        return null;
    }
  }

  String encode() {
    switch (kind) {
      case RecurrenceKind.daily:
        return 'daily';
      case RecurrenceKind.weekly:
        return 'weekly:${args.join(',')}';
      case RecurrenceKind.monthly:
        return 'monthly:${args.join(',')}';
    }
  }

  String get displayLabel {
    switch (kind) {
      case RecurrenceKind.daily:
        return '매일';
      case RecurrenceKind.weekly:
        final days = args.map((c) => weekDayLabels[c] ?? c).join(',');
        return '매주 $days';
      case RecurrenceKind.monthly:
        return '매월 ${args.join(',')}일';
    }
  }
}

enum RecurrenceKind { daily, weekly, monthly }
