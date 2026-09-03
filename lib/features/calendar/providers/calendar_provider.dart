import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/supabase_config.dart';
import '../../tasks/providers/task_provider.dart';
import '../domain/models/calendar_event.dart';

// ─── Filter State ───

final calendarEventTypeFilterProvider =
    StateProvider<Set<CalendarEventType>>((ref) {
  return CalendarEventType.values.toSet();
});

/// 특정 부서만 보기 (null이면 전체)
final calendarDepartmentFilterProvider =
    StateProvider<String?>((ref) => null);

final calendarMyOnlyProvider = StateProvider<bool>((ref) => false);

final calendarSelectedDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final calendarFocusedDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

// ─── Data Aggregation ───

/// Tasks의 due_date 기반 이벤트 (호텔 도메인)
final calendarEventsProvider =
    Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final tasksAsync = ref.watch(allMyTasksProvider);
  final typeFilter = ref.watch(calendarEventTypeFilterProvider);
  final deptFilter = ref.watch(calendarDepartmentFilterProvider);
  final myOnly = ref.watch(calendarMyOnlyProvider);

  if (tasksAsync.isLoading) return const AsyncValue.loading();

  final events = <CalendarEvent>[];
  if (typeFilter.contains(CalendarEventType.task)) {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    final tasks = tasksAsync.valueOrNull ?? [];
    for (final t in tasks) {
      if (!t.showInCalendar) continue;
      if (deptFilter != null && t.departmentId != deptFilter) continue;
      if (myOnly && t.assigneeId != currentUserId) continue;
      if (t.dueDate == null) continue;
      if (t.isTemplate) continue; // 템플릿은 캘린더에 표시 안 함

      events.add(CalendarEvent(
        id: 'task_${t.id}',
        type: CalendarEventType.task,
        title: t.title,
        date: t.dueDate!,
        subtitle: '${t.status.label}'
            '${t.departmentName != null ? ' · ${t.departmentName}' : ''}',
        isAllDay: t.dueTime == null,
        isDelayed: t.isDelayed,
        routePath: '/tasks/${t.id}',
      ));
    }
  }
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
