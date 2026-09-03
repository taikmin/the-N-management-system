/// 일일 수행 기록 모델
class DailyLog {
  const DailyLog({
    required this.id,
    required this.taskId,
    required this.authorId,
    this.authorName,
    required this.logDate,
    required this.content,
    this.issues,
    this.nextPlan,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String taskId;
  final String authorId;
  final String? authorName;
  final DateTime logDate;
  final String content;
  final String? issues;
  final String? nextPlan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      logDate: DateTime.parse(json['log_date'] as String),
      content: json['content'] as String,
      issues: json['issues'] as String?,
      nextPlan: json['next_plan'] as String?,
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
      'task_id': taskId,
      'author_id': authorId,
      'log_date': logDate.toIso8601String().split('T').first,
      'content': content,
      'issues': issues,
      'next_plan': nextPlan,
    };
  }
}
