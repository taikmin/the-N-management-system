import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/department_provider.dart';

/// 부서 상세 화면
class DepartmentDetailScreen extends ConsumerWidget {
  const DepartmentDetailScreen({super.key, required this.departmentId});

  final String departmentId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부서 삭제'),
        content: const Text('정말 이 부서를 삭제하시겠습니까?\n'
            '소속 직원의 부서 배정은 해제됩니다.'),
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
      await ref.read(departmentListProvider.notifier).deleteDepartment(departmentId);
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
    final deptAsync = ref.watch(departmentDetailProvider(departmentId));
    final membersAsync = ref.watch(departmentMembersProvider(departmentId));
    final statsAsync = ref.watch(departmentTaskStatsProvider(departmentId));
    final canManage = ref.watch(isManagementProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('부서 상세'),
        actions: [
          if (canManage)
            deptAsync.when(
              data: (d) => Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.push(
                      '/departments/${d.id}/edit',
                      extra: d,
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
      body: deptAsync.when(
        data: (d) => ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFF000000 |
                                    int.parse(
                                        d.color.replaceAll('#', ''),
                                        radix: 16))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.business_outlined),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Text(
                            d.name,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (d.description != null &&
                        d.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.md),
                      Text(d.description!, style: theme.textTheme.bodyMedium),
                    ],
                    if (d.leadName != null) ...[
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 6),
                          Text('팀장: ${d.leadName}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            statsAsync.when(
              data: (stats) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('업무 현황',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSizes.sm),
                      Wrap(
                        spacing: AppSizes.md,
                        runSpacing: AppSizes.sm,
                        children: [
                          _StatBadge(label: '전체', count: stats['total'] ?? 0),
                          _StatBadge(
                              label: '지시됨', count: stats['assigned'] ?? 0),
                          _StatBadge(
                              label: '진행중',
                              count: stats['in_progress'] ?? 0),
                          _StatBadge(
                              label: '완료', count: stats['completed'] ?? 0),
                          _StatBadge(
                              label: '미완료',
                              count: stats['incomplete'] ?? 0),
                          _StatBadge(
                              label: '지연', count: stats['delayed'] ?? 0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSizes.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('소속 직원',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSizes.sm),
                    membersAsync.when(
                      data: (members) {
                        if (members.isEmpty) {
                          return const Text('배정된 직원이 없습니다');
                        }
                        return Column(
                          children: members.map((m) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  ((m['full_name'] as String?) ?? '?')[0],
                                ),
                              ),
                              title: Text(
                                  m['full_name'] as String? ?? '이름 없음'),
                              subtitle: Text(m['email'] as String? ?? ''),
                              trailing: Chip(
                                label: Text(m['role'] as String? ?? 'staff'),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
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
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(width: 6),
          Text('$count',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
