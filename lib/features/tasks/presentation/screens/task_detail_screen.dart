import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/supabase_config.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/file_attachment_section.dart';
import '../../domain/models/task.dart';
import '../../domain/models/task_update.dart';
import '../../providers/task_provider.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, this.projectId, required this.taskId});

  final String? projectId;
  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _updateController = TextEditingController();

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final subTasksAsync = ref.watch(subTasksProvider(widget.taskId));
    final updatesAsync = ref.watch(taskUpdatesProvider(widget.taskId));

    return taskAsync.when(
      data: (task) => Scaffold(
        appBar: AppBar(
          title: Text(task.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '업무 수정',
              onPressed: () {
                if (widget.projectId != null) {
                  context.push(
                    '/projects/${widget.projectId}'
                    '/tasks/${widget.taskId}/edit',
                  );
                } else {
                  context.push('/tasks/${widget.taskId}/edit');
                }
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusSection(
                task: task,
                onStatusChanged: (status) async {
                  if (widget.projectId != null) {
                    await ref
                        .read(projectTasksProvider(widget.projectId!).notifier)
                        .updateStatus(widget.taskId, status);
                  } else {
                    await ref
                        .read(taskRepositoryProvider)
                        .updateTaskStatus(widget.taskId, status);
                  }
                  ref.invalidate(taskDetailProvider(widget.taskId));
                },
              ),
              const SizedBox(height: AppSizes.md),
              _InfoCard(task: task),
              if (task.description != null) ...[
                const SizedBox(height: AppSizes.md),
                _DescriptionCard(description: task.description!),
              ],

              // 하위 태스크 (연계 업무 통합)
              const SizedBox(height: AppSizes.lg),
              _SubTasksSection(
                task: task,
                projectId: widget.projectId,
                subTasksAsync: subTasksAsync,
                quickAddController: _updateController,
              ),

              // 첨부 파일
              const SizedBox(height: AppSizes.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: FileAttachmentSection(
                    entityType: 'task',
                    entityId: task.id,
                  ),
                ),
              ),

              // 코멘트
              const SizedBox(height: AppSizes.lg),
              _TaskUpdatesSection(
                taskId: widget.taskId,
                updatesAsync: updatesAsync,
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

// ─── Status Section ───

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.task, required this.onStatusChanged});

  final Task task;
  final ValueChanged<TaskStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('상태 변경', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              children: TaskStatus.values.map((status) {
                final isActive = task.status == status;
                return ChoiceChip(
                  label: Text(status.label),
                  selected: isActive,
                  onSelected: isActive ? null : (_) => onStatusChanged(status),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Card ───

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              'Plan',
              'Plan ${task.planType.value}',
              color: task.planType == PlanType.a ? null : Colors.orange,
            ),
            _InfoRow('우선순위', task.priority.label),
            if (task.assigneeName != null) _InfoRow('담당자', task.assigneeName!),
            if (task.colorTag != ColorTag.none)
              _InfoRow('색상 태그', task.colorTag.label),
            if (task.plannedStart != null)
              _InfoRow('계획 시작', _fmt(task.plannedStart!)),
            if (task.plannedEnd != null)
              _InfoRow(
                '계획 종료',
                _fmt(task.plannedEnd!),
                color: task.isDelayed ? Colors.red : null,
                suffix: task.isDelayed ? ' (${task.delayDays}일 지연)' : null,
              ),
            if (task.actualStart != null)
              _InfoRow('실제 시작', _fmt(task.actualStart!)),
            if (task.actualEnd != null)
              _InfoRow('실제 종료', _fmt(task.actualEnd!)),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.day.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.color, this.suffix});
  final String label;
  final String value;
  final Color? color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$value${suffix ?? ''}',
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Description ───

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설명', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.sm),
            Text(description),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-Tasks (연계 업무 통합) ───

class _SubTasksSection extends ConsumerWidget {
  const _SubTasksSection({
    required this.task,
    this.projectId,
    required this.subTasksAsync,
    required this.quickAddController,
  });

  final Task task;
  final String? projectId;
  final AsyncValue<List<Task>> subTasksAsync;
  final TextEditingController quickAddController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '하위 태스크',
              style: theme.textTheme.titleSmall,
            ),
            TextButton.icon(
              onPressed: () {
                if (projectId != null) {
                  context.push(
                    '/projects/$projectId'
                    '/tasks/create'
                    '?parent=${task.id}',
                  );
                } else {
                  context.push(
                    '/tasks/create'
                    '?parent=${task.id}',
                  );
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('상세 추가'),
            ),
          ],
        ),

        // 빠른 추가 입력란
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppSizes.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quickAddController,
                  decoration: const InputDecoration(
                    hintText: '하위 업무 제목 입력...',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 18,
                    ),
                  ),
                  onSubmitted: (_) =>
                      _quickAdd(ref, context),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              IconButton.filled(
                onPressed: () =>
                    _quickAdd(ref, context),
                icon: const Icon(
                  Icons.add,
                  size: 20,
                ),
                tooltip: '하위 태스크 빠른 추가',
              ),
            ],
          ),
        ),

        // 하위 태스크 목록
        subTasksAsync.when(
          data: (subTasks) {
            if (subTasks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(
                  AppSizes.md,
                ),
                child: Text(
                  '하위 태스크 없음',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: subTasks
                  .map(
                    (st) => Card(
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          st.status ==
                                  TaskStatus
                                      .completed
                              ? Icons.check_circle
                              : Icons
                                  .circle_outlined,
                          color: st.isDelayed
                              ? Colors.red
                              : null,
                          size: 20,
                        ),
                        title: Text(st.title),
                        subtitle: Text(
                          '${st.status.label}'
                          ' · Plan '
                          '${st.planType.value}',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          if (projectId != null) {
                            context.push(
                              '/projects/$projectId'
                              '/tasks/${st.id}',
                            );
                          } else {
                            context.push(
                              '/tasks/${st.id}',
                            );
                          }
                        },
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Text('오류: $e'),
        ),
      ],
    );
  }

  Future<void> _quickAdd(
    WidgetRef ref,
    BuildContext context,
  ) async {
    final title = quickAddController.text.trim();
    if (title.isEmpty) return;

    final userId =
        SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;

    final newTask = Task(
      id: '',
      title: title,
      status: TaskStatus.planned,
      priority: TaskPriority.medium,
      planType: task.planType,
      projectId: task.projectId,
      parentTaskId: task.id,
      createdBy: userId,
    );

    try {
      await ref
          .read(taskRepositoryProvider)
          .createTask(newTask);
      quickAddController.clear();
      ref.invalidate(subTasksProvider(task.id));
      ref.invalidate(allMyTasksProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추가 실패: $e'),
          ),
        );
      }
    }
  }
}

