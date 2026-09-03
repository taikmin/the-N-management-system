import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../departments/providers/department_provider.dart';
import '../../domain/models/calendar_event.dart';
import '../../providers/calendar_provider.dart';

/// 캘린더 뷰 모드
enum CalendarViewMode { month, week, day }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusedDay = ref.watch(calendarFocusedDayProvider);
    final selectedDay = ref.watch(calendarSelectedDayProvider);
    final eventsAsync = ref.watch(calendarEventsProvider);
    final selectedEvents = ref.watch(eventsForDayProvider(selectedDay));

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          // 뷰 모드 전환
          SegmentedButton<CalendarViewMode>(
            segments: const [
              ButtonSegment(value: CalendarViewMode.month, label: Text('월')),
              ButtonSegment(value: CalendarViewMode.week, label: Text('주')),
              ButtonSegment(value: CalendarViewMode.day, label: Text('일')),
            ],
            selected: {_viewMode},
            onSelectionChanged: (s) =>
                setState(() => _viewMode = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '오늘',
            onPressed: () {
              final now = DateTime.now();
              ref.read(calendarFocusedDayProvider.notifier).state = now;
              ref.read(calendarSelectedDayProvider.notifier).state = now;
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '필터',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 칩 표시
          _ActiveFilters(),
          // 캘린더
          eventsAsync.when(
            data: (allEvents) => _buildCalendar(
              allEvents,
              focusedDay,
              selectedDay,
              theme,
            ),
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(
              child: Center(child: Text('오류: $e')),
            ),
          ),
          const Divider(height: 1),
          // 선택된 날짜의 이벤트 목록
          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Text(
                      '이 날짜에 일정이 없습니다',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm, vertical: AppSizes.xs),
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      return _EventTile(event: selectedEvents[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    List<CalendarEvent> allEvents,
    DateTime focusedDay,
    DateTime selectedDay,
    ThemeData theme,
  ) {
    final calendarFormat = switch (_viewMode) {
      CalendarViewMode.month => CalendarFormat.month,
      CalendarViewMode.week => CalendarFormat.twoWeeks,
      CalendarViewMode.day => CalendarFormat.week,
    };

    return TableCalendar<CalendarEvent>(
      locale: 'ko_KR',
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2040, 12, 31),
      focusedDay: focusedDay,
      calendarFormat: calendarFormat,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      eventLoader: (day) {
        return allEvents.where((e) => e.occursOn(day)).toList();
      },
      onDaySelected: (selected, focused) {
        ref.read(calendarSelectedDayProvider.notifier).state = selected;
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
      },
      onPageChanged: (focused) {
        ref.read(calendarFocusedDayProvider.notifier).state = focused;
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        outsideDaysVisible: false,
        markersMaxCount: 4,
        markerDecoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;

          // 이벤트 유형별 도트 표시
          final uniqueTypes = events.map((e) => e.type).toSet();
          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: uniqueTypes.take(4).map((type) {
                final hasDelayed =
                    events.any((e) => e.type == type && e.isDelayed);
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasDelayed ? AppColors.error : type.color,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      onHeaderTapped: (_) =>
          _showYearMonthPicker(context),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        ),
      ),
    );
  }

  void _showYearMonthPicker(
      BuildContext context) {
    final focused =
        ref.read(calendarFocusedDayProvider);
    int selectedYear = focused.year;
    int selectedMonth = focused.month;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('연도/월 선택'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 연도 선택
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        IconButton(
                          icon: const Icon(
                              Icons.chevron_left),
                          onPressed: () {
                            if (selectedYear >
                                2020) {
                              setDialogState(() =>
                                  selectedYear--);
                            }
                          },
                        ),
                        Text(
                          '$selectedYear년',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons
                                  .chevron_right),
                          onPressed: () {
                            if (selectedYear <
                                2040) {
                              setDialogState(() =>
                                  selectedYear++);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 월 그리드
                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: 12,
                      itemBuilder: (ctx, i) {
                        final month = i + 1;
                        final isSelected =
                            month ==
                                selectedMonth;
                        final isNow =
                            selectedYear ==
                                    DateTime.now()
                                        .year &&
                                month ==
                                    DateTime.now()
                                        .month;
                        return InkWell(
                          onTap: () {
                            setDialogState(() =>
                                selectedMonth =
                                    month);
                          },
                          borderRadius:
                              BorderRadius
                                  .circular(8),
                          child: Container(
                            alignment:
                                Alignment.center,
                            decoration:
                                BoxDecoration(
                              color: isSelected
                                  ? Theme.of(ctx)
                                      .colorScheme
                                      .primary
                                  : null,
                              border: isNow &&
                                      !isSelected
                                  ? Border.all(
                                      color: Theme
                                              .of(ctx)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                          8),
                            ),
                            child: Text(
                              '$month월',
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(
                                            ctx)
                                        .colorScheme
                                        .onPrimary
                                    : null,
                                fontWeight:
                                    isSelected ||
                                            isNow
                                        ? FontWeight
                                            .bold
                                        : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final newDate = DateTime(
                      selectedYear,
                      selectedMonth,
                    );
                    ref
                        .read(
                            calendarFocusedDayProvider
                                .notifier)
                        .state = newDate;
                    ref
                        .read(
                            calendarSelectedDayProvider
                                .notifier)
                        .state = newDate;
                  },
                  child: const Text('이동'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _FilterSheet(),
    );
  }
}

// ─── Active Filters Display ───

class _ActiveFilters extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(calendarEventTypeFilterProvider);
    final deptFilter = ref.watch(calendarDepartmentFilterProvider);
    final myOnly = ref.watch(calendarMyOnlyProvider);
    final theme = Theme.of(context);

    final isFiltered = typeFilter.length < CalendarEventType.values.length ||
        deptFilter != null ||
        myOnly;

    if (!isFiltered) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: AppSizes.xs),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 16,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (myOnly)
                    _FilterTag(label: '내 담당', onRemove: () {
                      ref.read(calendarMyOnlyProvider.notifier).state = false;
                    }),
                  if (deptFilter != null)
                    _FilterTag(label: '부서 필터', onRemove: () {
                      ref.read(calendarDepartmentFilterProvider.notifier).state =
                          null;
                    }),
                  ...CalendarEventType.values
                      .where((t) => !typeFilter.contains(t))
                      .map((t) => _FilterTag(
                            label: '${t.label} 숨김',
                            onRemove: () {
                              ref
                                  .read(calendarEventTypeFilterProvider.notifier)
                                  .state = {...typeFilter, t};
                            },
                          )),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(calendarEventTypeFilterProvider.notifier).state =
                  CalendarEventType.values.toSet();
              ref.read(calendarDepartmentFilterProvider.notifier).state = null;
              ref.read(calendarMyOnlyProvider.notifier).state = false;
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

class _FilterTag extends StatelessWidget {
  const _FilterTag({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─── Filter Bottom Sheet ───

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(calendarEventTypeFilterProvider);
    final deptFilter = ref.watch(calendarDepartmentFilterProvider);
    final myOnly = ref.watch(calendarMyOnlyProvider);
    final departmentsAsync = ref.watch(departmentListProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text('필터',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSizes.md),

              // 이벤트 유형 토글
              Text('이벤트 유형',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.xs),
              Wrap(
                spacing: AppSizes.xs,
                children: CalendarEventType.values.map((type) {
                  final active = typeFilter.contains(type);
                  return FilterChip(
                    label: Text(type.label),
                    selected: active,
                    selectedColor: type.color.withValues(alpha: 0.2),
                    avatar: Icon(type.icon, size: 16, color: type.color),
                    onSelected: (v) {
                      final updated = Set<CalendarEventType>.from(typeFilter);
                      if (v) {
                        updated.add(type);
                      } else {
                        updated.remove(type);
                      }
                      ref
                          .read(calendarEventTypeFilterProvider.notifier)
                          .state = updated;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSizes.md),

              // 내 담당만 보기
              SwitchListTile(
                title: const Text('내 담당만 보기'),
                value: myOnly,
                onChanged: (v) =>
                    ref.read(calendarMyOnlyProvider.notifier).state = v,
              ),
              const Divider(),

              // 부서별 필터
              Text('부서 필터', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.xs),
              ListTile(
                dense: true,
                title: const Text('전체 부서'),
                leading: Icon(
                  deptFilter == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: deptFilter == null
                      ? theme.colorScheme.primary
                      : null,
                ),
                onTap: () => ref
                    .read(calendarDepartmentFilterProvider.notifier)
                    .state = null,
              ),
              ...departmentsAsync.whenOrNull(
                    data: (departments) => departments.map((d) => ListTile(
                          dense: true,
                          title: Text(d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          leading: Icon(
                            deptFilter == d.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: deptFilter == d.id
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          onTap: () => ref
                              .read(calendarDepartmentFilterProvider.notifier)
                              .state = d.id,
                        )),
                  ) ??
                  [],
            ],
          ),
        );
      },
    );
  }
}

// ─── Event Tile ───

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.xs),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: event.routePath != null
            ? () => context.push(event.routePath!)
            : null,
        child: Row(
          children: [
            // 색상 바
            Container(width: 4, height: 56, color: event.color),
            const SizedBox(width: AppSizes.sm),
            // 아이콘
            Icon(event.type.icon, color: event.color, size: 20),
            const SizedBox(width: AppSizes.sm),
            // 내용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: event.isDelayed
                            ? TextDecoration.none
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event.subtitle != null)
                      Text(
                        event.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            // 시간 또는 배지
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!event.isAllDay)
                    Text(
                      '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.labelSmall,
                    ),
                  if (event.isDelayed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '지연',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
