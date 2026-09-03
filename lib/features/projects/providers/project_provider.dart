import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/supabase_config.dart';
import '../data/repositories/project_repository.dart';
import '../domain/models/project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

/// 과제 목록 Provider (Realtime 구독)
final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, List<Project>>(
  ProjectListNotifier.new,
);

class ProjectListNotifier extends AsyncNotifier<List<Project>> {
  @override
  FutureOr<List<Project>> build() async {
    // Realtime 구독
    _subscribeToChanges();
    return ref.read(projectRepositoryProvider).getMyProjects();
  }

  void _subscribeToChanges() {
    final channel = SupabaseConfig.client.channel('projects_realtime');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'projects',
          callback: (_) => _refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      SupabaseConfig.client.removeChannel(channel);
    });
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(projectRepositoryProvider).getMyProjects(),
    );
  }

  Future<void> refresh() => _refresh();

  Future<void> createProject(Project project) async {
    await ref.read(projectRepositoryProvider).createProject(project);
    await _refresh();
  }

  Future<void> updateProject(String id, Project project) async {
    await ref.read(projectRepositoryProvider).updateProject(id, project);
    await _refresh();
  }

  Future<void> deleteProject(String id) async {
    await ref.read(projectRepositoryProvider).deleteProject(id);
    await _refresh();
  }
}

/// 단일 과제 상세 Provider
final projectDetailProvider =
    FutureProvider.family<Project, String>((ref, id) async {
  return ref.read(projectRepositoryProvider).getProject(id);
});

/// 과제별 태스크 통계
final projectTaskStatsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, projectId) async {
  return ref.read(projectRepositoryProvider).getTaskStats(projectId);
});

/// 과제 정렬 종류
enum ProjectSort {
  newest('최신순'),
  oldest('오래된순'),
  byDeadline('마감일순'),
  byName('이름순'),
  byOwner('책임자별');

  const ProjectSort(this.label);
  final String label;
}

/// 과제 상태 필터
final projectStatusFilterProvider =
    StateProvider<ProjectStatus?>((ref) => null);

/// 과제 검색어
final projectSearchQueryProvider = StateProvider<String>((ref) => '');

/// 과제 정렬
final projectSortProvider =
    StateProvider<ProjectSort>((ref) => ProjectSort.newest);

/// 필터링된 과제 목록
final filteredProjectListProvider = Provider<AsyncValue<List<Project>>>((ref) {
  final projectsAsync = ref.watch(projectListProvider);
  final statusFilter = ref.watch(projectStatusFilterProvider);
  final searchQuery = ref.watch(projectSearchQueryProvider).toLowerCase();
  final sort = ref.watch(projectSortProvider);

  return projectsAsync.whenData((projects) {
    var filtered = projects;

    if (statusFilter != null) {
      filtered = filtered.where((p) => p.status == statusFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.title.toLowerCase().contains(searchQuery) ||
            (p.projectNumber?.toLowerCase().contains(searchQuery) ?? false) ||
            (p.description?.toLowerCase().contains(searchQuery) ?? false) ||
            (p.ownerName?.toLowerCase().contains(searchQuery) ?? false) ||
            (p.assigneeName?.toLowerCase().contains(searchQuery) ?? false) ||
            (p.leadInstitution.toLowerCase().contains(searchQuery));
      }).toList();
    }

    // 정렬 적용
    switch (sort) {
      case ProjectSort.newest:
        filtered.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
      case ProjectSort.oldest:
        filtered.sort((a, b) => (a.createdAt ?? DateTime(0))
            .compareTo(b.createdAt ?? DateTime(0)));
      case ProjectSort.byDeadline:
        filtered.sort((a, b) {
          final ae = a.endDate ?? DateTime(9999);
          final be = b.endDate ?? DateTime(9999);
          return ae.compareTo(be);
        });
      case ProjectSort.byName:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case ProjectSort.byOwner:
        filtered.sort((a, b) =>
            (a.ownerName ?? '').compareTo(b.ownerName ?? ''));
    }

    return filtered;
  });
});

/// 과제별 팀원 목록
final projectMembersProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, projectId) async {
  return ref
      .read(projectRepositoryProvider)
      .getProjectMembers(projectId);
});
