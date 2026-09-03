import '../../../../app/supabase_config.dart';
import '../../domain/models/project.dart';

/// 과제 데이터 Repository
class ProjectRepository {
  final _client = SupabaseConfig.client;

  /// 내 과제 목록 조회 (owner 또는 멤버)
  Future<List<Project>> getMyProjects() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('projects')
        .select('*, profiles!projects_owner_id_fkey(full_name), '
          'assignee:profiles!projects_assignee_id_fkey(full_name)')
        .order('updated_at', ascending: false);

    return (data as List).map((json) => Project.fromJson(json)).toList();
  }

  /// 과제 상세 조회
  Future<Project> getProject(String id) async {
    final data = await _client
        .from('projects')
        .select('*, profiles!projects_owner_id_fkey(full_name), '
          'assignee:profiles!projects_assignee_id_fkey(full_name)')
        .eq('id', id)
        .single();

    return Project.fromJson(data);
  }

  /// 과제 생성
  Future<Project> createProject(Project project) async {
    final data = await _client
        .from('projects')
        .insert(project.toInsertJson())
        .select('*, profiles!projects_owner_id_fkey(full_name), '
          'assignee:profiles!projects_assignee_id_fkey(full_name)')
        .single();

    // 자동으로 owner를 멤버에 추가
    await _client.from('project_members').insert({
      'project_id': data['id'],
      'user_id': project.ownerId,
      'role': 'owner',
    });

    return Project.fromJson(data);
  }

  /// 과제 수정
  Future<Project> updateProject(String id, Project project) async {
    final data = await _client
        .from('projects')
        .update(project.toUpdateJson())
        .eq('id', id)
        .select('*, profiles!projects_owner_id_fkey(full_name), '
          'assignee:profiles!projects_assignee_id_fkey(full_name)')
        .single();

    return Project.fromJson(data);
  }

  /// 과제 삭제
  Future<void> deleteProject(String id) async {
    await _client.from('projects').delete().eq('id', id);
  }

  /// 과제별 팀원 목록 조회
  Future<List<Map<String, dynamic>>> getProjectMembers(
    String projectId,
  ) async {
    final data = await _client
        .from('project_members')
        .select(
          'id, user_id, role, '
          'profiles!project_members_user_id_fkey(full_name, department)',
        )
        .eq('project_id', projectId)
        .order('role');

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// 과제 팀원 설정 (기존 멤버 삭제 후 재생성)
  Future<void> updateProjectMembers(
    String projectId,
    String ownerId,
    List<String> memberIds,
  ) async {
    // 기존 멤버 삭제
    await _client
        .from('project_members')
        .delete()
        .eq('project_id', projectId);

    // owner + members 삽입
    final rows = <Map<String, dynamic>>[];
    rows.add({
      'project_id': projectId,
      'user_id': ownerId,
      'role': 'owner',
    });
    for (final memberId in memberIds) {
      if (memberId == ownerId) continue;
      rows.add({
        'project_id': projectId,
        'user_id': memberId,
        'role': 'member',
      });
    }
    if (rows.isNotEmpty) {
      await _client.from('project_members').insert(rows);
    }
  }

  /// 과제별 태스크 통계
  Future<Map<String, int>> getTaskStats(String projectId) async {
    final data = await _client
        .from('tasks')
        .select('status')
        .eq('project_id', projectId);

    final stats = <String, int>{
      'total': 0,
      'planned': 0,
      'in_progress': 0,
      'delayed': 0,
      'completed': 0,
      'blocked': 0,
    };

    for (final row in data as List) {
      final status = row['status'] as String;
      stats['total'] = (stats['total'] ?? 0) + 1;
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }
}
