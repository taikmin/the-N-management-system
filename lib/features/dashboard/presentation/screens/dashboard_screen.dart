import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../activity/providers/activity_provider.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../calendar/providers/calendar_provider.dart';
import '../../../departments/providers/department_provider.dart';
import '../../../memos/providers/memo_provider.dart';
import '../../../tasks/domain/models/task.dart';
import '../../../tasks/providers/task_provider.dart';

/// 대시보드 — 역할별 뷰 분기
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final isMobile = ResponsiveLayout.isMobile(context);
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSizes.sm : AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(user: user),
              const SizedBox(height: AppSizes.lg),
              // 역할별 뷰 분기
              if (user.isCeoOrAbove)
                _CeoDashboard(user: user)
              else if (user.role == UserRole.manager)
                _ManagerDashboard(user: user)
              else
                _StaffDashboard(user: user),
              const SizedBox(height: AppSizes.lg),
              // 공용 하단 위젯
              _ThisWeekSchedule(),
              const SizedBox(height: AppSizes.lg),
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

// ═══════════════════════════════════════════
// 공용 Welcome 카드
// ═══════════════════════════════════════════

class _WelcomeCard extends ConsumerWidget {
  const _WelcomeCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final departmentsAsync = ref.watch(departmentListProvider);
    final deptName = departmentsAsync.valueOrNull
        ?.where((d) => d.id == user.departmentId)
        .map((d) => d.name)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? AppSizes.md : AppSizes.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0] : '?',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.greeting,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.roleDisplay,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (deptName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            deptName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
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
}

// ═══════════════════════════════════════════
// CEO / Admin 대시보드
// ═══════════════════════════════════════════

class _CeoDashboard extends ConsumerWidget {
  const _CeoDashboard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allMyTasksProvider);
    final theme = Theme.of(context);

    return tasksAsync.when(
      data: (allTasks) {
        final today = _todayOnly(DateTime.now());
        final todayTasks = allTasks
            .where((t) => t.dueDate != null && _sameDay(t.dueDate!, today))
            .where((t) => !t.isTemplate)
            .toList();
        final completedToday =
            todayTasks.where((t) => t.status == TaskStatus.completed).length;
        final totalToday = todayTasks.length;
        final delayedTasks =
            allTasks.where((t) => t.isDelayed && !t.isTemplate).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('오늘 완료율'),
            _CompletionRateCard(
              completed: completedToday,
              total: totalToday,
            ),
            const SizedBox(height: AppSizes.lg),
            _SectionTitle('부서별 상태'),
            _DepartmentStatusGrid(allTasks: allTasks),
            const SizedBox(height: AppSizes.lg),
            if (delayedTasks.isNotEmpty) ...[
              _SectionTitle('⚠️ 지연 업무 ${delayedTasks.length}건',
                  color: AppColors.error),
              _DelayedTasksList(tasks: delayedTasks.take(5).toList()),
              const SizedBox(height: AppSizes.lg),
            ],
            _SectionTitle('최근 활동'),
            _RecentActivityPanel(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('오류: $e', style: TextStyle(color: theme.colorScheme.error)),
    );
  }
}

