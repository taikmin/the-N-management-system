import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/activity_log.dart';
import '../../providers/activity_provider.dart';

/// 전체 활동 로그 화면
class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync =
        ref.watch(activityListProvider);
    final filter = ref.watch(activityFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('팀 활동 내역'),
      ),
      body: Column(
        children: [
          // 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: ActivityFilter.values.map((f) {
                final selected = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(
                    right: AppSizes.xs,
                  ),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) {
                      ref
                          .read(activityFilterProvider
                              .notifier)
                          .state = f;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // 활동 목록
          Expanded(
            child: activitiesAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: theme
                              .colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(
                          height: AppSizes.md,
                        ),
                        Text(
                          '활동 내역이 없습니다',
                          style: theme
                              .textTheme.bodyLarge
                              ?.copyWith(
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 날짜별 그룹핑
                final grouped =
                    <String, List<ActivityLog>>{};
                for (final log in activities) {
                  grouped
                      .putIfAbsent(
                        log.dateKey,
                        () => [],
                      )
                      .add(log);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                  ),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateKey =
                        grouped.keys.elementAt(index);
                    final logs = grouped[dateKey]!;

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: AppSizes.sm,
                          ),
                          child: Text(
                            dateKey,
                            style: theme
                                .textTheme.titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...logs.map(
                          (log) =>
                              _ActivityTile(log: log),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text('오류: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.log});
  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor:
              _actionColor(log.action)
                  .withValues(alpha: 0.15),
          child: Icon(
            _actionIcon(log.action),
            size: 16,
            color: _actionColor(log.action),
          ),
        ),
        title: Text(
          log.summary,
          style: theme.textTheme.bodyMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${log.entityLabel} · ${log.timeDisplay}',
          style: theme.textTheme.bodySmall?.copyWith(
            color:
                theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: log.routePath != null &&
                log.action != 'delete'
            ? const Icon(
                Icons.chevron_right,
                size: 16,
              )
            : null,
        onTap: log.routePath != null &&
                log.action != 'delete'
            ? () => GoRouter.of(context)
                .push(log.routePath!)
            : null,
      ),
    );
  }

  IconData _actionIcon(String action) {
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

  Color _actionColor(String action) {
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
