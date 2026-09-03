import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../domain/models/task.dart';
import '../../providers/task_provider.dart';

/// 메인 업무 관리 화면 (Todo 스타일)
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() =>
      _TaskListScreenState();
}

class _TaskListScreenState
    extends ConsumerState<TaskListScreen> {
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _listAreaKey = GlobalKey();
  bool _showSearch = false;

  // ─── 자동 스크롤 ───
  Timer? _autoScrollTimer;
  double _lastGlobalY = 0;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter
        .addGlobalRoute(_onPointerEvent);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_onPointerEvent);
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPointerEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _lastGlobalY = event.position.dy;
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performAutoScroll(),
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _performAutoScroll() {
    final renderBox = _listAreaKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (renderBox == null ||
        !_scrollController.hasClients) {
      return;
    }

    final listTop =
        renderBox.localToGlobal(Offset.zero).dy;
    final listHeight = renderBox.size.height;
    final localY = _lastGlobalY - listTop;

    const edgeSize = 100.0;
    const maxSpeed = 15.0;

    double scrollDelta = 0;
    if (localY < edgeSize && localY >= 0) {
      final ratio = 1 - (localY / edgeSize);
      scrollDelta = -maxSpeed * ratio;
    } else if (localY > listHeight - edgeSize &&
        localY <= listHeight) {
      final ratio =
          1 - ((listHeight - localY) / edgeSize);
      scrollDelta = maxSpeed * ratio;
    }

    if (scrollDelta != 0) {
      final newOffset =
          (_scrollController.offset + scrollDelta)
              .clamp(
        0.0,
        _scrollController
            .position.maxScrollExtent,
      );
      _scrollController.jumpTo(newOffset);
    }
  }

  Future<void> _handleQuickAdd() async {
    final title = _quickAddController.text.trim();
    if (title.isEmpty) return;

    try {
      await ref
          .read(allMyTasksProvider.notifier)
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
    final filter = ref.watch(taskFilterProvider);
    final groupByProject =
        ref.watch(taskGroupByProjectProvider);
    final isMobile =
        ResponsiveLayout.isMobile(context);

    // 드래그 상태에 따라 자동 스크롤 시작/중지
    ref.listen<bool>(dragActiveProvider,
        (prev, next) {
      if (next) {
        _startAutoScroll();
      } else {
        _stopAutoScroll();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: _showSearch && isMobile
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => ref
                    .read(taskSearchQueryProvider
                        .notifier)
                    .state = v,
                decoration: InputDecoration(
                  hintText: '검색...',
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref
                          .read(
                              taskSearchQueryProvider
                                  .notifier)
                          .state = '';
                      setState(
                        () => _showSearch = false,
                      );
                    },
                  ),
                ),
              )
            : const Text('업무 관리'),
        actions: [
          if (isMobile && !_showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '검색',
              onPressed: () => setState(
                () => _showSearch = true,
              ),
            ),
          _SortButton(),
          IconButton(
            icon: Icon(
              groupByProject
                  ? Icons.folder_outlined
                  : Icons.list,
            ),
            tooltip: groupByProject
                ? '플랫 리스트'
                : '과제별 그룹핑',
            onPressed: () {
              ref
                  .read(taskGroupByProjectProvider
                      .notifier)
                  .state = !groupByProject;
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              ref
                  .read(
                      allMyTasksProvider.notifier)
                  .refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 바 — PC에서만 항상 표시
          if (!isMobile)
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
                      .read(taskSearchQueryProvider
                          .notifier)
                      .state = v;
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText:
                      '업무명, 담당자, 과제 검색...',
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
                                    taskSearchQueryProvider
                                        .notifier)
                                .state = '';
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),

          // 빠른 추가 입력 — PC에서만 표시
          if (!isMobile)
            _QuickAddBar(
              controller: _quickAddController,
              focusNode: _quickAddFocus,
              onSubmit: _handleQuickAdd,
            ),

          // 필터 칩 바
          _FilterChipBar(
            current: filter,
            onChanged: (f) {
              ref
                  .read(
                      taskFilterProvider.notifier)
                  .state = f;
            },
            compact: isMobile,
          ),

          // 태스크 리스트
          Expanded(
            key: _listAreaKey,
            child: groupByProject
                ? _GroupedTaskList(
                    compact: isMobile,
                    scrollController:
                        _scrollController,
                  )
                : _FlatTaskList(
                    compact: isMobile,
                    scrollController:
                        _scrollController,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/tasks/create'),
        tooltip: '상세 업무 생성',
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
            color:
                theme.colorScheme.outlineVariant,
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
                hintText: '할 일을 빠르게 추가...',
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(
                  vertical: AppSizes.sm,
                ),
              ),
              textInputAction:
                  TextInputAction.done,
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
class _FilterChipBar extends ConsumerWidget {
  const _FilterChipBar({
    required this.current,
    required this.onChanged,
    this.compact = false,
  });

  final TaskFilter current;
  final ValueChanged<TaskFilter> onChanged;
  final bool compact;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final completedSub =
        ref.watch(completedSubFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal:
            compact ? AppSizes.sm : AppSizes.md,
        vertical:
            compact ? AppSizes.xs : AppSizes.sm,
      ),
      child: Row(
        children: [
          ...TaskFilter.values.map((f) {
            final selected = f == current;
            return Padding(
              padding: EdgeInsets.only(
                right: compact
                    ? 2.0
                    : AppSizes.xs,
              ),
              child: FilterChip(
                label: Text(_filterLabel(f)),
                selected: selected,
                onSelected: (_) =>
                    onChanged(f),
                visualDensity: compact
                    ? VisualDensity.compact
                    : null,
              ),
            );
          }),
          // 완료 탭 하위 필터
          if (current == TaskFilter.completed) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 20,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant,
            ),
            const SizedBox(width: 8),
            ...CompletedSubFilter.values.map(
              (sf) {
                final sel =
                    sf == completedSub;
                return Padding(
                  padding: EdgeInsets.only(
                    right: compact
                        ? 2.0
                        : AppSizes.xs,
                  ),
                  child: FilterChip(
                    label: Text(
                      sf.label,
                      style: TextStyle(
                        fontSize:
                            compact ? 11 : 12,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => ref
                        .read(
                          completedSubFilterProvider
                              .notifier,
                        )
                        .state = sf,
                    visualDensity:
                        VisualDensity.compact,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _filterLabel(TaskFilter f) {
    switch (f) {
      case TaskFilter.all:
        return '전체';
      case TaskFilter.today:
        return '오늘';
      case TaskFilter.delayed:
        return '지연';
      case TaskFilter.completed:
        return '완료';
    }
  }
}

/// 플랫 태스크 리스트
class _FlatTaskList extends ConsumerWidget {
  const _FlatTaskList({
    this.compact = false,
    this.scrollController,
  });
  final bool compact;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync =
        ref.watch(filteredTasksProvider);
    final isMobile =
        ResponsiveLayout.isMobile(context);

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const _EmptyState();
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(
            bottom: 80,
            top: AppSizes.xs,
          ),
          // PC에서 드롭 영역 +1
          itemCount:
              tasks.length + (isMobile ? 0 : 1),
          itemBuilder: (context, index) {
            // PC 첫 번째: 독립 업무 드롭 영역
            if (!isMobile && index == 0) {
              return _IndependentDropZone(
                ref: ref,
              );
            }
            final taskIdx =
                isMobile ? index : index - 1;
            final task = tasks[taskIdx];

            if (isMobile) {
              return _TaskTile(
                task: task,
                compact: compact,
                onMoveRequest: () =>
                    _showMoveSheet(
                  context,
                  ref,
                  task,
                ),
              );
            }

            // PC: DragTarget + Draggable
            return _DraggableTaskItem(
              task: task,
              compact: compact,
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) =>
          Center(child: Text('오류: $e')),
    );
  }
}

/// 과제별 그룹핑 리스트
class _GroupedTaskList extends ConsumerWidget {
  const _GroupedTaskList({
    this.compact = false,
    this.scrollController,
  });
  final bool compact;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync =
        ref.watch(groupedTasksProvider);
    final theme = Theme.of(context);

    return groupedAsync.when(
      data: (grouped) {
        if (grouped.isEmpty) {
          return const _EmptyState();
        }

        final entries = grouped.entries.toList();
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(
            bottom: 80,
            top: AppSizes.xs,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        entry.key == '독립 업무'
                            ? Icons
                                .person_outline
                            : Icons
                                .science_outlined,
                        size: 18,
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(
                        width: AppSizes.xs,
                      ),
                      Text(
                        entry.key,
                        style: theme
                            .textTheme.titleSmall
                            ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(
                        width: AppSizes.xs,
                      ),
                      Text(
                        '(${entry.value.length})',
                        style: theme
                            .textTheme.bodySmall
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value.map(
                  (t) {
                    final mob =
                        ResponsiveLayout.isMobile(
                      context,
                    );
                    if (mob) {
                      return _TaskTile(
                        task: t,
                        compact: compact,
                        onMoveRequest: () =>
                            _showMoveSheet(
                          context,
                          ref,
                          t,
                        ),
                      );
                    }
                    return _DraggableTaskItem(
                      task: t,
                      compact: compact,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) =>
          Center(child: Text('오류: $e')),
    );
  }
}

/// 개별 태스크 타일
class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    this.compact = false,
    this.onMoveRequest,
    this.highlighted = false,
    this.highlightColor,
  });
  final Task task;
  final bool compact;
  final VoidCallback? onMoveRequest;
  final bool highlighted;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCompleted =
        task.status == TaskStatus.completed;
    final subTasksMap =
        ref.watch(subTasksMapProvider);
    final subTasks =
        subTasksMap[task.id] ?? [];
    final hasSubTasks = subTasks.isNotEmpty;

    return Container(
      decoration: highlighted
          ? BoxDecoration(
              border: Border.all(
                color: highlightColor ??
                    AppColors.primary,
                width: 2,
              ),
              borderRadius:
                  BorderRadius.circular(4),
            )
          : null,
      child: Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(
          left: AppSizes.lg,
        ),
        color: AppColors.done,
        child: const Icon(
          Icons.check,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(
          right: AppSizes.lg,
        ),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction ==
            DismissDirection.startToEnd) {
          await ref
              .read(allMyTasksProvider.notifier)
              .toggleComplete(
                  task.id, task.status);
          return false;
        } else {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('업무 삭제'),
              content: Text(
                '"${task.title}"을(를) 삭제하시겠습니까?',
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
        if (direction ==
            DismissDirection.endToStart) {
          ref
              .read(allMyTasksProvider.notifier)
              .deleteTask(task.id);
        }
      },
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                // 색상 태그 바
                _ColorTagBar(
                  tag: task.colorTag,
                  taskId: task.id,
                ),
                // 메인 컨텐츠
                Expanded(
                  child: ListTile(
                    dense: compact,
                    visualDensity: compact
                        ? VisualDensity.compact
                        : null,
                    leading: Checkbox(
                      value: isCompleted,
                      visualDensity: compact
                          ? VisualDensity.compact
                          : null,
                      onChanged: (_) {
                        ref
                            .read(allMyTasksProvider
                                .notifier)
                            .toggleComplete(
                              task.id,
                              task.status,
                            );
                      },
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: isCompleted
                            ? TextDecoration
                                .lineThrough
                            : null,
                        color: isCompleted
                            ? theme.colorScheme
                                .onSurfaceVariant
                            : null,
                      ),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        if (task.isNew)
                          _NewBadge(),
                        if (task.isRecentlyCompleted ||
                            subTasks.any(
                              (s) =>
                                  s.isRecentlyCompleted,
                            ))
                          _DoneBadge(),
                        Expanded(
                          child: Text(
                            [
                              task.belongsToLabel,
                              if (task.assigneeName !=
                                  null)
                                '담당: ${task.assigneeName}'
                              else if (task
                                      .creatorName !=
                                  null)
                                '등록: ${task.creatorName}',
                              if (task.createdAt !=
                                  null)
                                _formatDate(
                                    task.createdAt!),
                              if (hasSubTasks) ...[
                                () {
                                  final done = subTasks
                                      .where((s) =>
                                          s.status ==
                                          TaskStatus
                                              .completed)
                                      .length;
                                  final label =
                                      '연계 ${subTasks.length}건';
                                  final doneLabel =
                                      done > 0
                                          ? '($done완료)'
                                          : '';
                                  final hasNewSub =
                                      subTasks.any(
                                          (s) => s.isNew);
                                  final hasDoneSub =
                                      subTasks.any((s) =>
                                          s.isRecentlyCompleted);
                                  final newLabel =
                                      hasNewSub
                                          ? ' +NEW'
                                          : hasDoneSub
                                              ? ' +완료'
                                              : '';
                                  return '$label'
                                      '$doneLabel'
                                      '$newLabel';
                                }(),
                              ],
                            ].join(' · '),
                            style: theme
                                .textTheme.bodySmall
                                ?.copyWith(
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        // + 버튼 (연계 업무 추가)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                            ),
                            padding:
                                EdgeInsets.zero,
                            tooltip: '연계 업무 추가',
                            onPressed: () {
                              if (task.projectId !=
                                  null) {
                                context.push(
                                  '/projects/'
                                  '${task.projectId}'
                                  '/tasks/create'
                                  '?parent='
                                  '${task.id}',
                                );
                              } else {
                                context.push(
                                  '/tasks/create'
                                  '?parent='
                                  '${task.id}',
                                );
                              }
                            },
                          ),
                        ),
                        if (task.showInCalendar &&
                            task.plannedEnd != null)
                          Icon(
                            Icons.calendar_month,
                            size: 14,
                            color: theme.colorScheme
                                .primary
                                .withValues(
                                    alpha: 0.6),
                          ),
                        _PriorityDot(
                          priority: task.priority,
                        ),
                        if (task.plannedEnd !=
                            null) ...[
                          const SizedBox(
                            width: AppSizes.xs,
                          ),
                          Text(
                            _dateLabel(task),
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: task.isDelayed
                                  ? AppColors.error
                                  : theme
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight:
                                  task.isDelayed
                                      ? FontWeight
                                          .bold
                                      : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onLongPress: onMoveRequest,
                    onTap: () {
                      if (task.projectId !=
                          null) {
                        context.push(
                          '/projects/${task.projectId}'
                          '/tasks/${task.id}',
                        );
                      } else {
                        context.push(
                          '/tasks/${task.id}',
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // 연계 업무(하위 태스크) 미리보기
          if (hasSubTasks)
            _SubTaskPreview(
              parentTask: task,
              subTasks: subTasks,
            ),
        ],
      ),
      ),
    );
  }

  String _dateLabel(Task t) {
    final end = _formatDate(t.plannedEnd!);
    if (t.plannedStart != null &&
        !(t.plannedStart!.year == t.plannedEnd!.year &&
            t.plannedStart!.month ==
                t.plannedEnd!.month &&
            t.plannedStart!.day ==
                t.plannedEnd!.day)) {
      return '${_formatDate(t.plannedStart!)}~$end';
    }
    return end;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

/// 색상 태그 바 (왼쪽)
class _ColorTagBar extends ConsumerWidget {
  const _ColorTagBar({
    required this.tag,
    required this.taskId,
  });

  final ColorTag tag;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showPicker(context, ref),
      child: Container(
        width: 6,
        decoration: BoxDecoration(
          color: _tagColor(tag),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          ),
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('색상 태그'),
        children: ColorTag.values.map((ct) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(
                      allMyTasksProvider.notifier)
                  .updateColorTag(taskId, ct);
            },
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _tagColor(ct),
                    shape: BoxShape.circle,
                    border: ct == ColorTag.none
                        ? Border.all(
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(ct.label),
                if (ct == tag) ...[
                  const Spacer(),
                  const Icon(
                    Icons.check,
                    size: 18,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static Color _tagColor(ColorTag tag) {
    switch (tag) {
      case ColorTag.red:
        return Colors.red;
      case ColorTag.yellow:
        return Colors.amber;
      case ColorTag.blue:
        return Colors.blue;
      case ColorTag.none:
        return Colors.transparent;
    }
  }
}

/// 연계 업무(하위 태스크) 미리보기 (접기/펼치기)
class _SubTaskPreview
    extends ConsumerStatefulWidget {
  const _SubTaskPreview({
    required this.parentTask,
    required this.subTasks,
  });

  final Task parentTask;
  final List<Task> subTasks;

  @override
  ConsumerState<_SubTaskPreview> createState() =>
      _SubTaskPreviewState();
}

class _SubTaskPreviewState
    extends ConsumerState<_SubTaskPreview> {
  bool _showCompleted = false;
  bool _autoExpanded = false;

  Future<bool?> _confirmDelete(Task st) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('연계 업무 삭제'),
        content: Text(
          '"${st.title}"을(를) 삭제하시겠습니까?',
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
            child: const Text(
              '삭제',
              style:
                  TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteSubTask(Task st) {
    ref
        .read(allMyTasksProvider.notifier)
        .deleteTask(st.id);
  }

  void _navigateToEdit(Task st) {
    if (st.projectId != null) {
      context.push(
        '/projects/${st.projectId}'
        '/tasks/${st.id}/edit',
      );
    } else {
      context.push(
        '/tasks/${st.id}/edit',
      );
    }
  }

  void _navigateToDetail(Task st) {
    if (st.projectId != null) {
      context.push(
        '/projects/${st.projectId}'
        '/tasks/${st.id}',
      );
    } else {
      context.push('/tasks/${st.id}');
    }
  }

  void _showContextMenu(
    Task st,
    Offset position,
  ) {
    final overlay = Overlay.of(context)
        .context
        .findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 18),
              SizedBox(width: 8),
              Text('수정'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outline,
                  size: 18),
              SizedBox(width: 8),
              Text('이동'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('삭제',
                  style: TextStyle(
                      color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'edit') {
        _navigateToEdit(st);
      } else if (value == 'move') {
        if (context.mounted) {
          _showMoveSheet(context, ref, st);
        }
      } else if (value == 'delete') {
        final confirm =
            await _confirmDelete(st);
        if (confirm == true) {
          _deleteSubTask(st);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchedIds =
        ref.watch(matchedSubTaskIdsProvider);
    final hasMatchedSub = widget.subTasks
        .any((s) => matchedIds.contains(s.id));
    final isMobile =
        ResponsiveLayout.isMobile(context);

    final incompleteSubs = widget.subTasks
        .where((s) =>
            s.status != TaskStatus.completed)
        .toList();
    final completedSubs = widget.subTasks
        .where((s) =>
            s.status == TaskStatus.completed)
        .toList();
    final hasCompletedSub =
        completedSubs.isNotEmpty;
    final allCompleted =
        incompleteSubs.isEmpty &&
            hasCompletedSub;

    // 완료 탭 부분완료 필터:
    // 부모 미완료 + 연계 완료 시 자동 펼치기
    final currentFilter =
        ref.watch(taskFilterProvider);
    final completedSub =
        ref.watch(completedSubFilterProvider);
    final isPartialMode =
        currentFilter == TaskFilter.completed &&
            completedSub ==
                CompletedSubFilter.includePartial &&
            widget.parentTask.status !=
                TaskStatus.completed;
    final shouldAutoExpand =
        hasMatchedSub ||
            (isPartialMode && hasCompletedSub);

    // 검색/부분완료 시 자동으로 완료 노출
    if (shouldAutoExpand && !_autoExpanded) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (mounted && !_showCompleted) {
          setState(() {
            _showCompleted = true;
            _autoExpanded = true;
          });
        }
      });
    }
    if (!shouldAutoExpand && _autoExpanded) {
      _autoExpanded = false;
    }

    // 보이는 목록: 항상 미완료,
    // 토글 시 완료도 함께
    final visibleSubs = _showCompleted
        ? widget.subTasks
        : incompleteSubs;

    return Padding(
      padding: const EdgeInsets.only(
        left: 6,
        right: AppSizes.md,
        bottom: AppSizes.xs,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // 전체 완료 상태 헤더
          if (allCompleted && !_showCompleted)
            InkWell(
              onTap: () => setState(
                () => _showCompleted = true,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: theme
                          .colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '전체 완료'
                      ' (${completedSubs.length}건)',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(
                left: isMobile
                    ? AppSizes.lg
                    : AppSizes.xl,
                right: AppSizes.sm,
              ),
              child: _ReorderableSubTaskList(
                visibleSubTasks: visibleSubs,
                allSubTasks: widget.subTasks,
                matchedIds: matchedIds,
                onNavigateDetail:
                    _navigateToDetail,
                onContextMenu: _showContextMenu,
                onDelete: _deleteSubTask,
                onConfirmDelete: _confirmDelete,
                onToggleComplete: (st) {
                  ref
                      .read(allMyTasksProvider
                          .notifier)
                      .toggleComplete(
                        st.id,
                        st.status,
                      );
                },
              ),
            ),
          // 완료 보기/숨기기 토글
          if (hasCompletedSub && !allCompleted)
            InkWell(
              onTap: () => setState(
                () => _showCompleted =
                    !_showCompleted,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      _showCompleted
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showCompleted
                          ? '완료 숨기기'
                          : '완료 ${completedSubs.length}건 보기',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 전체완료 펼친 상태에서 접기
          if (allCompleted && _showCompleted)
            InkWell(
              onTap: () => setState(
                () => _showCompleted = false,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.expand_less,
                      size: 16,
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '접기',
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 연계 업무 리오더 리스트
class _ReorderableSubTaskList
    extends ConsumerWidget {
  const _ReorderableSubTaskList({
    required this.visibleSubTasks,
    required this.allSubTasks,
    required this.matchedIds,
    required this.onNavigateDetail,
    required this.onContextMenu,
    required this.onDelete,
    required this.onConfirmDelete,
    required this.onToggleComplete,
  });

  final List<Task> visibleSubTasks;
  final List<Task> allSubTasks;
  final Set<String> matchedIds;
  final void Function(Task) onNavigateDetail;
  final void Function(Task, Offset)
      onContextMenu;
  final void Function(Task) onDelete;
  final Future<bool?> Function(Task)
      onConfirmDelete;
  final void Function(Task) onToggleComplete;

  /// 미완료만 보이는 상태에서 reorder된
  /// visible 리스트를 전체 리스트의
  /// 원래 위치에 맞게 합친다.
  List<Task> _mergeReorder(
    List<Task> reorderedVisible,
  ) {
    if (visibleSubTasks.length ==
        allSubTasks.length) {
      return reorderedVisible;
    }
    final visibleIds = visibleSubTasks
        .map((t) => t.id)
        .toSet();
    final iter = reorderedVisible.iterator;
    return [
      for (final t in allSubTasks)
        if (visibleIds.contains(t.id))
          (iter..moveNext()).current
        else
          t,
    ];
  }

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final isMobile =
        ResponsiveLayout.isMobile(context);

    // PC: Draggable<Task> + DragTarget<Task>
    if (!isMobile) {
      return Column(
        children: List.generate(
          visibleSubTasks.length,
          (i) {
            final st = visibleSubTasks[i];
            return _PcSubTaskItem(
              key: ValueKey(
                'pc_sub_${st.id}',
              ),
              st: st,
              siblings: visibleSubTasks,
              allSiblings: allSubTasks,
              highlighted:
                  matchedIds.contains(st.id),
              onTap: () =>
                  onNavigateDetail(st),
              onLongPress: (pos) =>
                  onContextMenu(st, pos),
              onDismissed: () =>
                  onDelete(st),
              onConfirmDismiss: () =>
                  onConfirmDelete(st),
              onToggleComplete: () =>
                  onToggleComplete(st),
            );
          },
        ),
      );
    }

    // Mobile: ReorderableListView
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: visibleSubTasks.length,
      onReorder: (oldIdx, newIdx) {
        if (newIdx > oldIdx) newIdx--;
        final reordered =
            List<Task>.from(visibleSubTasks);
        final item =
            reordered.removeAt(oldIdx);
        reordered.insert(newIdx, item);
        final merged = _mergeReorder(reordered);
        ref
            .read(allMyTasksProvider.notifier)
            .reorderSubTasks(
              merged
                  .map((t) => t.id)
                  .toList(),
            );
      },
      proxyDecorator:
          (child, index, animation) {
        return Material(
          elevation: 4,
          color: Colors.transparent,
          child: child,
        );
      },
      itemBuilder: (context, i) {
        final st = visibleSubTasks[i];
        final isMatched =
            matchedIds.contains(st.id);
        return _SubTaskRow(
          key: ValueKey('sub_${st.id}'),
          st: st,
          index: i,
          highlighted: isMatched,
          onTap: () =>
              onNavigateDetail(st),
          onLongPress: (pos) =>
              onContextMenu(st, pos),
          onDismissed: () =>
              onDelete(st),
          onConfirmDismiss: () =>
              onConfirmDelete(st),
          onToggleComplete: () =>
              onToggleComplete(st),
        );
      },
    );
  }
}

/// PC 전용: Draggable + DragTarget 연계 업무 행
class _PcSubTaskItem
    extends ConsumerStatefulWidget {
  const _PcSubTaskItem({
    super.key,
    required this.st,
    required this.siblings,
    required this.allSiblings,
    this.highlighted = false,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
    required this.onConfirmDismiss,
    required this.onToggleComplete,
  });

  final Task st;
  final List<Task> siblings;
  final List<Task> allSiblings;
  final bool highlighted;
  final VoidCallback onTap;
  final void Function(Offset) onLongPress;
  final VoidCallback onDismissed;
  final Future<bool?> Function()
      onConfirmDismiss;
  final VoidCallback onToggleComplete;

  @override
  ConsumerState<_PcSubTaskItem>
      createState() => _PcSubTaskItemState();
}

class _PcSubTaskItemState
    extends ConsumerState<_PcSubTaskItem> {
  bool _isDragging = false;

  void _handleSiblingReorder(Task dragged) {
    final reordered =
        List<Task>.from(widget.siblings);
    final oldIdx = reordered
        .indexWhere((t) => t.id == dragged.id);
    if (oldIdx < 0) return;
    final item = reordered.removeAt(oldIdx);
    final newIdx = reordered
        .indexWhere((t) => t.id == widget.st.id);
    reordered.insert(
      newIdx >= 0
          ? newIdx
          : reordered.length,
      item,
    );
    // visible(미완료)만 reorder된 경우
    // 전체 리스트의 원래 위치를 보존
    final merged = _mergeWithAll(reordered);
    ref
        .read(allMyTasksProvider.notifier)
        .reorderSubTasks(
          merged.map((t) => t.id).toList(),
        );
  }

  List<Task> _mergeWithAll(
    List<Task> reorderedVisible,
  ) {
    if (widget.siblings.length ==
        widget.allSiblings.length) {
      return reorderedVisible;
    }
    final visibleIds = widget.siblings
        .map((t) => t.id)
        .toSet();
    final iter = reorderedVisible.iterator;
    return [
      for (final t in widget.allSiblings)
        if (visibleIds.contains(t.id))
          (iter..moveNext()).current
        else
          t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = widget.st;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) {
        final d = details.data;
        if (d.id == st.id) return false;
        // 같은 부모의 형제 → 리오더
        if (d.parentTaskId != null &&
            d.parentTaskId ==
                st.parentTaskId) {
          return true;
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        _handleSiblingReorder(details.data);
      },
      builder: (
        ctx,
        candidates,
        rejected,
      ) {
        final isDropTarget =
            candidates.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(
            milliseconds: 150,
          ),
          decoration: BoxDecoration(
            color: widget.highlighted
                ? Colors.amber.shade50
                : isDropTarget
                    ? AppColors.primary
                        .withValues(alpha: 0.08)
                    : null,
            border: isDropTarget
                ? const Border(
                    top: BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: AnimatedOpacity(
            duration: const Duration(
              milliseconds: 150,
            ),
            opacity: _isDragging ? 0.3 : 1.0,
            child: Dismissible(
              key: ValueKey(
                'dismiss_pc_${st.id}',
              ),
              direction: DismissDirection
                  .endToStart,
              background: Container(
                alignment:
                    Alignment.centerRight,
                padding:
                    const EdgeInsets.only(
                  right: AppSizes.md,
                ),
                color: AppColors.error,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              confirmDismiss: (_) =>
                  widget.onConfirmDismiss(),
              onDismissed: (_) =>
                  widget.onDismissed(),
              child: GestureDetector(
                onLongPressStart: (d) =>
                    widget.onLongPress(
                  d.globalPosition,
                ),
                child: InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets
                        .symmetric(
                      vertical: 3,
                    ),
                    child: Row(
                      children: [
                        // Draggable 핸들
                        Draggable<Task>(
                          data: st,
                          feedback:
                              _DragFeedback(
                            task: st,
                          ),
                          onDragStarted: () {
                            setState(() =>
                                _isDragging =
                                    true);
                            ref
                                .read(
                                    dragActiveProvider
                                        .notifier)
                                .state = true;
                          },
                          onDragEnd: (_) {
                            setState(() =>
                                _isDragging =
                                    false);
                            ref
                                .read(
                                    dragActiveProvider
                                        .notifier)
                                .state = false;
                          },
                          child: MouseRegion(
                            cursor:
                                SystemMouseCursors
                                    .grab,
                            child: Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              child: Icon(
                                Icons
                                    .drag_indicator,
                                size: 14,
                                color: theme
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget
                              .onToggleComplete,
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(2),
                            child: Icon(
                              st.status ==
                                      TaskStatus
                                          .completed
                                  ? Icons
                                      .check_circle
                                  : Icons
                                      .circle_outlined,
                              size: 14,
                              color: st.status ==
                                      TaskStatus
                                          .completed
                                  ? theme
                                      .colorScheme
                                      .primary
                                  : st.isDelayed
                                      ? Colors
                                          .red
                                      : theme
                                          .colorScheme
                                          .onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        if (st.isNew)
                          _NewBadge()
                        else if (st
                            .isRecentlyCompleted)
                          _DoneBadge(),
                        Expanded(
                          child: Text(
                            st.title,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              decoration: st
                                          .status ==
                                      TaskStatus
                                          .completed
                                  ? TextDecoration
                                      .lineThrough
                                  : null,
                              fontWeight: widget
                                      .highlighted
                                  ? FontWeight
                                      .w600
                                  : null,
                            ),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ),
                        if (st.assigneeName !=
                                null ||
                            st.creatorName !=
                                null ||
                            st.createdAt != null)
                          Text(
                            _formatSubMeta(st),
                            style: theme
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        if (st.plannedEnd !=
                            null) ...[
                          const SizedBox(
                            width: 4,
                          ),
                          Text(
                            '${st.plannedEnd!.month}/${st.plannedEnd!.day}',
                            style: theme
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color: st.isDelayed
                                  ? Colors.red
                                  : theme
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(
                          width: 4,
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 개별 연계 업무(하위 태스크) 행
class _SubTaskRow extends StatelessWidget {
  const _SubTaskRow({
    super.key,
    required this.st,
    required this.index,
    this.highlighted = false,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
    required this.onConfirmDismiss,
    required this.onToggleComplete,
  });

  final Task st;
  final int index;
  final bool highlighted;
  final VoidCallback onTap;
  final void Function(Offset) onLongPress;
  final VoidCallback onDismissed;
  final Future<bool?> Function()
      onConfirmDismiss;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        ResponsiveLayout.isMobile(context);

    return Dismissible(
      key: ValueKey('dismiss_sub_${st.id}'),
      direction:
          DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(
          right: AppSizes.md,
        ),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 16,
        ),
      ),
      confirmDismiss: (_) =>
          onConfirmDismiss(),
      onDismissed: (_) => onDismissed(),
      child: Container(
        decoration: highlighted
            ? BoxDecoration(
                color:
                    Colors.amber.shade50,
                borderRadius:
                    BorderRadius.circular(4),
              )
            : null,
        child: GestureDetector(
          onLongPressStart: (details) =>
              onLongPress(
                  details.globalPosition),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 3,
              ),
              child: Row(
                children: [
                  // PC: 드래그 핸들
                  if (!isMobile)
                    ReorderableDragStartListener(
                      index: index,
                      child: MouseRegion(
                        cursor:
                            SystemMouseCursors
                                .grab,
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Icon(
                            Icons
                                .drag_indicator,
                            size: 14,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(
                                    alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: onToggleComplete,
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                              2),
                      child: Icon(
                        st.status ==
                                TaskStatus
                                    .completed
                            ? Icons
                                .check_circle
                            : Icons
                                .circle_outlined,
                        size: 14,
                        color: st.status ==
                                TaskStatus
                                    .completed
                            ? theme.colorScheme
                                .primary
                            : st.isDelayed
                                ? Colors.red
                                : theme
                                    .colorScheme
                                    .onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (st.isNew)
                    _NewBadge()
                  else if (st.isRecentlyCompleted)
                    _DoneBadge(),
                  Expanded(
                    child: Text(
                      st.title,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        decoration: st.status ==
                                TaskStatus
                                    .completed
                            ? TextDecoration
                                .lineThrough
                            : null,
                        fontWeight: highlighted
                            ? FontWeight.w600
                            : null,
                      ),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                  if (st.assigneeName != null ||
                      st.creatorName != null ||
                      st.createdAt != null)
                    Text(
                      _formatSubMeta(st),
                      style: theme
                          .textTheme.labelSmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  if (st.plannedEnd !=
                      null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${st.plannedEnd!.month}/${st.plannedEnd!.day}',
                      style: theme
                          .textTheme.labelSmall
                          ?.copyWith(
                        color: st.isDelayed
                            ? Colors.red
                            : theme.colorScheme
                                .onSurfaceVariant,
                      ),
                    ),
                  ],
                  // 모바일: 리오더 핸들
                  if (isMobile)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding:
                            EdgeInsets.all(2),
                        child: Icon(
                          Icons
                              .drag_indicator,
                          size: 14,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 정렬 버튼
class _SortButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(taskSortProvider);
    return PopupMenuButton<TaskSort>(
      icon: const Icon(Icons.sort),
      tooltip: '정렬',
      onSelected: (sort) => ref
          .read(taskSortProvider.notifier)
          .state = sort,
      itemBuilder: (context) => TaskSort.values
          .map(
            (s) => PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  if (s == current)
                    const Icon(Icons.check,
                        size: 18)
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

/// NEW 배지 (빨간색 - 24시간 이내 생성)
class _NewBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 완료 배지 (초록색 - 24시간 이내 완료)
class _DoneBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        '완료',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 우선순위 점
class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
      ),
    );
  }

  Color get _color {
    switch (priority) {
      case TaskPriority.urgent:
        return AppColors.error;
      case TaskPriority.high:
        return AppColors.warning;
      case TaskPriority.medium:
        return AppColors.info;
      case TaskPriority.low:
        return AppColors.todo;
    }
  }
}

// ─── 드래그 앤 드롭 (PC) ───

/// PC 전용: DragTarget + 드래그 핸들 방식
class _DraggableTaskItem
    extends ConsumerStatefulWidget {
  const _DraggableTaskItem({
    required this.task,
    this.compact = false,
  });
  final Task task;
  final bool compact;

  @override
  ConsumerState<_DraggableTaskItem> createState() =>
      _DraggableTaskItemState();
}

class _DraggableTaskItemState
    extends ConsumerState<_DraggableTaskItem> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subTasksMap =
        ref.watch(subTasksMapProvider);
    final task = widget.task;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) {
        return _canAcceptDrop(
          details.data,
          task,
          subTasksMap,
        );
      },
      onAcceptWithDetails: (details) {
        _handleDrop(
          context,
          ref,
          details.data,
          task,
        );
      },
      builder: (
        context,
        candidateData,
        rejectedData,
      ) {
        final isAccepting =
            candidateData.isNotEmpty;
        final isRejecting =
            rejectedData.isNotEmpty;

        return AnimatedOpacity(
          opacity: _isDragging ? 0.3 : 1.0,
          duration: const Duration(
            milliseconds: 150,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // 드래그 핸들 (이 아이콘만 잡고 드래그)
              Draggable<Task>(
                data: task,
                feedback:
                    _DragFeedback(task: task),
                onDragStarted: () {
                  setState(
                    () => _isDragging = true,
                  );
                  ref
                      .read(dragActiveProvider
                          .notifier)
                      .state = true;
                },
                onDragEnd: (_) {
                  setState(
                    () => _isDragging = false,
                  );
                  ref
                      .read(dragActiveProvider
                          .notifier)
                      .state = false;
                },
                child: MouseRegion(
                  cursor:
                      SystemMouseCursors.grab,
                  child: Container(
                    width: 24,
                    alignment:
                        Alignment.center,
                    padding:
                        const EdgeInsets.only(
                      top: 14,
                      bottom: 14,
                      left: 2,
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: theme
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(
                              alpha: 0.35),
                    ),
                  ),
                ),
              ),
              // 태스크 타일
              Expanded(
                child: _TaskTile(
                  task: task,
                  compact: widget.compact,
                  highlighted: isAccepting ||
                      isRejecting,
                  highlightColor: isAccepting
                      ? AppColors.primary
                      : AppColors.error,
                  onMoveRequest: () =>
                      _showMoveSheet(
                    context,
                    ref,
                    task,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 독립 업무 드롭 영역 (PC 전용)
class _IndependentDropZone extends StatelessWidget {
  const _IndependentDropZone({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) {
        // 이미 독립 업무면 불필요
        return details.data.parentTaskId != null;
      },
      onAcceptWithDetails: (details) {
        final task = details.data;
        final oldParentId = task.parentTaskId;
        ref
            .read(allMyTasksProvider.notifier)
            .moveTask(
              task.id,
              newParentTaskId: null,
            );
        if (context.mounted) {
          _showUndoSnackBar(
            context,
            ref,
            task,
            oldParentId,
            '독립 업무로 변경됨',
          );
        }
      },
      builder: (
        context,
        candidateData,
        rejectedData,
      ) {
        final active =
            candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(
            milliseconds: 200,
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          padding: EdgeInsets.symmetric(
            vertical: active ? 12 : 6,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                    .withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
            borderRadius:
                BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : theme
                      .colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                active
                    ? Icons
                        .arrow_downward_rounded
                    : Icons.drag_indicator,
                size: 16,
                color: active
                    ? AppColors.primary
                    : theme.colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                active
                    ? '여기에 놓으면 독립 업무로 변경'
                    : '연계 업무를 여기로 드래그하여 '
                        '독립 업무로 분리',
                style: theme
                    .textTheme.labelSmall
                    ?.copyWith(
                  color: active
                      ? AppColors.primary
                      : theme.colorScheme
                          .onSurfaceVariant
                          .withValues(
                              alpha: 0.4),
                  fontWeight: active
                      ? FontWeight.bold
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 드래그 시 보여줄 피드백 위젯
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surface,
          borderRadius:
              BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.drag_indicator,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                task.title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 연계 업무 메타 표기 ───

/// 담당/등록자 + 등록 날짜를 한 줄로 합친다.
/// 예: "담당: 홍길동 · 3/15"
String _formatSubMeta(Task st) {
  final parts = <String>[];
  if (st.assigneeName != null) {
    parts.add('담당: ${st.assigneeName}');
  } else if (st.creatorName != null) {
    parts.add('등록: ${st.creatorName}');
  }
  if (st.createdAt != null) {
    final c = st.createdAt!;
    parts.add('${c.month}/${c.day}');
  }
  return parts.join(' · ');
}

// ─── 이동 헬퍼 함수 ───

/// 드롭 가능 여부 판단
bool _canAcceptDrop(
  Task dragged,
  Task target,
  Map<String, List<Task>> subTasksMap,
) {
  // 자기 자신 불가
  if (dragged.id == target.id) return false;
  // 대상이 이미 연계 업무면 불가 (최대 2단계)
  if (target.parentTaskId != null) return false;
  // 드래그 업무에 연계 업무가 있으면 불가
  // (3단계 방지)
  final dragSubs = subTasksMap[dragged.id];
  if (dragSubs != null && dragSubs.isNotEmpty) {
    return false;
  }
  // 이미 이 부모의 연계 업무면 불필요
  if (dragged.parentTaskId == target.id) {
    return false;
  }
  return true;
}

/// 드롭 처리
void _handleDrop(
  BuildContext context,
  WidgetRef ref,
  Task dragged,
  Task target,
) {
  final oldParentId = dragged.parentTaskId;
  ref
      .read(allMyTasksProvider.notifier)
      .moveTask(
        dragged.id,
        newParentTaskId: target.id,
      );
  if (context.mounted) {
    _showUndoSnackBar(
      context,
      ref,
      dragged,
      oldParentId,
      '"${target.title}"의 연계 업무로 이동',
    );
  }
}

/// 되돌리기 SnackBar
void _showUndoSnackBar(
  BuildContext context,
  WidgetRef ref,
  Task task,
  String? previousParentId,
  String message,
) {
  final bottomMargin = 0.0;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${task.title}: $message',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () {
            ref
                .read(
                    allMyTasksProvider.notifier)
                .moveTask(
                  task.id,
                  newParentTaskId:
                      previousParentId,
                );
          },
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          15,
          5,
          15,
          10 + bottomMargin,
        ),
        showCloseIcon: true,
        duration: const Duration(days: 365),
      ),
    );
}

// ─── 이동 BottomSheet ───

/// 이동 바텀시트 표시
void _showMoveSheet(
  BuildContext context,
  WidgetRef ref,
  Task task,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _MoveTaskSheet(
      task: task,
      parentRef: ref,
    ),
  );
}

/// 업무 이동 바텀시트
class _MoveTaskSheet extends ConsumerStatefulWidget {
  const _MoveTaskSheet({
    required this.task,
    required this.parentRef,
  });
  final Task task;
  final WidgetRef parentRef;

  @override
  ConsumerState<_MoveTaskSheet> createState() =>
      _MoveTaskSheetState();
}

class _MoveTaskSheetState
    extends ConsumerState<_MoveTaskSheet> {
  final _searchController =
      TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final tasksAsync =
        ref.watch(allMyTasksProvider);
    final subTasksMap =
        ref.watch(subTasksMapProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(
                top: 8,
              ),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme
                    .colorScheme.outlineVariant,
                borderRadius:
                    BorderRadius.circular(2),
              ),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.all(
                AppSizes.md,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '업무 이동',
                    style: theme
                        .textTheme.titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: AppSizes.xs,
                  ),
                  Text(
                    '"${task.title}"',
                    style: theme
                        .textTheme.bodyMedium
                        ?.copyWith(
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 독립 업무로 변경 버튼
            if (task.parentTaskId != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _doMove(null),
                    icon: const Icon(
                      Icons.call_split,
                      size: 18,
                    ),
                    label: const Text(
                      '독립 업무로 변경',
                    ),
                  ),
                ),
              ),
            if (task.parentTaskId != null)
              const SizedBox(
                height: AppSizes.sm,
              ),
            // 검색
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _query = v),
                decoration: InputDecoration(
                  hintText:
                      '연계할 부모 업무 검색...',
                  prefixIcon:
                      const Icon(Icons.search),
                  isDense: true,
                  suffixIcon:
                      _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController
                                    .clear();
                                setState(() =>
                                    _query = '');
                              },
                            )
                          : null,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
              ),
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  '아래 업무의 연계 업무로 등록:',
                  style: theme
                      .textTheme.labelMedium
                      ?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: AppSizes.xs,
            ),
            // 부모 후보 목록
            Expanded(
              child: tasksAsync.when(
                data: (allTasks) {
                  // 부모 후보: 최상위 + 본인 아님
                  // + 연계 업무 없음 (3단계 방지)
                  var candidates = allTasks
                      .where((t) {
                    if (t.id == task.id) {
                      return false;
                    }
                    if (t.parentTaskId !=
                        null) {
                      return false;
                    }
                    // 이미 이 부모면 제외
                    if (t.id ==
                        task.parentTaskId) {
                      return false;
                    }
                    // 대상이 본인의 연계 업무면
                    // 순환 방지
                    final subs =
                        subTasksMap[task.id];
                    if (subs != null &&
                        subs.any(
                          (s) => s.id == t.id,
                        )) {
                      return false;
                    }
                    return true;
                  }).toList();

                  // 검색 필터
                  if (_query.isNotEmpty) {
                    final q =
                        _query.toLowerCase();
                    candidates = candidates
                        .where(
                          (t) =>
                              t.title
                                  .toLowerCase()
                                  .contains(q) ||
                              (t.projectTitle
                                      ?.toLowerCase()
                                      .contains(
                                          q) ??
                                  false),
                        )
                        .toList();
                  }

                  if (candidates.isEmpty) {
                    return Center(
                      child: Text(
                        '이동 가능한 업무가 '
                        '없습니다',
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller:
                        scrollController,
                    itemCount:
                        candidates.length,
                    itemBuilder: (ctx, i) {
                      final t = candidates[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.task_outlined,
                          size: 20,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                        subtitle: Text(
                          t.belongsToLabel,
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                        ),
                        onTap: () =>
                            _doMove(t.id),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Text('오류: $e'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _doMove(String? newParentId) {
    final task = widget.task;
    final oldParentId = task.parentTaskId;

    widget.parentRef
        .read(allMyTasksProvider.notifier)
        .moveTask(
          task.id,
          newParentTaskId: newParentId,
        );

    Navigator.pop(context);

    final msg = newParentId == null
        ? '독립 업무로 변경됨'
        : '연계 업무로 이동됨';

    if (mounted) {
      _showUndoSnackBar(
        context,
        widget.parentRef,
        task,
        oldParentId,
        msg,
      );
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
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 64,
            color: theme
                .colorScheme.onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            '할 일이 없습니다',
            style: theme.textTheme.titleMedium
                ?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            '위 입력창에 할 일을 추가하거나\n'
            '+ 버튼으로 상세 업무를 만들어 보세요',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
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
