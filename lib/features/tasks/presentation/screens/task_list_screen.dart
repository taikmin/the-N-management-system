import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../departments/providers/department_provider.dart';
import '../../domain/models/task.dart';
import '../../providers/task_provider.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(filteredTasksProvider);
    final filter = ref.watch(taskFilterProvider);
    final sort = ref.watch(taskSortProvider);
    final canManage = ref.watch(isManagementProvider);
    final departmentsAsync = ref.watch(departmentListProvider);
    final deptFilter = ref.watch(taskDepartmentFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '업무 검색...',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(taskSearchQueryProvider.notifier).state = v,
              )
            : const Text(AppStrings.tasks),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
                ref.read(taskSearchQueryProvider.notifier).state = '';
              }
            },
          ),
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort),
            tooltip: '정렬',
            onSelected: (s) =>
                ref.read(taskSortProvider.notifier).state = s,
            itemBuilder: (_) => TaskSort.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s == sort
                                ? Icons.check
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(allMyTasksProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 필터 chip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
            child: Row(
              children: TaskFilter.values.map((f) {
                final selected = f == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSizes.xs),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(taskFilterProvider.notifier).state = f,
                  ),
                );
              }).toList(),
            ),
          ),
          // 부서 필터 dropdown
          departmentsAsync.when(
            data: (departments) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: DropdownButtonFormField<String?>(
                initialValue: deptFilter,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: '부서 필터',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('전체 부서')),
                  ...departments.map((d) => DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(d.name),
                      )),
                ],
                onChanged: (v) =>
                    ref.read(taskDepartmentFilterProvider.notifier).state = v,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSizes.sm),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Center(child: Text('업무가 없습니다'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.xs),
                  itemBuilder: (context, index) {
                    final t = tasks[index];
                    return _TaskTile(task: t);
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/tasks/create'),
              icon: const Icon(Icons.add),
              label: const Text('업무 지시'),
            )
          : null,
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(task.status, task.isDelayed);

    return Card(
      child: InkWell(
        onTap: () => context.push('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.priority == TaskPriority.urgent ||
                      task.priority == TaskPriority.high)
                    _PriorityBadge(priority: task.priority),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (task.departmentName != null) ...[
                    _MetaChip(
                      icon: Icons.business_outlined,
                      label: task.departmentName!,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (task.assigneeName != null) ...[
                    _MetaChip(
                      icon: Icons.person_outline,
                      label: task.assigneeName!,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (task.dueDate != null)
                    _MetaChip(
                      icon: Icons.event_outlined,
                      label:
                          '${task.dueDate!.month}/${task.dueDate!.day}${task.dueTime != null ? ' ${task.dueTime}' : ''}',
                      color: task.isDelayed ? AppColors.error : null,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    task.status.label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                  if (task.isDelayed && task.delayDays != null) ...[
                    const SizedBox(width: 4),
                    Text('· ${task.delayDays}일 지연',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.error)),
                  ],
                  if (task.recurrencePattern != null) ...[
                    const Spacer(),
                    Icon(Icons.repeat, size: 14, color: theme.colorScheme.primary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus status, bool isDelayed) {
    if (isDelayed && status != TaskStatus.completed) return AppColors.error;
    switch (status) {
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 2),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: c)),
      ],
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priority == TaskPriority.urgent
        ? AppColors.error
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
