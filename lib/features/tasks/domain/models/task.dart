/// 태스크 모델
class Task {
  const Task({
    required this.id,
    this.projectId,
    this.parentTaskId,
    required this.title,
    this.description,
    this.status = TaskStatus.planned,
    this.priority = TaskPriority.medium,
    this.planType = PlanType.a,
    this.assigneeId,
    this.assigneeName,
    this.createdBy,
    this.creatorName,
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.orderIndex = 0,
    this.category,
    this.colorTag = ColorTag.none,
    this.showInCalendar = false,
    this.projectTitle,
    this.subTasks = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? projectId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final PlanType planType;
  final String? assigneeId;
  final String? assigneeName;
  final String? createdBy;
  final String? creatorName;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final int orderIndex;
  final String? category;
  final ColorTag colorTag;
  final bool showInCalendar;
  final String? projectTitle;
  final List<Task> subTasks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String?,
      parentTaskId: json['parent_task_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromString(
        json['status'] as String? ?? 'planned',
      ),
      priority: TaskPriority.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      planType: PlanType.fromString(
        json['plan_type'] as String? ?? 'A',
      ),
      assigneeId: json['assignee_id'] as String?,
      assigneeName: json['profiles'] != null
          ? (json['profiles']
              as Map<String, dynamic>)['full_name'] as String?
          : null,
      createdBy: json['created_by'] as String?,
      creatorName: json['creator'] != null
          ? (json['creator']
              as Map<String, dynamic>)['full_name'] as String?
          : null,
      plannedStart: json['planned_start'] != null
          ? DateTime.parse(json['planned_start'] as String)
          : null,
      plannedEnd: json['planned_end'] != null
          ? DateTime.parse(json['planned_end'] as String)
          : null,
      actualStart: json['actual_start'] != null
          ? DateTime.parse(json['actual_start'] as String)
          : null,
      actualEnd: json['actual_end'] != null
          ? DateTime.parse(json['actual_end'] as String)
          : null,
      orderIndex: json['order_index'] as int? ?? 0,
      category: json['category'] as String?,
      colorTag: ColorTag.fromString(
        json['color_tag'] as String? ?? 'none',
      ),
      showInCalendar:
          json['show_in_calendar'] as bool? ?? true,
      projectTitle: json['projects'] != null
          ? (json['projects']
              as Map<String, dynamic>)['title'] as String?
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    final json = <String, dynamic>{
      'parent_task_id': parentTaskId,
      'title': title,
      'description': description,
      'status': status.dbValue,
      'priority': priority.name,
      'plan_type': planType.value,
      'assignee_id': assigneeId,
      'planned_start':
          plannedStart?.toIso8601String().split('T').first,
      'planned_end':
          plannedEnd?.toIso8601String().split('T').first,
      'actual_start':
          actualStart?.toIso8601String().split('T').first,
      'actual_end':
          actualEnd?.toIso8601String().split('T').first,
      'order_index': orderIndex,
      'category': category,
      'color_tag': colorTag.value,
      'show_in_calendar': showInCalendar,
    };
    if (projectId != null) {
      json['project_id'] = projectId;
    }
    return json;
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'description': description,
      'status': status.dbValue,
      'priority': priority.name,
      'plan_type': planType.value,
      'assignee_id': assigneeId,
      'planned_start':
          plannedStart?.toIso8601String().split('T').first,
      'planned_end':
          plannedEnd?.toIso8601String().split('T').first,
      'actual_start':
          actualStart?.toIso8601String().split('T').first,
      'actual_end':
          actualEnd?.toIso8601String().split('T').first,
      'order_index': orderIndex,
      'category': category,
      'color_tag': colorTag.value,
      'show_in_calendar': showInCalendar,
      'project_id': projectId,
    };
  }