class _CompletionRateCard extends StatelessWidget {
  const _CompletionRateCard({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = total == 0 ? 0.0 : completed / total;
    final pct = (rate * 100).round();
    final color = rate >= 0.8
        ? AppColors.done
        : (rate >= 0.5 ? AppColors.warning : AppColors.error);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$completed / $total 완료',
                    style: theme.textTheme.titleMedium),
                Text('$pct%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentStatusGrid extends ConsumerWidget {
  const _DepartmentStatusGrid({required this.allTasks});
  final List<Task> allTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final departmentsAsync = ref.watch(departmentListProvider);

    return departmentsAsync.when(
      data: (departments) {
        final today = _todayOnly(DateTime.now());
        return LayoutBuilder(builder: (context, constraints) {
          final crossAxis = constraints.maxWidth > 600 ? 3 : 2;
          return GridView.count(
            crossAxisCount: crossAxis,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSizes.sm,
            crossAxisSpacing: AppSizes.sm,
            childAspectRatio: 1.4,
            children: departments.map((d) {
              final deptTasks = allTasks
                  .where((t) => t.departmentId == d.id && !t.isTemplate)
                  .where(
                      (t) => t.dueDate != null && _sameDay(t.dueDate!, today))
                  .toList();
              final done = deptTasks
                  .where((t) => t.status == TaskStatus.completed)
                  .length;
              final total = deptTasks.length;
              final pct = total == 0 ? 0 : ((done / total) * 100).round();

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/departments/${d.id}'),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text('$done / $total',
                            style: theme.textTheme.titleMedium),
                        Text('$pct%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        });
      },
      loading: () =>
          const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      error: (e, _) => Text('부서 로딩 오류: $e'),
    );
  }
}

class _DelayedTasksList extends StatelessWidget {
  const _DelayedTasksList({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: tasks.map((t) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.schedule, color: AppColors.error),
            title: Text(t.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${t.departmentName ?? '(부서 없음)'} · ${t.assigneeName ?? '(담당자 없음)'}'
              '${t.delayDays != null ? ' · ${t.delayDays}일 지연' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => context.push('/tasks/${t.id}'),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Manager 대시보드
// ═══════════════════════════════════════════

class _ManagerDashboard extends ConsumerWidget {
  const _ManagerDashboard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allMyTasksProvider);

    return tasksAsync.when(
      data: (allTasks) {
        final today = _todayOnly(DateTime.now());

        final myDeptTasks = user.departmentId == null
            ? <Task>[]
            : allTasks
                .where((t) => t.departmentId == user.departmentId && !t.isTemplate)
                .toList();

        final myDeptToday = myDeptTasks
            .where((t) => t.dueDate != null && _sameDay(t.dueDate!, today))
            .toList();

        final assignedByMe = allTasks
            .where((t) => t.assignerId == user.id && !t.isTemplate)
            .toList();
        final assignedByMeCompleted = assignedByMe
            .where((t) => t.status == TaskStatus.completed)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 신규 지시 버튼
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/tasks/create'),
                icon: const Icon(Icons.add),
                label: const Text('신규 업무 지시'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            _SectionTitle('오늘 우리 부서 완료율'),
            _CompletionRateCard(
              completed: myDeptToday
                  .where((t) => t.status == TaskStatus.completed)
                  .length,
              total: myDeptToday.length,
            ),
            const SizedBox(height: AppSizes.lg),
            _SectionTitle('내가 지시한 업무 완료 현황'),
            _CompletionRateCard(
              completed: assignedByMeCompleted,
              total: assignedByMe.length,
            ),
            const SizedBox(height: AppSizes.lg),
            _SectionTitle('우리 부서 지연 업무'),
            _DelayedTasksList(
              tasks: myDeptTasks.where((t) => t.isDelayed).take(5).toList(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('오류: $e'),
    );
  }
}

// ═══════════════════════════════════════════
// Staff 대시보드
// ═══════════════════════════════════════════

class _StaffDashboard extends ConsumerWidget {
  const _StaffDashboard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allMyTasksProvider);
    final theme = Theme.of(context);

    return tasksAsync.when(
      data: (allTasks) {
        final today = _todayOnly(DateTime.now());
        final myTasks = allTasks
            .where((t) => t.assigneeId == user.id && !t.isTemplate)
            .toList();

        final todayMyTasks = myTasks
            .where((t) =>
                t.dueDate != null && _sameDay(t.dueDate!, today) ||
                t.status == TaskStatus.inProgress)
            .toList();

        final pendingReport = myTasks
            .where((t) =>
                (t.status == TaskStatus.incomplete ||
                    t.status == TaskStatus.delayed) &&
                (t.delayReason == null || t.delayReason!.isEmpty))
            .toList();

        final recurringThisWeek = myTasks.where((t) {
          if (t.dueDate == null) return false;
          if (t.recurrenceTemplateId == null) return false;
          final diff = t.dueDate!.difference(today).inDays;
          return diff >= 0 && diff < 7;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingReport.isNotEmpty) ...[
              Card(
                color: AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '사유 미입력 업무 ${pendingReport.length}건이 있습니다',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
            ],
            _SectionTitle('오늘 내 업무 ${todayMyTasks.length}건'),
            if (todayMyTasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.beach_access_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          '오늘 할 일이 없습니다',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...todayMyTasks.take(5).map((t) => _StaffTaskTile(task: t)),
            if (todayMyTasks.length > 5)
              TextButton(
                onPressed: () => context.push('/tasks'),
                child: Text('외 ${todayMyTasks.length - 5}건 전체 보기'),
              ),
            const SizedBox(height: AppSizes.lg),
            if (recurringThisWeek.isNotEmpty) ...[
              _SectionTitle('이번 주 반복 업무'),
              ...recurringThisWeek.take(5).map((t) => _StaffTaskTile(task: t)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('오류: $e'),
    );
  }
}

class _StaffTaskTile extends StatelessWidget {
  const _StaffTaskTile({required this.task});
  final Task task;

  Color _statusColor() {
    if (task.isDelayed && task.status != TaskStatus.completed) {
      return AppColors.error;
    }
    switch (task.status) {
      case TaskStatus.completed:
        return AppColors.done;
      case TaskStatus.inProgress:
        return AppColors.inProgress;
      default:
        return AppColors.todo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor(),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(task.title, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${task.status.label}'
          '${task.dueTime != null ? ' · ${task.dueTime}' : ''}'
          '${task.recurrencePattern != null ? ' · 반복' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () => context.push('/tasks/${task.id}'),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 공용 위젯
// ═══════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.color});
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

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
            _SectionTitle('이번 주 일정'),
            TextButton(
              onPressed: () => context.go('/calendar'),
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
                    ? () => context.push(e.routePath!)
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

class _RecentMemosPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(recentMemosProvider);
    final theme = Theme.of(context);

    return memosAsync.when(
      data: (memos) {
        if (memos.isEmpty) return const SizedBox.shrink();
        final display = memos.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionTitle('최근 메모'),
                TextButton(
                  onPressed: () => context.go('/memos'),
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            ...display.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      m.isPinned ? Icons.push_pin : Icons.note_alt_outlined,
                      size: 20,
                      color: m.isPinned ? theme.colorScheme.primary : null,
                    ),
                    title: Text(
                      m.title.isEmpty ? '(제목 없음)' : m.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      m.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () => context.push('/memos/${m.id}'),
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

class _RecentActivityPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(dashboardActivitiesProvider);
    final theme = Theme.of(context);

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Text(
                '최근 활동이 없습니다',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        final display = activities.take(5).toList();
        return Card(
          child: Column(
            children: [
              ...display.map((a) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        a.userName?.isNotEmpty == true ? a.userName![0] : '?',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    title: Text(
                      a.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(a.timeAgo),
                    trailing: a.routePath != null
                        ? const Icon(Icons.chevron_right, size: 16)
                        : null,
                    onTap: a.routePath != null
                        ? () => context.push(a.routePath!)
                        : null,
                  )),
              const Divider(height: 1),
              TextButton(
                onPressed: () => context.push('/activity'),
                child: const Text('전체 활동 보기'),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════
// 도우미
// ═══════════════════════════════════════════

DateTime _todayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
