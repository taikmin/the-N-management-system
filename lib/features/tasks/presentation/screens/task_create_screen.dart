import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../departments/providers/department_provider.dart';
import '../../domain/models/task.dart';
import '../../providers/task_provider.dart';

/// 업무 지시 / 수정 화면 (관리급 전용)
class TaskCreateScreen extends ConsumerStatefulWidget {
  const TaskCreateScreen({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends ConsumerState<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  String? _departmentId;
  String? _assigneeId;
  TaskPriority _priority = TaskPriority.normal;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _showInCalendar = true;

  // 반복
  RecurrenceKind? _recurrenceKind;
  final Set<String> _weeklyDays = {};
  final TextEditingController _monthlyDaysController = TextEditingController();

  bool _submitting = false;
  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _categoryController = TextEditingController(text: t?.category ?? '');
    _departmentId = t?.departmentId;
    _assigneeId = t?.assigneeId;
    _priority = t?.priority ?? TaskPriority.normal;
    _dueDate = t?.dueDate;
    if (t?.dueTime != null) {
      final parts = t!.dueTime!.split(':');
      if (parts.length == 2) {
        _dueTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    _showInCalendar = t?.showInCalendar ?? true;
    final pattern = RecurrencePattern.tryParse(t?.recurrencePattern);
    if (pattern != null) {
      _recurrenceKind = pattern.kind;
      if (pattern.kind == RecurrenceKind.weekly) {
        _weeklyDays.addAll(pattern.args);
      } else if (pattern.kind == RecurrenceKind.monthly) {
        _monthlyDaysController.text = pattern.args.join(',');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _monthlyDaysController.dispose();
    super.dispose();
  }

  String? _encodeRecurrence() {
    if (_recurrenceKind == null) return null;
    switch (_recurrenceKind!) {
      case RecurrenceKind.daily:
        return 'daily';
      case RecurrenceKind.weekly:
        if (_weeklyDays.isEmpty) return null;
        final ordered = RecurrencePattern.weekDayCodes
            .where(_weeklyDays.contains)
            .toList();
        return 'weekly:${ordered.join(',')}';
      case RecurrenceKind.monthly:
        final days = _monthlyDaysController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (days.isEmpty) return null;
        return 'monthly:${days.join(',')}';
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    // 반복 업무면 due_date 불필요, 인스턴스가 매일 자동 생성됨
    final recurrence = _encodeRecurrence();

    final task = Task(
      id: widget.task?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      departmentId: _departmentId,
      assigneeId: _assigneeId,
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      priority: _priority,
      status: widget.task?.status ?? TaskStatus.assigned,
      dueDate: recurrence == null ? _dueDate : null,
      dueTime: _dueTime == null
          ? null
          : '${_dueTime!.hour.toString().padLeft(2, '0')}:'
              '${_dueTime!.minute.toString().padLeft(2, '0')}',
      showInCalendar: _showInCalendar,
      recurrencePattern: recurrence,
    );

    setState(() => _submitting = true);
    try {
      final notifier = ref.read(allMyTasksProvider.notifier);
      if (_isEditing) {
        await notifier.updateTask(widget.task!.id, task);
      } else {
        await notifier.createTask(task);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isEditing ? '업무가 수정되었습니다' : '업무가 지시되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final usersAsync = ref.watch(assignableUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '업무 수정' : '업무 지시'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                prefixIcon: Icon(Icons.task_alt_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '상세 설명 (선택)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSizes.md),

            // 부서
            departmentsAsync.when(
              data: (departments) => DropdownButtonFormField<String?>(
                initialValue: _departmentId,
                decoration: const InputDecoration(
                  labelText: '부서',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('(부서 없음)')),
                  ...departments.map((d) => DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(d.name),
                      )),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('부서 로딩 오류: $e'),
            ),
            const SizedBox(height: AppSizes.md),

            // 담당자
            usersAsync.when(
              data: (users) => DropdownButtonFormField<String?>(
                initialValue: _assigneeId,
                decoration: const InputDecoration(
                  labelText: '담당자',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('(미지정)')),
                  ...users.map((u) => DropdownMenuItem<String?>(
                        value: u['id'] as String,
                        child: Text(u['full_name'] as String? ?? '이름 없음'),
                      )),
                ],
                onChanged: (v) => setState(() => _assigneeId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('사용자 로딩 오류: $e'),
            ),
            const SizedBox(height: AppSizes.md),

            // 우선순위
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: '우선순위',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: TaskPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: AppSizes.md),

            // 카테고리
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: '카테고리 (선택, 자유 태그)',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: AppSizes.lg),

            // 반복 설정
            Text('반복', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.xs),
            Wrap(
              spacing: AppSizes.xs,
              children: [
                ChoiceChip(
                  label: const Text('일회성'),
                  selected: _recurrenceKind == null,
                  onSelected: (_) => setState(() => _recurrenceKind = null),
                ),
                ChoiceChip(
                  label: const Text('매일'),
                  selected: _recurrenceKind == RecurrenceKind.daily,
                  onSelected: (_) =>
                      setState(() => _recurrenceKind = RecurrenceKind.daily),
                ),
                ChoiceChip(
                  label: const Text('매주'),
                  selected: _recurrenceKind == RecurrenceKind.weekly,
                  onSelected: (_) =>
                      setState(() => _recurrenceKind = RecurrenceKind.weekly),
                ),
                ChoiceChip(
                  label: const Text('매월'),
                  selected: _recurrenceKind == RecurrenceKind.monthly,
                  onSelected: (_) =>
                      setState(() => _recurrenceKind = RecurrenceKind.monthly),
                ),
              ],
            ),
            if (_recurrenceKind == RecurrenceKind.weekly) ...[
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: 6,
                children: RecurrencePattern.weekDayCodes.map((code) {
                  final selected = _weeklyDays.contains(code);
                  return FilterChip(
                    label: Text(RecurrencePattern.weekDayLabels[code]!),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _weeklyDays.add(code);
                      } else {
                        _weeklyDays.remove(code);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
            if (_recurrenceKind == RecurrenceKind.monthly) ...[
              const SizedBox(height: AppSizes.sm),
              TextFormField(
                controller: _monthlyDaysController,
                decoration: const InputDecoration(
                  labelText: '매월 실행할 일자 (쉼표 구분, 예: 1,15)',
                  hintText: '1,15',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: AppSizes.lg),

            // 마감 (일회성일 때만 활성)
            if (_recurrenceKind == null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(_dueDate == null
                          ? '마감 날짜'
                          : '${_dueDate!.year}.${_dueDate!.month}.${_dueDate!.day}'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(_dueTime == null
                          ? '마감 시각 (선택)'
                          : _dueTime!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
            ],

            SwitchListTile(
              title: const Text('캘린더에 표시'),
              value: _showInCalendar,
              onChanged: (v) => setState(() => _showInCalendar = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
