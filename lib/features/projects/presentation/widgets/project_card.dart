import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/project.dart';

/// 과제 카드 위젯
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.taskStats,
  });

  final Project project;
  final VoidCallback? onTap;
  final Map<String, int>? taskStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(project.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 바
            Container(
              height: 4,
              color: statusColor,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 과제번호 + 상태
                  Row(
                    children: [
                      if (project.projectNumber != null) ...[
                        Text(
                          project.projectNumber!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      _StatusChip(status: project.status),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),

                  // 과제명 + NEW 배지
                  Row(
                    children: [
                      if (project.isNew)
                        Container(
                          margin:
                              const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
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
                          project.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // 책임자 · 담당자 · 게시일
                  if (project.ownerName != null ||
                      project.assigneeName != null ||
                      project.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (project.ownerName != null)
                          project.ownerName!,
                        if (project.assigneeName !=
                            null)
                          '담당: ${project.assigneeName}',
                        if (project.createdAt != null)
                          '${project.createdAt!.year}.'
                              '${project.createdAt!.month.toString().padLeft(2, '0')}.'
                              '${project.createdAt!.day.toString().padLeft(2, '0')}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),

                  // 수행기간
                  if (project.startDate != null && project.endDate != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons
                              .calendar_today_outlined,
                          size: 14,
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_formatDate(project.startDate!)} ~ ${_formatDate(project.endDate!)}',
                            style: theme
                                .textTheme.bodySmall
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            overflow: TextOverflow
                                .ellipsis,
                          ),
                        ),
                        if (project.daysRemaining !=
                            null) ...[
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            project.daysRemaining! >= 0
                                ? 'D-${project.daysRemaining}'
                                : 'D+${-project.daysRemaining!}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: project.daysRemaining! <= 30
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),

                    // 진행률 바
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: project.progressByDate,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                  ],

                  // 예산
                  if (project.totalBudget > 0)
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        Text(
                          project.budgetDisplay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                  // 태스크 통계
                  if (taskStats != null && (taskStats!['total'] ?? 0) > 0) ...[
                    const SizedBox(height: AppSizes.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        _MiniStat(
                          label: '전체',
                          count: taskStats!['total'] ?? 0,
                        ),
                        _MiniStat(
                          label: '완료',
                          count: taskStats!['completed'] ?? 0,
                          color: Colors.green,
                        ),
                        _MiniStat(
                          label: '지연',
                          count: taskStats!['delayed'] ?? 0,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planning:
        return Colors.grey;
      case ProjectStatus.active:
        return Colors.blue;
      case ProjectStatus.completed:
        return Colors.green;
      case ProjectStatus.onHold:
        return Colors.orange;
      case ProjectStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProjectStatus.planning => Colors.grey,
      ProjectStatus.active => Colors.blue,
      ProjectStatus.completed => Colors.green,
      ProjectStatus.onHold => Colors.orange,
      ProjectStatus.cancelled => Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.count,
    this.color,
  });
  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
