import '../../../../app/supabase_config.dart';
import '../../domain/models/department.dart';

/// 부서 데이터 Repository
class DepartmentRepository {
  final _client = SupabaseConfig.client;

  static const _selectFragment =
      '*, lead:profiles!departments_lead_id_fkey(full_name)';

  /// 부서 목록 조회 (sort_order 순)
  Future<List<Department>> getAll() async {
    final data = await _client
        .from('departments')
        .select(_selectFragment)
        .order('sort_order');
    return (data as List)
        .map((json) => Department.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 부서 단건 조회
  Future<Department> get(String id) async {
    final data = await _client
        .from('departments')
        .select(_selectFragment)
        .eq('id', id)
        .single();
    return Department.fromJson(data);
  }

  /// 생성 (관리자 이상)
  Future<Department> create(Department department) async {
    final data = await _client
        .from('departments')
        .insert(department.toInsertJson())
        .select(_selectFragment)
        .single();
    return Department.fromJson(data);
  }

  /// 수정
  Future<Department> update(String id, Department department) async {
    final data = await _client
        .from('departments')
        .update(department.toUpdateJson())
        .eq('id', id)
        .select(_selectFragment)
        .single();
    return Department.fromJson(data);
  }

  /// 삭제 (관리자 이상)
  Future<void> delete(String id) async {
    await _client.from('departments').delete().eq('id', id);
  }

  /// 부서 소속 직원 목록
  Future<List<Map<String, dynamic>>> getMembers(String departmentId) async {
    final data = await _client
        .from('profiles')
        .select('id, full_name, role, email, phone')
        .eq('department_id', departmentId)
        .order('full_name');
    return List<Map<String, dynamic>>.from(data);
  }

  /// 부서별 업무 통계
  Future<Map<String, int>> getTaskStats(String departmentId) async {
    final data = await _client
        .from('tasks')
        .select('status')
        .eq('department_id', departmentId);

    final stats = <String, int>{
      'total': 0,
      'assigned': 0,
      'in_progress': 0,
      'completed': 0,
      'incomplete': 0,
      'delayed': 0,
    };
    for (final row in data as List) {
      final status = row['status'] as String;
      stats['total'] = (stats['total'] ?? 0) + 1;
      stats[status] = (stats[status] ?? 0) + 1;
    }
    return stats;
  }
}
