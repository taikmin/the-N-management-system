import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/calendar_event.dart';

// ─── Filter State ───

/// 이벤트 유형별 토글 필터 (현재 task만 있음)
final calendarEventTypeFilterProvider =
    StateProvider<Set<CalendarEventType>>((ref) {
  return CalendarEventType.values.toSet();
});

/// 특정 부서만 보기 (null이면 전체)
final calendarDepartmentFilterProvider =
    StateProvider<String?>((ref) => null);

/// TODO(Step 4 C-5): 캘린더 화면 리팩터링 후 제거될 별칭
final calendarProjectFilterProvider = calendarDepartmentFilterProvider;

/// TODO(Step 4 C-5): 캘린더 화면이 아직 참조 중인 임시 stub
final projectListProvider =
    Provider<AsyncValue<List<dynamic>>>((ref) =>
        const AsyncValue.data(<dynamic>[]));

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
///
/// TODO(Step 4 C-3): Tasks 모델 재구성 후 due_date 기반 이벤트 다시 추가.
/// 현재는 Task 모델이 R&D 필드(plannedStart/End)만 있어 캘린더 소스 임시 비활성.
final calendarEventsProvider =
    Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  // 필터 상태만 유지 (UI가 참조 중)
  ref.watch(calendarEventTypeFilterProvider);
  ref.watch(calendarDepartmentFilterProvider);
  ref.watch(calendarMyOnlyProvider);

  return const AsyncValue.data(<CalendarEvent>[]);
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