  Task copyWith({
    String? id,
    String? Function()? projectId,
    String? parentTaskId,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    PlanType? planType,
    String? assigneeId,
    String? assigneeName,
    String? createdBy,
    String? creatorName,
    DateTime? plannedStart,
    DateTime? plannedEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    int? orderIndex,
    String? Function()? category,
    ColorTag? colorTag,
    bool? showInCalendar,
    String? projectTitle,
    List<Task>? subTasks,
  }) {
    return Task(
      id: id ?? this.id,
      projectId:
          projectId != null ? projectId() : this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      planType: planType ?? this.planType,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      plannedStart: plannedStart ?? this.plannedStart,
      plannedEnd: plannedEnd ?? this.plannedEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      orderIndex: orderIndex ?? this.orderIndex,
      category:
          category != null ? category() : this.category,
      colorTag: colorTag ?? this.colorTag,
      showInCalendar:
          showInCalendar ?? this.showInCalendar,
      projectTitle: projectTitle ?? this.projectTitle,
      subTasks: subTasks ?? this.subTasks,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 지연 여부 (계획 종료일 초과 && 미완료)
  bool get isDelayed {
    if (plannedEnd == null) return false;
    if (status == TaskStatus.completed) return false;
    return DateTime.now().isAfter(plannedEnd!);
  }

  /// 지연 일수
  int get delayDays {
    if (!isDelayed || plannedEnd == null) return 0;
    return DateTime.now().difference(plannedEnd!).inDays;
  }

  /// 오늘 해야 할 태스크인지
  bool get isDueToday {
    if (plannedEnd == null) return false;
    final now = DateTime.now();
    return plannedEnd!.year == now.year &&
        plannedEnd!.month == now.month &&
        plannedEnd!.day == now.day;
  }

  /// 24시간 이내 생성 여부
  bool get isNew =>
      createdAt != null &&
      DateTime.now().difference(createdAt!).inHours < 24;

  /// 24시간 이내 완료 여부
  bool get isRecentlyCompleted =>
      status == TaskStatus.completed &&
      updatedAt != null &&
      DateTime.now().difference(updatedAt!).inHours < 24;

  /// 독립 태스크인지
  bool get isIndependent => projectId == null;

  /// 표시용 소속 텍스트 (과제명 또는 카테고리)
  String get belongsToLabel {
    if (projectTitle != null) return projectTitle!;
    if (category != null && category!.isNotEmpty) {
      return category!;
    }
    if (isIndependent) return '독립 업무';
    return '';
  }
}

/// 태스크 상태
enum TaskStatus {
  planned('계획'),
  inProgress('진행'),
  delayed('지연'),
  completed('완료'),
  blocked('진행불가');

  const TaskStatus(this.label);
  final String label;

  static TaskStatus fromString(String value) {
    switch (value) {
      case 'planned':
        return TaskStatus.planned;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'delayed':
        return TaskStatus.delayed;
      case 'completed':
        return TaskStatus.completed;
      case 'blocked':
        return TaskStatus.blocked;
      default:
        return TaskStatus.planned;
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

/// 우선순위
enum TaskPriority {
  low('낮음'),
  medium('보통'),
  high('높음'),
  urgent('긴급');

  const TaskPriority(this.label);
  final String label;

  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

/// Plan 유형
enum PlanType {
  a('A'),
  b('B'),
  c('C');

  const PlanType(this.value);
  final String value;

  static PlanType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'A':
        return PlanType.a;
      case 'B':
        return PlanType.b;
      case 'C':
        return PlanType.c;
      default:
        return PlanType.a;
    }
  }
}

/// 색상 태그
enum ColorTag {
  none('none', '없음'),
  red('red', '긴급'),
  yellow('yellow', '중요'),
  blue('blue', '일반');

  const ColorTag(this.value, this.label);
  final String value;
  final String label;

  static ColorTag fromString(String value) {
    return ColorTag.values.firstWhere(
      (c) => c.value == value,
      orElse: () => ColorTag.none,
    );
  }
}
