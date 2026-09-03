import '../../../../app/supabase_config.dart';
import '../../domain/models/task.dart';

/// 호텔 업무 Repository
class TaskRepository {
  final _client = SupabaseConfig.client;

  static const _selectWithJoins = '*, '
      'department:departments!tasks_department_id_fkey(name), '
      'assigner:profiles!tasks_assigner_id_fkey(full_name), '
      'assignee:profiles!tasks_assignee_id_fkey(full_name)';

  /// 전체 업무 (기본 최신순)
  Future<List<Task>> getAll() async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .order('created_at', ascending: false);
    return (data as List)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 부서별 업무
  Future<List<Task>> getByDepartment(String departmentId) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('department_id', departmentId)
        .order('due_date', ascending: true)
        .order('priority', ascending: false);
    return (data as List)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 특정 사용자에게 할당된 업무
  Future<List<Task>> getByAssignee(String userId) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('assignee_id', userId)
        .order('due_date', ascending: true)
        .order('priority', ascending: false);
    return (data as List)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 오늘 마감 + 미완료
  Future<List<Task>> getToday() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .or('due_date.eq.$today,status.eq.in_progress,status.eq.delayed')
        .order('priority', ascending: false);
    return (data as List)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 단건 조회
  Future<Task> get(String id) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('id', id)
        .single();
    return Task.fromJson(data);
  }

  /// 반복 템플릿에서 생성된 인스턴스 조회
  Future<List<Task>> getInstances(String templateId) async {
    final data = await _client
        .from('tasks')
        .select(_selectWithJoins)
        .eq('recurrence_template_id', templateId)
        .order('due_date', ascending: false);
    return (data as List)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 생성 (관리급)
  Future<Task> create(Task task) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    final payload = task.toInsertJson();
    payload['assigner_id'] ??= userId;
    final data = await _client
        .from('tasks')
        .insert(payload)
        .select(_selectWithJoins)
        .single();
    return Task.fromJson(data);
  }

  /// 수정
  Future<Task> update(String id, Task task) async {
    final data = await _client
        .from('tasks')
        .update(task.toUpdateJson())
        .eq('id', id)
        .select(_selectWithJoins)
        .single();
    return Task.fromJson(data);
  }

  /// 상태 변경 (직원 보고 등)
  Future<void> updateStatus(
    String id, {
    required TaskStatus status,
    String? completionNote,
    String? delayReason,
  }) async {
    final updates = <String, dynamic>{
      'status': status.dbValue,
      'completion_note': completionNote,
      'delay_reason': delayReason,
    };
    if (status == TaskStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    } else {
      updates['completed_at'] = null;
    }
    await _client.from('tasks').update(updates).eq('id', id);
  }

  /// 삭제 (관리급)
  Future<void> delete(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  /// 담당자 드롭다운용 사용자 목록
  Future<List<Map<String, dynamic>>> getAssignableUsers() async {
    final data = await _client
        .from('profiles')
        .select('id, full_name, role, department_id')
        .order('full_name');
    return List<Map<String, dynamic>>.from(data);
  }
}
