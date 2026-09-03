/// 개인 메모 모델
class Memo {
  const Memo({
    required this.id,
    required this.userId,
    this.title = '',
    this.content = '',
    this.category,
    this.isPinned = false,
    this.priority = MemoPriority.none,
    this.status = MemoStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String content;
  final String? category;
  final bool isPinned;
  final MemoPriority priority;
  final MemoStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      category: json['category'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      priority: MemoPriority.fromString(
        json['priority'] as String? ?? 'none',
      ),
      status: MemoStatus.fromString(
        json['status'] as String? ?? 'active',
      ),
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
      'user_id': userId,
      'title': title,
      'content': content,
      'category': category,
      'is_pinned': isPinned,
      'priority': priority.name,
      'status': status.name,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'is_pinned': isPinned,
      'priority': priority.name,
      'status': status.name,
    };
  }

  Memo copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? Function()? category,
    bool? isPinned,
    MemoPriority? priority,
    MemoStatus? status,
  }) {
    return Memo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category != null
          ? category()
          : this.category,
      isPinned: isPinned ?? this.isPinned,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// 표시용 날짜
  String get createdAtDisplay {
    if (createdAt == null) return '';
    final d = createdAt!;
    return '${d.month}/${d.day}';
  }
}

/// 메모 우선순위
enum MemoPriority {
  none('없음'),
  low('낮음'),
  medium('보통'),
  high('높음');

  const MemoPriority(this.label);
  final String label;

  static MemoPriority fromString(String value) {
    return MemoPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => MemoPriority.none,
    );
  }
}

/// 메모 상태
enum MemoStatus {
  active('활성'),
  archived('보관');

  const MemoStatus(this.label);
  final String label;

  static MemoStatus fromString(String value) {
    return MemoStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MemoStatus.active,
    );
  }
}

/// 메모 필터
enum MemoFilter {
  all,
  idea,
  memo,
  todo,
  archived,
}
