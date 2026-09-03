import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/supabase_config.dart';
import '../../projects/providers/project_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../domain/models/calendar_event.dart';

// ─── Filter State ───

/// 이벤트 유형별 토글 필터
final calendarEventTypeFilterProvider =
    StateProvider<Set<CalendarEventType>>((ref) {
  return CalendarEventType.values.toSet(); // 기본: 전부 활성
});

/// 특정 과제만 보기 (null이면 전체)
final calendarProjectFilterProvider =
    StateProvider<String?>((ref) => null);

/// 내 담당만 보기
final calendarMyOnlyProvider = StateProvider<bool>((ref) => false);

/// 현재 선택된 날짜
final calendarSelectedDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

/// 현재 포커스 월
final calendarFocusedDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

// ─── Data Aggregation ───

/// 모든 이벤트를 통합한 Provider
final calendarEventsProvider =
    Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final projectsAsync = ref.watch(projectListProvider);
  final tasksAsync = ref.watch(allMyTasksProvider);

  // 필터
  final typeFilter = ref.watch(calendarEventTypeFilterProvider);
  final projectFilter = ref.watch(calendarProjectFilterProvider);
  final myOnly = ref.watch(calendarMyOnlyProvider);

  // 모든 데이터가 로딩 중이면 로딩 표시
  if (projectsAsync.isLoading && tasksAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final events = <CalendarEvent>[];

  // 1. 과제 이벤트 (수행기간 막대)
  if (typeFilter.contains(CalendarEventType.project)) {
    final projects = projectsAsync.valueOrNull ?? [];
    for (final p in projects) {
      if (!p.showInCalendar) continue;
      if (projectFilter != null && p.id != projectFilter) continue;
      if (p.startDate == null && p.endDate == null) continue;

      events.add(CalendarEvent(
        id: 'project_${p.id}',
        type: CalendarEventType.project,
        title: p.title,
        date: p.startDate ?? p.endDate!,
        endDate: p.endDate,
        subtitle: p.status.label,
        projectId: p.id,
        projectTitle: p.title,
        isAllDay: true,
        routePath: '/projects/${p.id}',
      ));
    }
  }

  // 2. 태스크 이벤트 (마감일)
  if (typeFilter.contains(CalendarEventType.task)) {
    final currentUserId =
        SupabaseConfig.auth.currentUser?.id;
    final tasks = tasksAsync.valueOrNull ?? [];
    for (final t in tasks) {
      if (!t.showInCalendar) continue;
      if (projectFilter != null && t.projectId != projectFilter) continue;
      if (myOnly && t.assigneeId != currentUserId) continue;
      if (t.plannedEnd == null && t.plannedStart == null) continue;
      if (t.status.name == 'completed') continue;

      final startDate = t.plannedStart ?? t.plannedEnd!;
      final endDate = t.plannedEnd ?? t.plannedStart;
      events.add(CalendarEvent(
        id: 'task_${t.id}',
        type: CalendarEventType.task,
        title: t.title,
        date: startDate,
        endDate: endDate,
        subtitle: '${t.status.label} · Plan ${t.planType.value}',
        projectId: t.projectId,
        isAllDay: true,
        isDelayed: t.isDelayed,
        routePath: t.projectId != null
            ? '/projects/${t.projectId}/tasks/${t.id}'
            : '/tasks/${t.id}',
      ));
    }
  }

  // 날짜 순 정렬
  events.sort((a, b) => a.date.compareTo(b.date));

  return AsyncValue.data(events);
});

/// 특정 날짜의 이벤트 목록
final eventsForDayProvider =
    Provider.family<List<CalendarEvent>, DateTime>((ref, day) {
  final eventsAsync = ref.watch(calendarEventsProvider);
  final events = eventsAsync.valueOrNull ?? [];
  return events.where((e) => e.occursOn(day)).toList();
});

/// 이번 주 이벤트 (대시보드용)
final thisWeekEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final eventsAsync = ref.watch(calendarEventsProvider);
  final events = eventsAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekEnd = today.add(const Duration(days: 7));

  return events.where((e) {
    final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
    return !eventDate.isBefore(today) && eventDate.isBefore(weekEnd);
  }).toList();
});

