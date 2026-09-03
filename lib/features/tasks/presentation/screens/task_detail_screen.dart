import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/models/task.dart';
import '../../providers/task_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('업무 삭제'),
        content: const Text('이 업무를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(allMyTasksProvider.notifier).deleteTask(taskId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canManage = ref.watch(isManagementProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('업무 상세'),
        actions: [
          if (canManage)
            taskAsync.when(
              data: (t) => Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.push(
                      '/tasks/${t.id}/edit',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
        ],
      ),
      body: taskAsync.when(
        data: (task) {
          final isMyTask = user?.id == task.assigneeId;
          return ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              _TaskHeaderCard(task: task),
              const SizedBox(height: AppSizes.md),
              _TaskInfoCard(task: task),
              if (task.completionNote != null ||
                  task.delayReason != null) ...[
                const SizedBox(height: AppSizes.md),
                _TaskReportCard(task: task),
              ],
              const SizedBox(height: AppSizes.xl),

              // 직원(담당자) 보고 버튼 or 관리자 편집 안내
              if (isMyTask && task.status != TaskStatus.completed) ...[
                FilledButton.icon(
                  onPressed: () =>
                      _showReportSheet(context, ref, task),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('보고하기'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
              if (!isMyTask && !canManage)
                Text(
                  '이 업무는 다른 직원에게 할당되어 있습니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  void _showReportSheet(BuildContext context, WidgetRef ref, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskReportSheet(task: task),
    );
  }
}

class _TaskHeaderCard extends StatelessWidget {
  const _TaskHeaderCard({required this.task});
  final Task task;

  Color _statusColor() {
    if (task.isDelayed && task.status != TaskStatus.completed) {
      return AppColors.error;
    }
    switch (task.status) {
      case TaskStatus.assigned:
        return AppColors.todo;
      case TaskStatus.inProgress:
        return AppColors.inProgress;
      case TaskStatus.completed:
        return AppColors.done;
      case TaskStatus.incomplete:
        return AppColors.warning;
      case TaskStatus.delayed:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.status.label,
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priority.label,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (task.recurrencePattern != null) ...[
                  const SizedBox(width: 6),
                  Row(
                    children: [
                      Icon(Icons.repeat,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 2),
                      Text(
                        RecurrencePattern.tryParse(task.recurrencePattern)
                                ?.displayLabel ??
                            '반복',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              task.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (task.description != null &&
                task.description!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Text(task.description!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            _row(theme, Icons.business_outlined, '부서',
                task.departmentName ?? '(부서 없음)'),
            _row(theme, Icons.person_outline, '담당자',
                task.assigneeName ?? '(미지정)'),
            _row(theme, Icons.person_pin_outlined, '지시자',
                task.assignerName ?? '(정보 없음)'),
            _row(
              theme,
              Icons.event_outlined,
              '마감',
              task.dueDate == null
                  ? '(설정 없음)'
                  : '${task.dueDate!.year}.${task.dueDate!.month}.${task.dueDate!.day}'
                      '${task.dueTime != null ? ' ${task.dueTime}' : ''}',
            ),
            if (task.category != null)
              _row(theme, Icons.label_outline, '카테고리', task.category!),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _TaskReportCard extends StatelessWidget {
  const _TaskReportCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('보고 내용',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            if (task.completedAt != null)
              Text(
                '완료: ${task.completedAt!.year}.${task.completedAt!.month}.${task.completedAt!.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            if (task.completionNote != null &&
                task.completionNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task.completionNote!),
            ],
            if (task.delayReason != null && task.delayReason!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '사유: ${task.delayReason}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 직원용 보고 하단 시트
class TaskReportSheet extends ConsumerStatefulWidget {
  const TaskReportSheet({super.key, required this.task});
  final Task task;

  @override
  ConsumerState<TaskReportSheet> createState() => _TaskReportSheetState();
}

class _TaskReportSheetState extends ConsumerState<TaskReportSheet> {
  TaskStatus _status = TaskStatus.completed;
  final _noteController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 미완료/지연 사유 필수
    if ((_status == TaskStatus.incomplete || _status == TaskStatus.delayed) &&
        _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사유를 입력해주세요')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(allMyTasksProvider.notifier).updateStatus(
            widget.task.id,
            status: _status,
            completionNote: _status == TaskStatus.completed
                ? (_noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim())
                : null,
            delayReason: (_status == TaskStatus.incomplete ||
                    _status == TaskStatus.delayed)
                ? _reasonController.text.trim()
                : null,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('보고되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('보고 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsReason =
        _status == TaskStatus.incomplete || _status == TaskStatus.delayed;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.lg,
        right: AppSizes.lg,
        top: AppSizes.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text('업무 보고',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(widget.task.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              _statusOption(TaskStatus.completed, '완료', Icons.check_circle),
              _statusOption(TaskStatus.inProgress, '진행중', Icons.play_circle),
              _statusOption(
                  TaskStatus.incomplete, '미완료', Icons.cancel_outlined),
              _statusOption(TaskStatus.delayed, '지연', Icons.schedule),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (_status == TaskStatus.completed)
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '완료 메모 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          if (needsReason)
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '사유 (필수)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('보고'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusOption(TaskStatus s, String label, IconData icon) {
    final selected = _status == s;
    final color =
        s == TaskStatus.completed ? AppColors.done : AppColors.warning;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _status = s),
      avatar: Icon(icon, size: 16, color: selected ? color : null),
      label: Text(label),
    );
  }
}
