/// R&D 과제 모델
class Project {
  const Project({
    required this.id,
    required this.title,
    this.projectNumber,
    this.description,
    this.status = ProjectStatus.planning,
    this.startDate,
    this.endDate,
    this.leadInstitution = '한국기계연구원',
    this.coInstitutions = const [],
    this.totalBudget = 0,
    required this.ownerId,
    this.ownerName,
    this.assigneeId,
    this.assigneeName,
    this.showInCalendar = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? projectNumber;
  final String? description;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String leadInstitution;
  final List<String> coInstitutions;
  final int totalBudget;
  final String ownerId;
  final String? ownerName;
  final String? assigneeId;
  final String? assigneeName;
  final bool showInCalendar;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      projectNumber: json['project_number'] as String?,
      description: json['description'] as String?,
      status: ProjectStatus.fromString(json['status'] as String? ?? 'planning'),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      leadInstitution:
          json['lead_institution'] as String? ?? '한국기계연구원',
      coInstitutions: (json['co_institutions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      totalBudget: json['total_budget'] as int? ?? 0,
      ownerId: json['owner_id'] as String,
      ownerName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      assigneeId:
          json['assignee_id'] as String?,
      assigneeName: json['assignee'] != null
          ? (json['assignee']
                  as Map<String, dynamic>)[
              'full_name'] as String?
          : null,
      showInCalendar: json['show_in_calendar'] as bool? ?? false,
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
      'title': title,
      'project_number': projectNumber,
      'description': description,
      'status': status.name,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'lead_institution': leadInstitution,
      'co_institutions': coInstitutions,
      'total_budget': totalBudget,
      'owner_id': ownerId,
      'assignee_id': assigneeId,
      'show_in_calendar': showInCalendar,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'project_number': projectNumber,
      'description': description,
      'status': status.name,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'lead_institution': leadInstitution,
      'co_institutions': coInstitutions,
      'total_budget': totalBudget,
      'owner_id': ownerId,
      'assignee_id': assigneeId,
      'show_in_calendar': showInCalendar,
    };
  }

  Project copyWith({
    String? id,
    String? title,
    String? projectNumber,
    String? description,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? leadInstitution,
    List<String>? coInstitutions,
    int? totalBudget,
    String? ownerId,
    String? ownerName,
    String? Function()? assigneeId,
    String? Function()? assigneeName,
    bool? showInCalendar,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      projectNumber: projectNumber ?? this.projectNumber,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      leadInstitution: leadInstitution ?? this.leadInstitution,
      coInstitutions: coInstitutions ?? this.coInstitutions,
      totalBudget: totalBudget ?? this.totalBudget,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      assigneeId: assigneeId != null
          ? assigneeId()
          : this.assigneeId,
      assigneeName: assigneeName != null
          ? assigneeName()
          : this.assigneeName,
      showInCalendar: showInCalendar ?? this.showInCalendar,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 24시간 이내 생성 여부
  bool get isNew =>
      createdAt != null &&
      DateTime.now().difference(createdAt!).inHours < 24;

  /// 과제 진행률 (기간 기반, 0.0 ~ 1.0)
  double get progressByDate {
    if (startDate == null || endDate == null) return 0;
    final total = endDate!.difference(startDate!).inDays;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(startDate!).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// D-Day 계산
  int? get daysRemaining {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }

  /// 예산 표시 (억 단위)
  String get budgetDisplay {
    if (totalBudget >= 100000000) {
      final billions = totalBudget / 100000000;
      return '${billions.toStringAsFixed(1)}억원';
    } else if (totalBudget >= 10000) {
      final manWon = totalBudget / 10000;
      return '${manWon.toStringAsFixed(0)}만원';
    }
    return '$totalBudget원';
  }
}

/// 과제 상태
enum ProjectStatus {
  planning('계획'),
  active('진행중'),
  completed('완료'),
  onHold('보류'),
  cancelled('취소');

  const ProjectStatus(this.label);
  final String label;

  static ProjectStatus fromString(String value) {
    switch (value) {
      case 'planning':
        return ProjectStatus.planning;
      case 'active':
        return ProjectStatus.active;
      case 'completed':
        return ProjectStatus.completed;
      case 'on_hold':
        return ProjectStatus.onHold;
      case 'cancelled':
        return ProjectStatus.cancelled;
      default:
        return ProjectStatus.planning;
    }
  }

  String get dbValue {
    switch (this) {
      case ProjectStatus.onHold:
        return 'on_hold';
      default:
        return name;
    }
  }
}
