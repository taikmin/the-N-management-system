import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../domain/models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/recording_provider.dart';

class MeetingListScreen extends ConsumerStatefulWidget {
  const MeetingListScreen({super.key});

  @override
  ConsumerState<MeetingListScreen> createState() =>
      _MeetingListScreenState();
}

class _MeetingListScreenState
    extends ConsumerState<MeetingListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(filteredMeetingListProvider);
    final statusFilter = ref.watch(meetingStatusFilterProvider);
    final theme = Theme.of(context);
    final isMobile =
        ResponsiveLayout.isMobile(context);
    final hPad =
        isMobile ? AppSizes.sm : AppSizes.md;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회의 관리'),
        actions: [
          _MeetingSortButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(meetingListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 필터 + 검색
          Padding(
            padding: EdgeInsets.fromLTRB(
                hPad, AppSizes.sm, hPad, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                ref.read(meetingSearchQueryProvider.notifier).state = v;
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: '회의 검색...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchController
                        .text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(
                                  meetingSearchQueryProvider
                                      .notifier)
                              .state = '';
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: hPad),
              children: [
                FilterChip(
                  label: const Text('전체'),
                  selected: statusFilter == null,
                  onSelected: (_) => ref
                      .read(meetingStatusFilterProvider.notifier)
                      .state = null,
                ),
                const SizedBox(width: AppSizes.xs),
                ...MeetingStatus.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: AppSizes.xs),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: statusFilter == s,
                      onSelected: (_) => ref
                          .read(meetingStatusFilterProvider.notifier)
                          .state = statusFilter == s ? null : s,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sm),

          // 회의 목록
          Expanded(
            child: meetingsAsync.when(
              data: (meetings) {
                if (meetings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          '등록된 회의가 없습니다',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          '새 회의를 생성해보세요',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(meetingListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                        horizontal: hPad, vertical: AppSizes.xs),
                    itemCount: meetings.length,
                    itemBuilder: (context, index) {
                      return _MeetingCard(meeting: meetings[index]);
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: Transform.translate(
        offset: Offset(
          0,
          ref.watch(recordingProvider).isFloatingVisible
              ? (isMobile ? -80.0 : -56.0)
              : 0,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/meetings/create'),
          icon: const Icon(Icons.add),
          label: const Text('새 회의'),
        ),
      ),
    );
  }
}

class _MeetingSortButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(meetingSortProvider);
    return PopupMenuButton<MeetingSort>(
      icon: const Icon(Icons.sort),
      tooltip: '정렬',
      onSelected: (sort) => ref
          .read(meetingSortProvider.notifier)
          .state = sort,
      itemBuilder: (context) => MeetingSort.values
          .map(
            (s) => PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  if (s == current)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(s.label),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusColor = switch (meeting.status) {
      MeetingStatus.preparing => AppColors.warning,
      MeetingStatus.notified => AppColors.info,
      MeetingStatus.inProgress => AppColors.inProgress,
      MeetingStatus.completed => AppColors.done,
    };

    final dDayText = meeting.isToday
        ? 'D-Day'
        : meeting.isPast
            ? '종료'
            : 'D-${meeting.daysUntil}';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: InkWell(
        onTap: () => context.push('/meetings/${meeting.id}'),
        child: Column(
          children: [
            // 상단 색상 바
            Container(height: 4, color: statusColor),
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 유형 배지 + D-Day
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          meeting.meetingType.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          meeting.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dDayText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: meeting.isToday
                              ? AppColors.error
                              : meeting.isPast
                                  ? theme.colorScheme.onSurfaceVariant
                                  : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),

                  // 제목 + NEW 배지
                  Row(
                    children: [
                      if (meeting.isNew)
                        Container(
                          margin:
                              const EdgeInsets.only(right: 4),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius:
                                BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          meeting.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),

                  // 과제명 + 게시자
                  Text(
                    [
                      if (meeting.projectTitle != null)
                        meeting.projectTitle!,
                      if (meeting.creatorName != null)
                        meeting.creatorName!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: AppSizes.sm),

                  // 하단 정보
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(meeting.meetingDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (meeting.location != null) ...[
                        const SizedBox(width: AppSizes.md),
                        Icon(Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            meeting.location!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (meeting.mealReservation) ...[
                        const SizedBox(width: AppSizes.sm),
                        Icon(Icons.restaurant,
                            size: 14, color: AppColors.tertiary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