// ─── Task Comments (코멘트) ───

class _TaskUpdatesSection extends ConsumerStatefulWidget {
  const _TaskUpdatesSection({
    required this.taskId,
    required this.updatesAsync,
  });

  final String taskId;
  final AsyncValue<List<TaskUpdate>> updatesAsync;

  @override
  ConsumerState<_TaskUpdatesSection> createState() =>
      _TaskUpdatesSectionState();
}

class _TaskUpdatesSectionState
    extends ConsumerState<_TaskUpdatesSection> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              '코멘트',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSizes.sm),

            // 입력 필드
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration:
                        const InputDecoration(
                      hintText: '코멘트 입력...',
                      isDense: true,
                      border:
                          OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    minLines: 1,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                IconButton.filled(
                  onPressed: _submit,
                  icon: const Icon(
                    Icons.send,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            // 코멘트 목록
            widget.updatesAsync.when(
              data: (updates) {
                if (updates.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(
                      AppSizes.sm,
                    ),
                    child: Text(
                      '코멘트가 없습니다',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: updates.map((u) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: AppSizes.sm,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            child: Text(
                              u.authorName
                                          ?.isNotEmpty ==
                                      true
                                  ? u.authorName![
                                      0]
                                  : '?',
                              style:
                                  const TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: AppSizes.sm,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      u.authorName ??
                                          '익명',
                                      style: theme
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                    if (u.createdAt !=
                                        null) ...[
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Text(
                                        _fmtTime(
                                          u.createdAt!,
                                        ),
                                        style: theme
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                    const Spacer(),
                                    InkWell(
                                      onTap: () =>
                                          _delete(
                                        u.id,
                                      ),
                                      child: Icon(
                                        Icons
                                            .close,
                                        size: 16,
                                        color: theme
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 2,
                                ),
                                Text(u.content),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child:
                    CircularProgressIndicator(),
              ),
              error: (e, _) => Text('오류: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final content =
        _commentController.text.trim();
    if (content.isEmpty) return;

    final userId =
        SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;

    final update = TaskUpdate(
      id: '',
      taskId: widget.taskId,
      authorId: userId,
      content: content,
    );

    await ref
        .read(taskRepositoryProvider)
        .createTaskUpdate(update);
    _commentController.clear();
    ref.invalidate(
      taskUpdatesProvider(widget.taskId),
    );
  }

  Future<void> _delete(String id) async {
    await ref
        .read(taskRepositoryProvider)
        .deleteTaskUpdate(id);
    ref.invalidate(
      taskUpdatesProvider(widget.taskId),
    );
  }

  String _fmtTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
