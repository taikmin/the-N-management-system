import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../activity/providers/activity_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../calendar/providers/calendar_provider.dart';
import '../../../memos/providers/memo_provider.dart';

import '../../../tasks/providers/task_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final isMobile =
            ResponsiveLayout.isMobile(context);

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            isMobile ? AppSizes.sm : AppSizes.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(
                    isMobile
                        ? AppSizes.md
                        : AppSizes.lg,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0]
                              : '?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.greeting,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.role.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            // 부서명은 Step 4-C2에서 department_id로 조회 예정
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Quick Stats
              Text(
                '요약',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              _DashboardStats(),
              const SizedBox(height: AppSizes.lg),

              // 최근 팀 활동
              _RecentActivityPanel(),
              const SizedBox(height: AppSizes.lg),

              // 이번 주 일정
              _ThisWeekSchedule(),
              const SizedBox(height: AppSizes.lg),

              // 최근 메모
              _RecentMemosPreview(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('${AppStrings.errorGeneral}: $e'),
      ),
    );
  }

}

/// 실시간 통계 위젯 (Step 4 C-3에서 호텔 업무 기반으로 재작성 예정)
class _DashboardStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasksAsync = ref.watch(allMyTasksProvider);
    final tasks = allTasksAsync.valueOrNull ?? [];
    final myTaskCount =
        tasks.where((t) => t.status.name != 'completed').length;
    final delayedCount = tasks.where((t) => t.isDelayed).length;
    final completedCount =
        tasks.where((t) => t.status.name == 'completed').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSizes.sm,
          crossAxisSpacing: AppSizes.sm,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              title: '내 업무',
              value: '$myTaskCount',
              icon: Icons.task_alt_outlined,
              color: AppColors.info,
            ),
            _StatCard(
              title: '지연',
              value: '$delayedCount',
              icon: Icons.schedule_outlined,
              color: delayedCount > 0 ? AppColors.error : AppColors.warning,
            ),
            _StatCard(
              title: '완료',
              value: '$completedCount',
              icon: Icons.check_circle_outline,
              color: AppColors.done,
            ),
          ],
        );
      },
    );
  }
}

/// 이번 주 일정 미리보기
class _ThisWeekSchedule extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekEvents = ref.watch(thisWeekEventsProvider);
    final theme = Theme.of(context);

    if (weekEvents.isEmpty) return const SizedBox.shrink();

    final display = weekEvents.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '이번 주 일정',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => GoRouter.of(context).go('/calendar'),
              child: const Text('캘린더'),
            ),
          ],
        ),
        ...display.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: Icon(e.type.icon, color: e.color, size: 20),
                title: Text(e.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${e.date.month}/${e.date.day} · ${e.type.label}'
                  '${e.isDelayed ? ' · 지연' : ''}',
                  style: TextStyle(
                    color: e.isDelayed ? AppColors.error : null,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: e.routePath != null
                    ? () => GoRouter.of(context).push(e.routePath!)
                    : null,
              ),
            )),
        if (weekEvents.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '외 ${weekEvents.length - 5}건',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
/// 최근 메모 미리보기
class _RecentMemosPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync =
        ref.watch(recentMemosProvider);
    final theme = Theme.of(context);

    return memosAsync.when(
      data: (memos) {
        if (memos.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 메모',
                  style: theme
                      .textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      GoRouter.of(context)
                          .go('/memos'),
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            ...memos.map((m) => Card(
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      m.isPinned
                          ? Icons.push_pin
                          : Icons.note_alt_outlined,
                      size: 20,
                      color: m.isPinned
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      m.title.isNotEmpty
                          ? m.title
                          : '(제목 없음)',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (m.category != null)
                          m.category!,
                        m.createdAtDisplay,
                      ].join(' · '),
                      style: theme
                          .textTheme.bodySmall,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 16,
                    ),
                    onTap: () =>
                        GoRouter.of(context)
                            .push('/memos/${m.id}'),
                  ),
                )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// 최근 팀 활동 패널
class _RecentActivityPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync =
        ref.watch(activityStreamProvider);
    final theme = Theme.of(context);

    return activitiesAsync.when(
      data: (activities) {
        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 팀 활동',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      GoRouter.of(context)
                          .push('/activity'),
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            if (activities.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.lg,
                    horizontal: AppSizes.md,
                  ),
                  child: Center(
                    child: Text(
                      '최근 24시간 내 활동이 없습니다',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ...activities.take(5).map(
                  (log) => Card(
                    margin: const EdgeInsets.only(
                      bottom: 4,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            _activityColor(log.action)
                                .withValues(
                                    alpha: 0.15),
                        child: Icon(
                          _activityIcon(log.action),
                          size: 14,
                          color: _activityColor(
                              log.action),
                        ),
                      ),
                      title: Text(
                        log.summary,
                        style: theme
                            .textTheme.bodySmall,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${log.entityLabel} · '
                        '${log.timeAgo}',
                        style: theme
                            .textTheme.bodySmall
                            ?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      trailing: log.routePath !=
                                  null &&
                              log.action != 'delete'
                          ? const Icon(
                              Icons.chevron_right,
                              size: 16,
                            )
                          : null,
                      onTap: log.routePath != null &&
                              log.action != 'delete'
                          ? () =>
                              GoRouter.of(context)
                                  .push(
                                      log.routePath!)
                          : null,
                    ),
                  ),
                ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'complete':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _activityColor(String action) {
    switch (action) {
      case 'create':
        return AppColors.info;
      case 'update':
        return AppColors.warning;
      case 'delete':
        return AppColors.error;
      case 'complete':
        return AppColors.done;
      default:
        return AppColors.info;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
