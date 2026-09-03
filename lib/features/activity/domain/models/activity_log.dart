/// 활동 로그 모델
class ActivityLog {
  const ActivityLog({
    required this.id,
    this.userId,
    this.userName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityTitle,
    this.details,
    required this.createdAt,
    this.notified = false,
  });

  final String id;
  final String? userId;
  final String? userName;
  final String action; // create, update, delete, complete
  final String entityType; // tasks, departments, memos
  final String? entityId;
  final String? entityTitle;
  final Map<String, dynamic>? details;
  final DateTime createdAt;
  final bool notified;

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      entityTitle: json['entity_title'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      notified: json['notified'] as bool? ?? false,
    );
  }

  String get actionIcon {
    switch (action) {
      case 'create':
        return '+';
      case 'update':
        return '~';
      case 'delete':
        return '-';
      case 'complete':
        return 'v';
      default:
        return '?';
    }
  }

  String get actionLabel {
    switch (action) {
      case 'create':
        return '생성';
      case 'update':
        return '수정';
      case 'delete':
        return '삭제';
      case 'complete':
        return '완료';
      default:
        return action;
    }
  }

  String get entityLabel {
    switch (entityType) {
      case 'tasks':
        return '업무';
      case 'departments':
        return '부서';
      case 'memos':
        return '메모';
      default:
        return entityType;
    }
  }

  /// 부가 정보 (부서명 등, log_activity 트리거가 details.department_name 저장)
  String? get departmentName =>
      details?['department_name'] as String?;

  String get summary {
    final name = userName ?? '알 수 없음';
    final title = entityTitle ?? '(제목 없음)';
    final deptSuffix = departmentName != null ? ' [$departmentName]' : '';
    return '$name 님이 \'$title\' $entityLabel을(를) '
        '$actionLabel했습니다$deptSuffix';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${createdAt.month}/${createdAt.day}';
  }

  String get timeDisplay {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dateKey {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate =
        DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(logDate).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    return '${createdAt.year}.'
        '${createdAt.month.toString().padLeft(2, '0')}.'
        '${createdAt.day.toString().padLeft(2, '0')}';
  }

  String? get routePath {
    if (entityId == null) return null;
    switch (entityType) {
      case 'tasks':
        return '/tasks/$entityId';
      case 'departments':
        return '/departments/$entityId';
      case 'memos':
        return '/memos/$entityId';
      default:
        return null;
    }
  }
}

/// 활동 필터
enum ActivityFilter {
  all('전체'),
  tasks('업무'),
  departments('부서'),
  memos('메모');

  const ActivityFilter(this.label);
  final String label;

  String? get entityType {
    switch (this) {
      case ActivityFilter.all:
        return null;
      case ActivityFilter.tasks:
        return 'tasks';
      case ActivityFilter.departments:
        return 'departments';
      case ActivityFilter.memos:
        return 'memos';
    }
  }
}
