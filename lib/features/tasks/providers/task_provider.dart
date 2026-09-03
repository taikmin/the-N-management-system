import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/supabase_config.dart';
import '../../projects/domain/models/project.dart';
import '../../projects/providers/project_provider.dart';
import '../data/repositories/task_repository.dart';
import '../domain/models/daily_log.dart';
import '../domain/models/task.dart';
import '../domain/models/task_comment.dart';
import '../domain/models/task_update.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

// ─── 드래그 상태 ───

/// 드래그 중 여부 (자동 스크롤 트리거용)
final dragActiveProvider =
    StateProvider<bool>((ref) => false);

// ─── 필터, 정렬, 그룹핑 ───

/// 태스크 필터 종류
enum TaskFilter { all, today, delayed, completed }

/// 완료 탭 하위 필터
enum CompletedSubFilter {
  fullOnly('전체 완료'),
  includePartial('부분 완료 포함');

  const CompletedSubFilter(this.label);
  final String label;
}

/// 태스크 정렬 종류
enum TaskSort {
  newest('최신순'),
  oldest('오래된순'),
  byDeadline('마감일순'),
  byPriority('우선순위순'),
  byProject('과제별'),
  byCreator('게시자별'),
  byAssignee('담당자별');

  const TaskSort(this.label);
  final String label;
}

/// 현재 선택된 필터
final taskFilterProvider =
    StateProvider<TaskFilter>((ref) => TaskFilter.all);

/// 현재 선택된 정렬
final taskSortProvider =
    StateProvider<TaskSort>((ref) => TaskSort.newest);

/// 과제별 그룹핑 토글
final taskGroupByProjectProvider =
    StateProvider<bool>((ref) => false);

/// 완료 탭 하위 필터
final completedSubFilterProvider =
    StateProvider<CompletedSubFilter>(
  (ref) => CompletedSubFilter.includePartial,
);

// ─── 과제별 태스크 (기존) ───

/// 과제별 태스크 목록 Provider (Realtime)
final projectTasksProvider = AsyncNotifierProvider.family<
    ProjectTasksNotifier, List<Task>, String>(
  ProjectTasksNotifier.new,
);

class ProjectTasksNotifier
    extends FamilyAsyncNotifier<List<Task>, String> {
  @override
  FutureOr<List<Task>> build(String arg) async {
    _subscribeToChanges(arg);
    return ref
        .read(taskRepositoryProvider)
        .getTasksByProject(arg);
  }

  void _subscribeToChanges(String projectId) {
    final channel =
        SupabaseConfig.client.channel('tasks_$projectId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: projectId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      SupabaseConfig.client.removeChannel(channel);
    });
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getTasksByProject(arg),
    );
  }

  Future<void> refresh() => _refresh();

  Future<void> createTask(Task task) async {
    await ref.read(taskRepositoryProvider).createTask(task);
    await _refresh();
  }

  Future<void> updateTask(String id, Task task) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTask(id, task);
    await _refresh();
  }

  Future<void> updateStatus(
    String id,
    TaskStatus status,
  ) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTaskStatus(id, status);
    await _refresh();
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    await _refresh();
  }
}

// ─── 내 전체 태스크 (기존 — 대시보드 호환) ───

/// 내 전체 태스크
final myTasksProvider =
    AsyncNotifierProvider<MyTasksNotifier, List<Task>>(
  MyTasksNotifier.new,
);

class MyTasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  FutureOr<List<Task>> build() async {
    return ref.read(taskRepositoryProvider).getAllTasks();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getAllTasks(),
    );
  }
}

/// 오늘의 태스크
final todayTasksProvider =
    FutureProvider<List<Task>>((ref) async {
  return ref.read(taskRepositoryProvider).getTodayTasks();
});

// ─── 내 모든 태스크 (Realtime, Todo 리스트용) ───

/// 내 모든 태스크 Provider (Realtime 구독)
final allMyTasksProvider =
    AsyncNotifierProvider<AllMyTasksNotifier, List<Task>>(
  AllMyTasksNotifier.new,
);

class AllMyTasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  FutureOr<List<Task>> build() async {
    _subscribeToChanges();
    return ref
        .read(taskRepositoryProvider)
        .getAllTasksRecent();
  }

  void _subscribeToChanges() {
    final channel =
        SupabaseConfig.client.channel('all_tasks');
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
      () => ref
          .read(taskRepositoryProvider)
          .getAllTasksRecent(),
    );
  }

  Future<void> refresh() => _refresh();

  Future<Task> quickCreate(String title) async {
    final task = await ref
        .read(taskRepositoryProvider)
        .quickCreateTask(title);
    await _refresh();
    return task;
  }

  Future<void> toggleComplete(
    String id,
    TaskStatus currentStatus,
  ) async {
    await ref
        .read(taskRepositoryProvider)
        .toggleTaskComplete(id, currentStatus);
    await _refresh();
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    await _refresh();
  }

  Future<void> createTask(Task task) async {
    await ref.read(taskRepositoryProvider).createTask(task);
    await _refresh();
  }

  Future<void> updateTask(String id, Task task) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTask(id, task);
    await _refresh();
  }

  /// 배치 업무 생성 (회의록 업무 등록용)
  Future<List<Task>> createTasks(
    List<Task> tasks,
  ) async {
    final created = await ref
        .read(taskRepositoryProvider)
        .createTasks(tasks);
    await _refresh();
    return created;
  }

  /// 업무 이동 (parent_task_id 변경)
  Future<void> moveTask(
    String taskId, {
    required String? newParentTaskId,
  }) async {
    await ref
        .read(taskRepositoryProvider)
        .moveTask(
          taskId,
          newParentTaskId: newParentTaskId,
        );
    await _refresh();
  }

  Future<void> updateColorTag(
    String id,
    ColorTag tag,
  ) async {
    await ref
        .read(taskRepositoryProvider)
        .updateColorTag(id, tag);
    await _refresh();
  }

  /// 연계 업무 순서 변경
  Future<void> reorderSubTasks(
    List<String> orderedIds,
  ) async {
    await ref
        .read(taskRepositoryProvider)
        .reorderSubTasks(orderedIds);
    await _refresh();
  }
}

/// 태스크 검색어
final taskSearchQueryProvider =
    StateProvider<String>((ref) => '');

/// 검색어 매칭 헬퍼
bool _matchesQuery(Task t, String query) {
  return t.title
          .toLowerCase()
          .contains(query) ||
      (t.assigneeName
              ?.toLowerCase()
              .contains(query) ??
          false) ||
      (t.creatorName
              ?.toLowerCase()
              .contains(query) ??
          false) ||
      (t.projectTitle
              ?.toLowerCase()
              .contains(query) ??
          false) ||
      (t.category
              ?.toLowerCase()
              .contains(query) ??
          false) ||
      (t.description
              ?.toLowerCase()
              .contains(query) ??
          false);
}

/// 검색에 매칭된 연계 업무 ID 세트
final matchedSubTaskIdsProvider =
    Provider<Set<String>>((ref) {
  final searchQuery =
      ref.watch(taskSearchQueryProvider).toLowerCase();
  if (searchQuery.isEmpty) return {};

  final tasks =
      ref.watch(allMyTasksProvider).valueOrNull ?? [];
  final matched = <String>{};
  for (final t in tasks) {
    if (t.parentTaskId != null &&
        _matchesQuery(t, searchQuery)) {
      matched.add(t.id);
    }
  }
  return matched;
});

/// 독립업무 + 연계업무 중 가장 최근 완료 시점
DateTime _latestCompletionTime(
  Task parent,
  Map<String, List<Task>> subTasksMap,
) {
  var latest = parent.status == TaskStatus.completed
      ? (parent.updatedAt ?? DateTime(0))
      : DateTime(0);
  final subs = subTasksMap[parent.id];
  if (subs != null) {
    for (final s in subs) {
      if (s.status == TaskStatus.completed) {
        final su = s.updatedAt ?? DateTime(0);
        if (su.isAfter(latest)) latest = su;
      }
    }
  }
  return latest;
}

