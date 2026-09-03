import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/memo.dart';
import '../../providers/memo_provider.dart';

/// 개인 메모 목록 화면
class MemoListScreen extends ConsumerStatefulWidget {
  const MemoListScreen({super.key});

  @override
  ConsumerState<MemoListScreen> createState() =>
      _MemoListScreenState();
}

class _MemoListScreenState
    extends ConsumerState<MemoListScreen> {
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickAdd() async {
    final title = _quickAddController.text.trim();
    if (title.isEmpty) return;

    try {
      await ref
          .read(myMemosProvider.notifier)
          .quickCreate(title);
      _quickAddController.clear();
      _quickAddFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(memoFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              ref
                  .read(myMemosProvider.notifier)
                  .refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              AppSizes.sm,
              AppSizes.md,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                ref
                    .read(memoSearchQueryProvider
                        .notifier)
                    .state = v;
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: '메모 검색...',
                prefixIcon:
                    const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchController
                        .text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController
                              .clear();
                          ref
                              .read(
                                  memoSearchQueryProvider
                                      .notifier)
                              .state = '';
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 빠른 추가 입력
          _QuickAddBar(
            controller: _quickAddController,
            focusNode: _quickAddFocus,
            onSubmit: _handleQuickAdd,
          ),

          // 필터 칩 바
          _FilterChipBar(
            current: filter,
            onChanged: (f) {
              ref.read(memoFilterProvider.notifier)
                  .state = f;
            },
          ),

          // 메모 리스트
          Expanded(child: _MemoList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/memos/create'),
        tooltip: '메모 작성',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 빠른 추가 바
class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: '메모를 빠르게 추가...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: AppSizes.sm,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSubmit,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// 필터 칩 바
class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({
    required this.current,
    required this.onChanged,
  });

  final MemoFilter current;
  final ValueChanged<MemoFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: MemoFilter.values.map((f) {
          final selected = f == current;
          return Padding(
            padding: const EdgeInsets.only(
                right: AppSizes.xs),
            child: FilterChip(
              label: Text(_filterLabel(f)),
              selected: selected,
              onSelected: (_) => onChanged(f),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _filterLabel(MemoFilter f) {
    switch (f) {
      case MemoFilter.all:
        return '전체';
      case MemoFilter.idea:
        return '아이디어';
      case MemoFilter.memo:
        return '메모';
      case MemoFilter.todo:
        return '할일';
      case MemoFilter.archived:
        return '보관됨';
    }
  }
}

/// 메모 리스트
class _MemoList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync =
        ref.watch(filteredMemosProvider);

    return memosAsync.when(
      data: (memos) {
        if (memos.isEmpty) return const _EmptyState();
        return ListView.builder(
          padding: const EdgeInsets.only(
            bottom: 80,
            top: AppSizes.xs,
          ),
          itemCount: memos.length,
          itemBuilder: (context, index) {
            return _MemoTile(memo: memos[index]);
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('오류: $e')),
    );
  }
}

/// 개별 메모 타일
class _MemoTile extends ConsumerWidget {
  const _MemoTile({required this.memo});
  final Memo memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArchived =
        memo.status == MemoStatus.archived;

    return Dismissible(
      key: ValueKey(memo.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding:
            const EdgeInsets.only(left: AppSizes.lg),
        color: AppColors.info,
        child: Icon(
          isArchived
              ? Icons.unarchive
              : Icons.archive,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding:
            const EdgeInsets.only(right: AppSizes.lg),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (isArchived) {
            await ref
                .read(myMemosProvider.notifier)
                .unarchiveMemo(memo.id);
          } else {
            await ref
                .read(myMemosProvider.notifier)
                .archiveMemo(memo.id);
          }
          return false;
        } else {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('메모 삭제'),
              content: Text(
                '"${memo.title}"을(를) 삭제하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, true),
                  child: const Text('삭제'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          ref
              .read(myMemosProvider.notifier)
              .deleteMemo(memo.id);
        }
      },
      child: ListTile(
        leading: memo.isPinned
            ? Icon(Icons.push_pin,
                size: 20,
                color: theme.colorScheme.primary)
            : null,
        title: Text(
          memo.title.isNotEmpty
              ? memo.title
              : '(제목 없음)',
          style: TextStyle(
            color: isArchived
                ? theme.colorScheme.onSurfaceVariant
                : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (memo.category != null) ...[
              _CategoryBadge(
                  category: memo.category!),
              const SizedBox(width: AppSizes.xs),
            ],
            Text(
              memo.createdAtDisplay,
              style:
                  theme.textTheme.bodySmall?.copyWith(
                color: theme
                    .colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (memo.priority != MemoPriority.none)
              _PriorityDot(priority: memo.priority),
            IconButton(
              icon: Icon(
                memo.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                size: 18,
              ),
              tooltip: memo.isPinned ? '고정 해제' : '고정',
              onPressed: () {
                ref
                    .read(myMemosProvider.notifier)
                    .togglePin(
                        memo.id, memo.isPinned);
              },
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onTap: () =>
            context.push('/memos/${memo.id}'),
      ),
    );
  }
}

/// 카테고리 배지
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color get _color {
    switch (category) {
      case '아이디어':
        return Colors.purple;
      case '메모':
        return AppColors.info;
      case '할일':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }
}

/// 우선순위 점
class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final MemoPriority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
      ),
    );
  }

  Color get _color {
    switch (priority) {
      case MemoPriority.high:
        return AppColors.error;
      case MemoPriority.medium:
        return AppColors.info;
      case MemoPriority.low:
        return AppColors.todo;
      case MemoPriority.none:
        return Colors.transparent;
    }
  }
}

/// 빈 상태
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            '메모가 없습니다',
            style:
                theme.textTheme.titleMedium?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            '위 입력창에 메모를 추가하거나\n'
            '+ 버튼으로 상세 메모를 작성해 보세요',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
