import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/supabase_config.dart';
import '../data/repositories/task_repository.dart';
import '../domain/models/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

// ─── 필터/정렬 ───

enum TaskFilter {
  all('전체'),
  today('오늘'),
  delayed('지연'),
  completed('완료');

  const TaskFilter(this.label);
  final String label;
}

enum TaskSort {
  newest('최신순'),
  byDueDate('마감일순'),
  byPriority('우선순위순'),
  byAssignee('담당자순'),
  byDepartment('부서순');

  const TaskSort(this.label);
  final String label;
}

final taskFilterProvider =
    StateProvider<TaskFilter>((ref) => TaskFilter.today);

final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.byDueDate);

final taskSearchQueryProvider = StateProvider<String>((ref) => '');

/// 부서 필터 (null = 전체)
final taskDepartmentFilterProvider =
    StateProvider<String?>((ref) => null);

// ─── 모든 업무 (Realtime) ───

final allMyTasksProvider =
    AsyncNotifierProvider<AllMyTasksNotifier, List<Task>>(
  AllMyTasksNotifier.new,
);

class AllMyTasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  FutureOr<List<Task>> build() async {
    _subscribeToChanges();
    return ref.read(taskRepositoryProvider).getAll();
  }

  void _subscribeToChanges() {
    final channel = SupabaseConfig.client.channel('all_tasks');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (_) => _refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      SupabaseConfig.client.removeChannel(channel);
    });
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getAll(),
    );
  }

  Future<void> refresh() => _refresh();

  Future<void> createTask(Task task) async {
    await ref.read(taskRepositoryProvider).create(task);
    await _refresh();
  }

  Future<void> updateTask(String id, Task task) async {
    await ref.read(taskRepositoryProvider).update(id, task);
    await _refresh();
  }

  Future<void> updateStatus(
    String id, {
    required TaskStatus status,
    String? completionNote,
    String? delayReason,
  }) async {
    await ref.read(taskRepositoryProvider).updateStatus(
          id,
          status: status,
          completionNote: completionNote,
          delayReason: delayReason,
        );
    await _refresh();
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).delete(id);
    await _refresh();
  }
}

// ─── 상세/파생 provider ───

final taskDetailProvider =
    FutureProvider.family<Task, String>((ref, id) async {
  return ref.read(taskRepositoryProvider).get(id);
});

/// 반복 템플릿의 인스턴스 목록
final taskInstancesProvider =
    FutureProvider.family<List<Task>, String>((ref, templateId) async {
  return ref.read(taskRepositoryProvider).getInstances(templateId);
});

/// 사용자 목록 (담당자 드롭다운용)
final assignableUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(taskRepositoryProvider).getAssignableUsers();
});

// ─── 필터 적용된 파생 리스트 ───

final filteredTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasksAsync = ref.watch(allMyTasksProvider);
  final filter = ref.watch(taskFilterProvider);
  final sort = ref.watch(taskSortProvider);
  final query = ref.watch(taskSearchQueryProvider).toLowerCase();
  final deptFilter = ref.watch(taskDepartmentFilterProvider);

  return tasksAsync.whenData((tasks) {
    // 템플릿은 리스트에서 제외 (별도 관리 화면)
    var filtered = tasks.where((t) => !t.isTemplate).toList();

    // 부서 필터
    if (deptFilter != null) {
      filtered =
          filtered.where((t) => t.departmentId == deptFilter).toList();
    }

    // 상태 필터
    switch (filter) {
      case TaskFilter.all:
        filtered = filtered
            .where((t) => t.status != TaskStatus.completed)
            .toList();
      case TaskFilter.today:
        filtered = filtered
            .where((t) =>
                t.isDueToday ||
                t.status == TaskStatus.inProgress ||
                t.isDelayed)
            .toList();
      case TaskFilter.delayed:
        filtered = filtered.where((t) => t.isDelayed).toList();
      case TaskFilter.completed:
        filtered = filtered
            .where((t) => t.status == TaskStatus.completed)
            .toList();
    }

    // 검색
    if (query.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(query) ||
            (t.description?.toLowerCase().contains(query) ?? false) ||
            (t.assigneeName?.toLowerCase().contains(query) ?? false) ||
            (t.departmentName?.toLowerCase().contains(query) ?? false) ||
            (t.category?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // 정렬
    switch (sort) {
      case TaskSort.newest:
        filtered.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
      case TaskSort.byDueDate:
        filtered.sort((a, b) {
          final ae = a.dueDate ?? DateTime(9999);
          final be = b.dueDate ?? DateTime(9999);
          return ae.compareTo(be);
        });
      case TaskSort.byPriority:
        filtered.sort((a, b) =>
            b.priority.sortOrder.compareTo(a.priority.sortOrder));
      case TaskSort.byAssignee:
        filtered.sort(
            (a, b) => (a.assigneeName ?? '').compareTo(b.assigneeName ?? ''));
      case TaskSort.byDepartment:
        filtered.sort((a, b) =>
            (a.departmentName ?? '').compareTo(b.departmentName ?? ''));
    }

    return filtered;
  });
});

/// 부서별 그룹핑 (부서명 → 업무 리스트)
final tasksByDepartmentProvider =
    Provider<AsyncValue<Map<String, List<Task>>>>((ref) {
  final tasksAsync = ref.watch(filteredTasksProvider);
  return tasksAsync.whenData((tasks) {
    final grouped = <String, List<Task>>{};
    for (final t in tasks) {
      final key = t.departmentName ?? '(부서 없음)';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped;
  });
});