/// 필터링된 태스크 목록 (부모 태스크 + 검색 시
/// 연계 업무 매칭된 부모도 포함 + 정렬)
final filteredTasksProvider =
    Provider<AsyncValue<List<Task>>>((ref) {
  final tasksAsync = ref.watch(allMyTasksProvider);
  final filter = ref.watch(taskFilterProvider);
  final sort = ref.watch(taskSortProvider);
  final searchQuery =
      ref.watch(taskSearchQueryProvider).toLowerCase();
  final matchedSubIds =
      ref.watch(matchedSubTaskIdsProvider);
  final subTasksMap =
      ref.watch(subTasksMapProvider);
  final completedSub =
      ref.watch(completedSubFilterProvider);

  return tasksAsync.whenData((tasks) {
    // 하위 태스크는 메인 리스트에서 제외
    var filtered = tasks
        .where((t) => t.parentTaskId == null)
        .toList();

    switch (filter) {
      case TaskFilter.all:
        filtered = filtered
            .where(
                (t) => t.status != TaskStatus.completed)
            .toList();
      case TaskFilter.today:
        filtered = filtered
            .where((t) =>
                t.isDueToday ||
                t.status == TaskStatus.inProgress)
            .toList();
      case TaskFilter.delayed:
        filtered =
            filtered.where((t) => t.isDelayed).toList();
      case TaskFilter.completed:
        if (completedSub ==
            CompletedSubFilter.includePartial) {
          // 독립업무 완료 OR 연계업무 중 하나라도 완료
          filtered = filtered.where((t) {
            if (t.status == TaskStatus.completed) {
              return true;
            }
            final subs = subTasksMap[t.id];
            if (subs != null) {
              return subs.any(
                (s) =>
                    s.status == TaskStatus.completed,
              );
            }
            return false;
          }).toList();
        } else {
          filtered = filtered
              .where((t) =>
                  t.status == TaskStatus.completed)
              .toList();
        }
        // 최신 완료 시점 기준 정렬
        filtered.sort((a, b) {
          final au = _latestCompletionTime(
            a,
            subTasksMap,
          );
          final bu = _latestCompletionTime(
            b,
            subTasksMap,
          );
          return bu.compareTo(au);
        });
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        // 부모 자체가 매칭
        if (_matchesQuery(t, searchQuery)) return true;
        // 연계 업무 중 매칭된 것이 있으면 부모도 포함
        final subs = subTasksMap[t.id];
        if (subs != null) {
          return subs.any(
            (s) => matchedSubIds.contains(s.id),
          );
        }
        return false;
      }).toList();
    }

    // 최신 활동 시점 (본인 또는 연계 업무 중 최신)
    DateTime latestActivity(Task t) {
      var latest = t.createdAt ?? DateTime(0);
      final subs = subTasksMap[t.id];
      if (subs != null) {
        for (final s in subs) {
          final sc = s.createdAt;
          if (sc != null && sc.isAfter(latest)) {
            latest = sc;
          }
        }
      }
      return latest;
    }

    // 정렬 적용
    switch (sort) {
      case TaskSort.newest:
        filtered.sort((a, b) =>
            latestActivity(b)
                .compareTo(latestActivity(a)));
      case TaskSort.oldest:
        filtered.sort((a, b) =>
            latestActivity(a)
                .compareTo(latestActivity(b)));
      case TaskSort.byDeadline:
        filtered.sort((a, b) {
          final ae = a.plannedEnd ?? DateTime(9999);
          final be = b.plannedEnd ?? DateTime(9999);
          return ae.compareTo(be);
        });
      case TaskSort.byPriority:
        final order = {
          TaskPriority.urgent: 0,
          TaskPriority.high: 1,
          TaskPriority.medium: 2,
          TaskPriority.low: 3,
        };
        filtered.sort((a, b) =>
            (order[a.priority] ?? 2)
                .compareTo(order[b.priority] ?? 2));
      case TaskSort.byProject:
        filtered.sort((a, b) =>
            (a.projectTitle ?? '독립 업무')
                .compareTo(b.projectTitle ?? '독립 업무'));
      case TaskSort.byCreator:
        filtered.sort((a, b) =>
            (a.creatorName ?? '')
                .compareTo(b.creatorName ?? ''));
      case TaskSort.byAssignee:
        filtered.sort((a, b) {
          final an = a.assigneeName;
          final bn = b.assigneeName;
          if (an == null && bn == null) return 0;
          if (an == null) return 1;
          if (bn == null) return -1;
          return an.compareTo(bn);
        });
    }

    return filtered;
  });
});

