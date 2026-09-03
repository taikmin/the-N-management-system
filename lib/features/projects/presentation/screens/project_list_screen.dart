import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../domain/models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/project_card.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() =>
      _ProjectListScreenState();
}

class _ProjectListScreenState
    extends ConsumerState<ProjectListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(filteredProjectListProvider);
    final statusFilter = ref.watch(projectStatusFilterProvider);
    final theme = Theme.of(context);
    final isMobile =
        ResponsiveLayout.isMobile(context);
    final hPad =
        isMobile ? AppSizes.sm : AppSizes.md;

    return Scaffold(
      appBar: AppBar(
        title: const Text('과제 관리'),
        actions: [
          _ProjectSortButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(projectListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 + 필터
          Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              AppSizes.sm,
              hPad,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(projectSearchQueryProvider.notifier).state = value;
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: '과제명, 과제번호, 책임자, 담당자 검색...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchController
                        .text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(
                                  projectSearchQueryProvider
                                      .notifier)
                              .state = '';
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 상태 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: '전체',
                  selected: statusFilter == null,
                  onSelected: (_) => ref
                      .read(projectStatusFilterProvider.notifier)
                      .state = null,
                ),
                const SizedBox(width: AppSizes.sm),
                ...ProjectStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: AppSizes.sm),
                    child: _FilterChip(
                      label: status.label,
                      selected: statusFilter == status,
                      onSelected: (_) => ref
                          .read(projectStatusFilterProvider.notifier)
                          .state = statusFilter == status ? null : status,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 과제 목록
          Expanded(
            child: projectsAsync.when(
              data: (projects) {
                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          '등록된 과제가 없습니다',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSizes.sm),
                        FilledButton.icon(
                          onPressed: () => context.push('/projects/create'),
                          icon: const Icon(Icons.add),
                          label: const Text('새 과제 생성'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(projectListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: EdgeInsets.all(hPad),
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                        child: ProjectCard(
                          project: project,
                          onTap: () => context.push(
                            '/projects/${project.id}',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/projects/create'),
        icon: const Icon(Icons.add),
        label: const Text('새 과제'),
      ),
    );
  }
}

class _ProjectSortButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(projectSortProvider);
    return PopupMenuButton<ProjectSort>(
      icon: const Icon(Icons.sort),
      tooltip: '정렬',
      onSelected: (sort) => ref
          .read(projectSortProvider.notifier)
          .state = sort,
      itemBuilder: (context) => ProjectSort.values
          .map(
            (s) => PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  if (s == current)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(s.label),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}
