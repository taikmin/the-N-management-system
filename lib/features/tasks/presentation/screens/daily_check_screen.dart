import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/task.dart';
import '../../providers/task_provider.dart';

/// 일일 점검 대시보드
class DailyCheckScreen extends ConsumerWidget {
  const DailyCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTasksAsync = ref.watch(myTasksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('일일 점검'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(myTasksProvider.notifier).refresh(),
          ),
        ],
      ),
      body: myTasksAsync.when(
        data: (allTasks) {
          final today = DateTime.now();
          final todayStr =
              '${today.year}.${today.month.toString().padLeft(2, '0')}.${today.day.toString().padLeft(2, '0')}';

          // 분류
          final todayTasks = allTasks.where((t) =>
              t.isDueToday || t.status == TaskStatus.inProgress).toList();
          final delayedTasks = allTasks.where((t) => t.isDelayed).toList();
          final planBCTasks = allTasks
              .where((t) =>
                  t.planType != PlanType.a &&
                  t.status != TaskStatus.completed)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 헤더
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.today,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          todayStr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '전체 ${allTasks.length}건',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),

                // 지연 경고
                if (delayedTasks.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.warning_amber,
                    title: '지연 태스크',
                    count: delayedTasks.length,
                    color: theme.colorScheme.error,
                  ),
                  ...delayedTasks.map((t) => _TaskTile(
                        task: t,
                        showDelay: true,
                      )),
                  const SizedBox(height: AppSizes.lg),
                ],

                // 오늘의 태스크
                _SectionHeader(
                  icon: Icons.task_alt,
                  title: '오늘의 태스크',
                  count: todayTasks.length,
                  color: theme.colorScheme.primary,
                ),
                if (todayTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSizes.md),
                    child: Text('오늘 예정된 태스크가 없습니다'),
                  ),
                ...todayTasks.map((t) => _TaskTile(task: t)),
                const SizedBox(height: AppSizes.lg),

                // Plan B/C 상태
                if (planBCTasks.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.alt_route,
                    title: 'Plan B/C 활성',
                    count: planBCTasks.length,
                    color: Colors.orange,
                  ),
                  ...planBCTasks.map((t) => _TaskTile(
                        task: t,
                        showPlan: true,
                      )),
                  const SizedBox(height: AppSizes.lg),
                ],

                // 진행률 요약
                Text(
                  '상태별 요약',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _StatusSummary(tasks: allTasks),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    this.showDelay = false,
    this.showPlan = false,
  });
  final Task task;
  final bool showDelay;
  final bool showPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: showDelay
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: Icon(
          _statusIcon(task.status),
          color: showDelay ? Colors.red : _statusColor(task.status),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: task.isDelayed ? FontWeight.bold : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(task.status.label),
            if (task.assigneeName !=
                null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  task.assigneeName!,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ],
            if (showDelay &&
                task.isDelayed) ...[
              const SizedBox(width: 8),
              Text(
                '${task.delayDays}일 지연',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
            if (showPlan) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(4),
                ),
                child: Text(
                  'Plan ${task.planType.value}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push(
          '/projects/${task.projectId}/tasks/${task.id}',
        ),
      ),
    );
  }

  IconData _statusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.planned:
        return Icons.circle_outlined;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline;
      case TaskStatus.delayed:
        return Icons.warning_amber;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.blocked:
        return Icons.block;
    }
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.planned:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.delayed:
        return Colors.red;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return Colors.orange;
    }
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final counts = <TaskStatus, int>{};
    for (final t in tasks) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: TaskStatus.values.map((status) {
            final count = counts[status] ?? 0;
            return Column(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _color(status),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _color(status),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _color(TaskStatus s) {
    switch (s) {
      case TaskStatus.planned:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.delayed:
        return Colors.red;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.blocked:
        return Colors.orange;
    }
  }
}
