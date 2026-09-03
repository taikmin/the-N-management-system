import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/task.dart';
import '../../providers/task_provider.dart';

class TaskCreateScreen extends ConsumerStatefulWidget {
  const TaskCreateScreen({
    super.key,
    this.projectId,
    this.parentTaskId,
    this.task,
  });

  final String? projectId;
  final String? parentTaskId;
  final Task? task;

  @override
  ConsumerState<TaskCreateScreen> createState() =>
      _TaskCreateScreenState();
}

class _TaskCreateScreenState
    extends ConsumerState<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController
      _descriptionController;
  late final TextEditingController
      _categoryController;
  late TaskStatus _status;
  late TaskPriority _priority;
  late PlanType _planType;
  late ColorTag _colorTag;
  String? _selectedProjectId;
  String? _selectedAssigneeId;
  DateTime? _plannedStart;
  DateTime? _plannedEnd;
  bool _showInCalendar = false;
  bool _isLoading = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController =
        TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(
      text: t?.description ?? '',
    );
    _categoryController = TextEditingController(
      text: t?.category ?? '',
    );
    _status = t?.status ?? TaskStatus.planned;
    _priority = t?.priority ?? TaskPriority.medium;
    _planType = t?.planType ?? PlanType.a;
    _colorTag = t?.colorTag ?? ColorTag.none;
    _selectedProjectId =
        t?.projectId ?? widget.projectId;
    _selectedAssigneeId = t?.assigneeId;
    _plannedStart = t?.plannedStart;
    _plannedEnd = t?.plannedEnd;
    _showInCalendar = t?.showInCalendar ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final start = _plannedStart ?? now;
    final end = _plannedEnd ??
        start.add(const Duration(days: 1));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      initialDateRange: DateTimeRange(
        start: start,
        end: end,
      ),
      helpText: '계획 기간 선택',
      saveText: '확인',
      cancelText: '취소',
      fieldStartHintText: '시작일',
      fieldEndHintText: '종료일',
    );
    if (range != null) {
      setState(() {
        _plannedStart = range.start;
        _plannedEnd = range.end;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final task = Task(
        id: widget.task?.id ?? '',
        projectId: _selectedProjectId,
        parentTaskId: widget.parentTaskId ??
            widget.task?.parentTaskId,
        title: _titleController.text.trim(),
        description: _descriptionController.text
                .trim()
                .isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        status: _status,
        priority: _priority,
        planType: _planType,
        colorTag: _colorTag,
        showInCalendar: _showInCalendar,
        assigneeId: _selectedAssigneeId,
        plannedStart: _plannedStart,
        plannedEnd: _plannedEnd,
        category: _selectedProjectId == null
            ? (_categoryController.text
                    .trim()
                    .isNotEmpty
                ? _categoryController.text.trim()
                : null)
            : null,
      );

      if (_selectedProjectId != null) {
        final notifier = ref.read(
          projectTasksProvider(_selectedProjectId!)
              .notifier,
        );
        if (_isEditing) {
          await notifier.updateTask(
            widget.task!.id,
            task,
          );
        } else {
          await notifier.createTask(task);
        }
      } else {
        final notifier =
            ref.read(allMyTasksProvider.notifier);
        if (_isEditing) {
          await notifier.updateTask(
            widget.task!.id,
            task,
          );
        } else {
          await notifier.createTask(task);
        }
      }

      // 수정 후 상세 화면 데이터도 갱신
      if (_isEditing) {
        ref.invalidate(
          taskDetailProvider(widget.task!.id),
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectsAsync =
        ref.watch(projectsForDropdownProvider);
    final usersAsync =
        ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? '업무 수정' : '새 업무',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  if (widget.parentTaskId != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: AppSizes.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .subdirectory_arrow_right,
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '하위 태스크 생성',
                            style: theme.textTheme
                                .labelLarge
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 과제 선택 드롭다운
                  if (widget.projectId == null &&
                      widget.parentTaskId == null)
                    _buildProjectDropdown(
                      projectsAsync,
                      theme,
                    ),

                  // 카테고리 (독립 업무 시)
                  if (_selectedProjectId == null &&
                      widget.parentTaskId ==
                          null) ...[
                    const SizedBox(
                      height: AppSizes.md,
                    ),
                    TextFormField(
                      controller:
                          _categoryController,
                      decoration:
                          const InputDecoration(
                        labelText: '카테고리 (선택)',
                        prefixIcon: Icon(
                          Icons.label_outline,
                        ),
                        hintText: '예: 개인, 행정, 교육 등',
                      ),
                    ),
                  ],
                  const SizedBox(
                    height: AppSizes.md,
                  ),

                  // 제목
                  TextFormField(
                    controller: _titleController,
                    decoration:
                        const InputDecoration(
                      labelText: '업무명 *',
                      prefixIcon: Icon(
                        Icons.task_alt_outlined,
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty
                            ? '업무명을 입력해주세요'
                            : null,
                  ),
                  const SizedBox(
                    height: AppSizes.md,
                  ),

                  // 담당자 드롭다운
                  _buildAssigneeDropdown(
                    usersAsync,
                    theme,
                  ),
                  const SizedBox(
                    height: AppSizes.md,
                  ),

                  // 상태 + 우선순위 Row
                  Row(
                    children: [
                      Expanded(
                        child:
                            DropdownButtonFormField<
                                TaskStatus>(
                          initialValue: _status,
                          decoration:
                              const InputDecoration(
                            labelText: '상태',
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                            ),
                          ),
                          items: TaskStatus.values
                              .map(
                                (s) =>
                                    DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.label,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(
                                () => _status = v,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(
                        width: AppSizes.sm,
                      ),
                      Expanded(
                        child:
                            DropdownButtonFormField<
                                TaskPriority>(
                          initialValue: _priority,
                          decoration:
                              const InputDecoration(
                            labelText: '우선순위',
                            prefixIcon: Icon(
                              Icons.priority_high,
                            ),
                          ),
                          items: TaskPriority.values
                              .map(
                                (p) =>
                                    DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.label,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(
                                () =>
                                    _priority = v,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: AppSizes.md,
                  ),

                  // Plan 유형
                  Text(
                    'Plan 유형',
                    style:
                        theme.textTheme.labelLarge,
                  ),
                  const SizedBox(
                    height: AppSizes.xs,
                  ),
                  SegmentedButton<PlanType>(
                    segments: PlanType.values
                        .map(
                          (p) => ButtonSegment(
                            value: p,
                            label: Text(
                              'Plan ${p.value}',
                            ),
                          ),
                        )
                        .toList(),
                    selected: {_planType},
                    onSelectionChanged:
                        (selected) {
                      setState(
                        () => _planType =
                            selected.first,
                      );
                    },
                  ),
                  const SizedBox(
                    height: AppSizes.md,
                  ),

                  // 색상 태그
                  Text(
                    '색상 태그',
                    style:
                        theme.textTheme.labelLarge,
                  ),
                  const SizedBox(
                    height: AppSizes.xs,
                  ),
                  SegmentedButton<ColorTag>(
                    segments: ColorTag.values
                        .map(
                          (c) => ButtonSegment(
                            value: c,
                            label: Text(c.label),
                            icon: Icon(
                              Icons.circle,
                              color: _colorTagColor(c),
                              size: 14,
                            ),
                          ),
                        )
                        .toList(),
                    selected: {_colorTag},
                    onSelectionChanged:
                        (selected) {
                      setState(
                        () => _colorTag =
                            selected.first,
                      );
                    },
                  ),
                  const SizedBox(
                    height: AppSizes.md,
                  ),

                  // 계획 기간
                  _DateRangeField(
                    start: _plannedStart,
                    end: _plannedEnd,
                    onTap: _pickDate,
                    onClear: () {
                      setState(() {
                        _plannedStart = null;
                        _plannedEnd = null;
                        _showInCalendar = false;
                      });
                    },
                  ),

                  // 캘린더에 표시
                  CheckboxListTile(
                    value: _showInCalendar,
                    onChanged: (v) => setState(
                      () => _showInCalendar =
                          v ?? false,
                    ),
                    title: const Text(
                      '캘린더에 표시',
                    ),
                    secondary: Icon(
                      Icons.calendar_month,
                      color: _showInCalendar
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                          : null,
                    ),
                    dense: true,
                    contentPadding:
                        EdgeInsets.zero,
                  ),
                  const SizedBox(
                    height: AppSizes.sm,
                  ),

                  // 설명
                  TextFormField(
                    controller:
                        _descriptionController,
                    decoration:
                        const InputDecoration(
                      labelText: '설명',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(
                    height: AppSizes.xl,
                  ),

                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isEditing
                                ? '수정'
                                : '생성',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectDropdown(
    AsyncValue projectsAsync,
    ThemeData theme,
  ) {
    final projects =
        projectsAsync.valueOrNull ?? [];

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('과제 무관 (독립 업무)'),
      ),
      ...projects.map(
        (p) => DropdownMenuItem<String?>(
          value: p.id,
          child: Text(
            p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return DropdownButtonFormField<String?>(
      initialValue: _selectedProjectId,
      decoration: const InputDecoration(
        labelText: '소속 과제',
        prefixIcon:
            Icon(Icons.science_outlined),
      ),
      items: items,
      onChanged: (v) {
        setState(() => _selectedProjectId = v);
      },
      isExpanded: true,
    );
  }

  Widget _buildAssigneeDropdown(
    AsyncValue<List<Map<String, dynamic>>>
        usersAsync,
    ThemeData theme,
  ) {
    final users = usersAsync.valueOrNull ?? [];

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('미지정'),
      ),
      ...users.map(
        (u) => DropdownMenuItem<String?>(
          value: u['id'] as String,
          child: Text(
            _userLabel(u),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return DropdownButtonFormField<String?>(
      initialValue: _selectedAssigneeId,
      decoration: const InputDecoration(
        labelText: '담당자',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: items,
      onChanged: (v) {
        setState(() => _selectedAssigneeId = v);
      },
      isExpanded: true,
    );
  }

  Color _colorTagColor(ColorTag tag) {
    switch (tag) {
      case ColorTag.red:
        return Colors.red;
      case ColorTag.yellow:
        return Colors.amber;
      case ColorTag.blue:
        return Colors.blue;
      case ColorTag.none:
        return Colors.grey;
    }
  }

  String _userLabel(Map<String, dynamic> u) {
    final name =
        u['full_name'] as String? ?? '이름 없음';
    final dept = u['department'] as String?;
    if (dept != null && dept.isNotEmpty) {
      return '$name ($dept)';
    }
    return name;
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.start,
    required this.end,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasDate = start != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '계획 기간',
          prefixIcon: const Icon(
            Icons.date_range_outlined,
          ),
          suffixIcon: hasDate
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 18,
                  ),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          hasDate ? _rangeText() : '기간 선택',
          style: TextStyle(
            color: hasDate
                ? null
                : Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _rangeText() {
    final s = _fmt(start!);
    if (end != null && !_sameDay(start!, end!)) {
      return '$s ~ ${_fmt(end!)}';
    }
    return s;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String _fmt(DateTime d) =>
      '${d.year}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.day.toString().padLeft(2, '0')}';
}