/// 부모 태스크별 하위 태스크 맵 (메모리 내 그룹핑)
/// order_index → created_at 순 정렬
final subTasksMapProvider =
    Provider<Map<String, List<Task>>>((ref) {
  final tasks =
      ref.watch(allMyTasksProvider).valueOrNull ?? [];
  final map = <String, List<Task>>{};
  for (final task in tasks) {
    if (task.parentTaskId != null) {
      map
          .putIfAbsent(task.parentTaskId!, () => [])
          .add(task);
    }
  }
  // NEW 항목 우선 → order_index 순 → created_at 순
  for (final list in map.values) {
    list.sort((a, b) {
      // NEW(24h 이내) 항목을 상위로
      if (a.isNew && !b.isNew) return -1;
      if (!a.isNew && b.isNew) return 1;
      // NEW끼리는 최신순
      if (a.isNew && b.isNew) {
        return (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0));
      }
      // 나머지는 order_index 순
      final cmp = a.orderIndex.compareTo(b.orderIndex);
      if (cmp != 0) return cmp;
      return (a.createdAt ?? DateTime(0))
          .compareTo(b.createdAt ?? DateTime(0));
    });
  }
  return map;
});

/// 과제별 그룹핑된 태스크 맵
final groupedTasksProvider =
    Provider<AsyncValue<Map<String, List<Task>>>>((ref) {
  final tasksAsync = ref.watch(filteredTasksProvider);

  return tasksAsync.whenData((tasks) {
    final grouped = <String, List<Task>>{};
    for (final task in tasks) {
      final key = task.projectTitle ?? '독립 업무';
      grouped.putIfAbsent(key, () => []).add(task);
    }
    return grouped;
  });
});

/// 과제 목록 (태스크 생성 시 드롭다운용)
final projectsForDropdownProvider =
    Provider<AsyncValue<List<Project>>>((ref) {
  return ref.watch(projectListProvider);
});

// ─── 기존 유지 ───

/// 하위 태스크
final subTasksProvider =
    FutureProvider.family<List<Task>, String>(
  (ref, parentId) async {
    return ref
        .read(taskRepositoryProvider)
        .getSubTasks(parentId);
  },
);

/// 태스크 상세
final taskDetailProvider =
    FutureProvider.family<Task, String>((ref, id) async {
  return ref.read(taskRepositoryProvider).getTask(id);
});

/// 일일 기록
final dailyLogsProvider =
    FutureProvider.family<List<DailyLog>, String>(
  (ref, taskId) async {
    return ref
        .read(taskRepositoryProvider)
        .getDailyLogs(taskId);
  },
);

/// 댓글
final taskCommentsProvider =
    FutureProvider.family<List<TaskComment>, String>(
  (ref, taskId) async {
    return ref
        .read(taskRepositoryProvider)
        .getComments(taskId);
  },
);

/// 연계 업무
final taskUpdatesProvider =
    FutureProvider.family<List<TaskUpdate>, String>(
  (ref, taskId) async {
    return ref
        .read(taskRepositoryProvider)
        .getTaskUpdates(taskId);
  },
);

/// 전체 사용자 목록 (담당자 드롭다운용)
final allUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    return ref
        .read(taskRepositoryProvider)
        .getAllUsers();
  },
);
