import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/file_attachment_section.dart';
import '../../../tasks/domain/models/task.dart';
import '../../../tasks/providers/task_provider.dart';
import '../../domain/models/project.dart';
import '../../providers/project_provider.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final tasksAsync = ref.watch(projectTasksProvider(projectId));
    final theme = Theme.of(context);

    return projectAsync.when(
      data: (project) => Scaffold(
        appBar: AppBar(
          title: Text(project.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/projects/$projectId/edit'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('과제 삭제'),
                      content: const Text('이 과제와 모든 하위 태스크가 삭제됩니다. 계속하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await ref
                        .read(projectListProvider.notifier)
                        .deleteProject(projectId);
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 과제 정보 카드
              _ProjectInfoCard(project: project),
              const SizedBox(height: AppSizes.lg),

              // 진행률 섹션
              _ProgressSection(
                project: project,
                tasksAsync: tasksAsync,
              ),
              const SizedBox(height: AppSizes.lg),

              // 첨부 파일 섹션
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(
                      AppSizes.md),
                  child: FileAttachmentSection(
                    entityType: 'project',
                    entityId: projectId,
                    title: '과제 첨부 파일',
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // 태스크 목록
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '태스크',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push('/projects/$projectId/tasks/create'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('태스크 추가'),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),

              tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.task_alt_outlined,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: AppSizes.sm),
                              const Text('아직 태스크가 없습니다'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // 상태별 그룹핑
                  final grouped = <TaskStatus, List<Task>>{};
                  for (final task in tasks) {
                    grouped.putIfAbsent(task.status, () => []).add(task);
                  }

                  return Column(
                    children: TaskStatus.values
                        .where((s) => grouped.containsKey(s))
                        .map((status) => _TaskStatusGroup(
                              status: status,
                              tasks: grouped[status]!,
                              projectId: projectId,
                            ))
                        .toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('오류: $e'),
              ),
            ],
          ),
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _ProjectInfoCard extends ConsumerWidget {
  const _ProjectInfoCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membersAsync = ref.watch(
        projectMembersProvider(project.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.projectNumber != null)
              Text(
                project.projectNumber!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            if (project.description != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(project.description!),
            ],
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.md,
              runSpacing: AppSizes.sm,
              children: [
                _InfoItem(
                  icon: Icons.business,
                  label: '주관',
                  value: project.leadInstitution,
                ),
                if (project.coInstitutions.isNotEmpty)
                  _InfoItem(
                    icon: Icons.groups,
                    label: '공동',
                    value: project.coInstitutions.join(', '),
                  ),
                if (project.totalBudget > 0)
                  _InfoItem(
                    icon: Icons.attach_money,
                    label: '연구비',
                    value: project.budgetDisplay,
                  ),
                if (project.ownerName != null)
                  _InfoItem(
                    icon: Icons.person,
                    label: '책임자',
                    value: project.ownerName!,
                  ),
                if (project.assigneeName != null)
                  _InfoItem(
                    icon: Icons.person_pin,
                    label: '담당자',
                    value:
                        project.assigneeName!,
                  ),
              ],
            ),
            // 팀원 목록
            membersAsync.when(
              data: (members) {
                final nonOwner = members.where(
                  (m) => m['role'] != 'owner',
                ).toList();
                if (nonOwner.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(
                    top: AppSizes.sm,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '팀원: ',
                        style: theme
                            .textTheme.bodySmall
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          children: nonOwner
                              .map((m) {
                            final profile =
                                m['profiles']
                                    as Map<String,
                                        dynamic>?;
                            final name = profile
                                    ?['full_name']
                                as String? ??
                                '이름 없음';
                            return Text(
                              name,
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () =>
                  const SizedBox.shrink(),
              error: (_, _) =>
                  const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.project,
    required this.tasksAsync,
  });
  final Project project;
  final AsyncValue<List<Task>> tasksAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return tasksAsync.when(
      data: (tasks) {
        final total = tasks.length;
        final completed =
            tasks.where((t) => t.status == TaskStatus.completed).length;
        final delayed =
            tasks.where((t) => t.isDelayed).length;
        final progress = total > 0 ? completed / total : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('진행률',
                        style: theme.textTheme.titleSmall),
                    Text(
                      '${(progress * 100).toInt()}% ($completed/$total)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (delayed > 0) ...[
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Icon(Icons.warning_amber,
                          size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 4),
                      Text(
                        '지연 태스크 $delayed건',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _TaskStatusGroup extends StatelessWidget {
  const _TaskStatusGroup({
    required this.status,
    required this.tasks,
    required this.projectId,
  });
  final TaskStatus status;
  final List<Task> tasks;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${status.label} (${tasks.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...tasks.map(
          (task) => Card(
            child: ListTile(
              leading: Icon(
                task.isDelayed ? Icons.warning_amber : Icons.task_alt,
                color: task.isDelayed ? Colors.red : color,
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  decoration: task.status == TaskStatus.completed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: Row(
                children: [
                  if (task.assigneeName != null)
                    Flexible(
                      child: Text(
                        task.assigneeName!,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  if (task.planType !=
                      PlanType.a) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: task.planType ==
                                PlanType.b
                            ? Colors.orange
                                .withValues(
                                    alpha: 0.1)
                            : Colors.red
                                .withValues(
                                    alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(
                                4),
                      ),
                      child: Text(
                        'Plan ${task.planType.value}',
                        style: TextStyle(
                          fontSize: 11,
                          color: task.planType ==
                                  PlanType.b
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                  if (task.isDelayed) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${task.delayDays}일 지연',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/projects/$projectId/tasks/${task.id}',
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
      ],
    );
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
