import '../../../../app/supabase_config.dart';
import '../../domain/models/daily_log.dart';
import '../../domain/models/task.dart';
import '../../domain/models/task_comment.dart';
import '../../domain/models/task_update.dart';

/// 태스크 데이터 Repository
class TaskRepository {
  final _client = SupabaseConfig.client;

  static const _selectWithJoins =
      '*, profiles!tasks_assignee_id_fkey(full_name), '
      'creator:profiles!tasks_created_by_fkey(full_name), '
      'projects(title)';

  /// 과제별 태스크 목록
  Future<List<Task>> getTasksByProject(String projectId) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('project_id', projectId)
        .order('order_index')
        .order('created_at');

    return (data as List)
        .map((json) => Task.fromJson(json))
        .toList();
  }

  /// 전체 태스크 목록 (공용 — 모든 프로젝트)
  Future<List<Task>> getAllTasks() async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .order('planned_end')
        .order('priority');

    return (data as List)
        .map((json) => Task.fromJson(json))
        .toList();
  }

  /// 전체 태스크 최신순 (공용)
  Future<List<Task>> getAllTasksRecent() async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .order('created_at', ascending: false);

    return (data as List)
        .map((json) => Task.fromJson(json))
        .toList();
  }

  /// 오늘의 태스크 (마감일 오늘이거나, 진행중이거나, 지연)
  Future<List<Task>> getTodayTasks() async {
    final today =
        DateTime.now().toIso8601String().split('T').first;

    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .or('planned_end.eq.$today,'
            'status.eq.in_progress,status.eq.delayed')
        .order('priority', ascending: false);

    return (data as List)
        .map((json) => Task.fromJson(json))
        .toList();
  }

  /// 태스크 상세 조회
  Future<Task> getTask(String id) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('id', id)
        .single();

    return Task.fromJson(data);
  }

  /// 하위 태스크 조회
  Future<List<Task>> getSubTasks(String parentTaskId) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('parent_task_id', parentTaskId)
        .order('order_index');

    return (data as List)
        .map((json) => Task.fromJson(json))
        .toList();
  }

  /// 태스크 생성
  Future<Task> createTask(Task task) async {
    final data = await _client
        .from('tasks')
        .insert(task.toInsertJson())
        .select(_selectWithJoins)
        .single();

    return Task.fromJson(data);
  }

  /// 태스크 배치 생성 (회의록 업무 등록용)
  Future<List<Task>> createTasks(
    List<Task> tasks,
  ) async {
    if (tasks.isEmpty) return [];
    final data = await _client
        .from('tasks')
        .insert(
          tasks.map((t) => t.toInsertJson()).toList(),
        )
        .select(_selectWithJoins);

    return (data as List)
        .map((json) => Task.fromJson(json))
        .toList();
  }

  /// 빠른 태스크 생성 (제목만)
  Future<Task> quickCreateTask(String title) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    final data = await _client
        .from('tasks')
        .insert({
          'title': title,
          'assignee_id': userId,
          'status': 'planned',
          'priority': 'medium',
          'plan_type': 'A',
          'order_index': 0,
        })
        .select(_selectWithJoins)
        .single();

    return Task.fromJson(data);
  }

  /// 태스크 완료 토글
  Future<void> toggleTaskComplete(
    String id,
    TaskStatus currentStatus,
  ) async {
    final newStatus = currentStatus == TaskStatus.completed
        ? TaskStatus.planned
        : TaskStatus.completed;

    final updates = <String, dynamic>{
      'status': newStatus.dbValue,
    };

    if (newStatus == TaskStatus.completed) {
      updates['actual_end'] =
          DateTime.now().toIso8601String().split('T').first;
    } else {
      updates['actual_end'] = null;
    }

    await _client.from('tasks').update(updates).eq('id', id);
  }

  /// 태스크 수정
  Future<Task> updateTask(String id, Task task) async {
    final data = await _client
        .from('tasks')
        .update(task.toUpdateJson())
        .eq('id', id)
        .select(_selectWithJoins)
        .single();

    return Task.fromJson(data);
  }

  /// 태스크 상태만 변경
  Future<void> updateTaskStatus(
    String id,
    TaskStatus status,
  ) async {
    final updates = <String, dynamic>{
      'status': status.dbValue,
    };

    // 진행 시작 시 actual_start 자동 기록
    if (status == TaskStatus.inProgress) {
      updates['actual_start'] =
          DateTime.now().toIso8601String().split('T').first;
    }
    // 완료 시 actual_end 자동 기록
    if (status == TaskStatus.completed) {
      updates['actual_end'] =
          DateTime.now().toIso8601String().split('T').first;
    }

    await _client.from('tasks').update(updates).eq('id', id);
  }

  /// 태스크 삭제
  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  /// 업무 이동 (parent_task_id 변경)
  Future<void> moveTask(
    String taskId, {
    required String? newParentTaskId,
  }) async {
    await _client.from('tasks').update({
      'parent_task_id': newParentTaskId,
    }).eq('id', taskId);
  }

  // ─── Daily Logs ───

  /// 태스크별 일일 기록 조회
  Future<List<DailyLog>> getDailyLogs(String taskId) async {
    final data = await _client
        .from('daily_logs')
        .select(
          '*, profiles!daily_logs_author_id_fkey(full_name)',
        )
        .eq('task_id', taskId)
        .order('log_date', ascending: false);

    return (data as List)
        .map((json) => DailyLog.fromJson(json))
        .toList();
  }

  /// 일일 기록 생성
  Future<DailyLog> createDailyLog(DailyLog log) async {
    final data = await _client
        .from('daily_logs')
        .insert(log.toInsertJson())
        .select(
          '*, profiles!daily_logs_author_id_fkey(full_name)',
        )
        .single();

    return DailyLog.fromJson(data);
  }

  /// 일일 기록 수정
  Future<void> updateDailyLog(
    String id, {
    required String content,
    String? issues,
    String? nextPlan,
  }) async {
    await _client.from('daily_logs').update({
      'content': content,
      'issues': issues,
      'next_plan': nextPlan,
    }).eq('id', id);
  }

  /// 일일 기록 삭제
  Future<void> deleteDailyLog(String id) async {
    await _client.from('daily_logs').delete().eq('id', id);
  }

  // ─── Comments ───

  /// 태스크별 댓글 조회
  Future<List<TaskComment>> getComments(
    String taskId,
  ) async {
    final data = await _client
        .from('task_comments')
        .select(
          '*, profiles!task_comments_author_id_fkey(full_name)',
        )
        .eq('task_id', taskId)
        .order('created_at');

    return (data as List)
        .map((json) => TaskComment.fromJson(json))
        .toList();
  }

  /// 댓글 작성
  Future<TaskComment> createComment(
    TaskComment comment,
  ) async {
    final data = await _client
        .from('task_comments')
        .insert(comment.toInsertJson())
        .select(
          '*, profiles!task_comments_author_id_fkey(full_name)',
        )
        .single();

    return TaskComment.fromJson(data);
  }

  /// 댓글 수정
  Future<void> updateComment(
    String id,
    String content,
  ) async {
    await _client
        .from('task_comments')
        .update({'content': content})
        .eq('id', id);
  }

  /// 댓글 삭제
  Future<void> deleteComment(String id) async {
    await _client
        .from('task_comments')
        .delete()
        .eq('id', id);
  }

  // ─── Task Updates (연계 업무) ───

  /// 연계 업무 조회
  Future<List<TaskUpdate>> getTaskUpdates(
    String taskId,
  ) async {
    final data = await _client
        .from('task_updates')
        .select(
          '*, profiles!task_updates_author_id_fkey'
          '(full_name)',
        )
        .eq('task_id', taskId)
        .order('created_at');

    return (data as List)
        .map((json) => TaskUpdate.fromJson(json))
        .toList();
  }

  /// 연계 업무 생성
  Future<TaskUpdate> createTaskUpdate(
    TaskUpdate update,
  ) async {
    final data = await _client
        .from('task_updates')
        .insert(update.toInsertJson())
        .select(
          '*, profiles!task_updates_author_id_fkey'
          '(full_name)',
        )
        .single();

    return TaskUpdate.fromJson(data);
  }

  /// 연계 업무 삭제
  Future<void> deleteTaskUpdate(String id) async {
    await _client
        .from('task_updates')
        .delete()
        .eq('id', id);
  }

  // ─── Reorder Sub-Tasks ───

  /// 연계 업무 순서 일괄 변경
  Future<void> reorderSubTasks(
    List<String> orderedIds,
  ) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _client
          .from('tasks')
          .update({'order_index': i})
          .eq('id', orderedIds[i]);
    }
  }

  // ─── Color Tag ───

  /// 색상 태그 변경
  Future<void> updateColorTag(
    String taskId,
    ColorTag tag,
  ) async {
    await _client
        .from('tasks')
        .update({'color_tag': tag.value})
        .eq('id', taskId);
  }

  // ─── Users ───

  /// 전체 사용자 목록 (담당자 드롭다운용)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final data = await _client
        .from('profiles')
        .select('id, full_name, department')
        .order('full_name');

    return (data as List).cast<Map<String, dynamic>>();
  }
}
