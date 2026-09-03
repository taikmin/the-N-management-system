/// 연계 업무(태스크 업데이트) 모델
class TaskUpdate {
  const TaskUpdate({
    required this.id,
    required this.taskId,
    required this.authorId,
    this.authorName,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String taskId;
  final String authorId;
  final String? authorName;
  final String content;
  final DateTime? createdAt;

  factory TaskUpdate.fromJson(Map<String, dynamic> json) {
    return TaskUpdate(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['profiles'] != null
          ? (json['profiles']
                  as Map<String, dynamic>)['full_name']
              as String?
          : null,
      content: json['content'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(
              json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'task_id': taskId,
      'author_id': authorId,
      'content': content,
    };
  }
}
