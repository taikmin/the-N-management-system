import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../tasks/providers/task_provider.dart';
import '../../domain/models/project.dart';
import '../../providers/project_provider.dart';

class ProjectCreateScreen extends ConsumerStatefulWidget {
  const ProjectCreateScreen({super.key, this.project});

  /// 수정 모드일 때 기존 과제
  final Project? project;

  @override
  ConsumerState<ProjectCreateScreen> createState() =>
      _ProjectCreateScreenState();
}

class _ProjectCreateScreenState
    extends ConsumerState<ProjectCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _numberController;
  late final TextEditingController
      _descriptionController;
  late final TextEditingController _budgetController;
  late final TextEditingController _leadInstController;
  late final TextEditingController _coInstController;
  late ProjectStatus _status;
  String? _selectedOwnerId;
  String? _selectedAssigneeId;
  List<String> _selectedMemberIds = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showInCalendar = false;
  bool _isLoading = false;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _titleController =
        TextEditingController(text: p?.title ?? '');
    _numberController = TextEditingController(
        text: p?.projectNumber ?? '');
    _descriptionController = TextEditingController(
        text: p?.description ?? '');
    _budgetController = TextEditingController(
      text: p != null && p.totalBudget > 0
          ? p.totalBudget.toString()
          : '',
    );
    _leadInstController = TextEditingController(
        text: p?.leadInstitution ?? '한국기계연구원');
    _coInstController = TextEditingController(
        text: p?.coInstitutions.join(', ') ?? '');
    _status = p?.status ?? ProjectStatus.planning;
    _selectedOwnerId = p?.ownerId;
    _selectedAssigneeId = p?.assigneeId;
    _startDate = p?.startDate;
    _endDate = p?.endDate;
    _showInCalendar = p?.showInCalendar ?? false;

    // 수정 모드: 기존 멤버 로드
    if (_isEditing) {
      _loadExistingMembers();
    }
  }

  Future<void> _loadExistingMembers() async {
    try {
      final members = await ref
          .read(projectRepositoryProvider)
          .getProjectMembers(widget.project!.id);
      if (mounted) {
        setState(() {
          _selectedMemberIds = members
              .map((m) => m['user_id'] as String)
              .toList();
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _leadInstController.dispose();
    _coInstController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final start = _startDate ?? now;
    final end = _endDate ??
        start.add(const Duration(days: 1));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      initialDateRange: DateTimeRange(
        start: start,
        end: end,
      ),
      helpText: '수행기간 선택',
      saveText: '확인',
      cancelText: '취소',
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _showMemberPicker() async {
    final users =
        ref.read(allUsersProvider).valueOrNull ?? [];
    if (users.isEmpty) return;

    final selected =
        Set<String>.from(_selectedMemberIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('팀원 선택'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (ctx, index) {
                    final u = users[index];
                    final userId =
                        u['id'] as String;
                    final name = u['full_name']
                            as String? ??
                        '이름 없음';
                    final dept = u['department']
                        as String?;
                    final isSelected =
                        selected.contains(userId);
                    final isOwner = userId ==
                        _selectedOwnerId;

                    return CheckboxListTile(
                      value: isSelected || isOwner,
                      enabled: !isOwner,
                      title: Text(
                        dept != null &&
                                dept.isNotEmpty
                            ? '$name ($dept)'
                            : name,
                      ),
                      subtitle: isOwner
                          ? const Text('책임자')
                          : null,
                      onChanged: isOwner
                          ? null
                          : (v) {
                              setDialogState(() {
                                if (v == true) {
                                  selected
                                      .add(userId);
                                } else {
                                  selected.remove(
                                      userId);
                                }
                              });
                            },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, selected),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedMemberIds = result.toList();
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final user =
        ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final coInst = _coInstController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final budget = int.tryParse(_budgetController
              .text
              .replaceAll(RegExp(r'[^0-9]'), '')) ??
          0;

      final ownerId =
          _selectedOwnerId ?? user.id;

      final project = Project(
        id: widget.project?.id ?? '',
        title: _titleController.text.trim(),
        projectNumber: _numberController.text
                .trim()
                .isNotEmpty
            ? _numberController.text.trim()
            : null,
        description: _descriptionController.text
                .trim()
                .isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
        leadInstitution:
            _leadInstController.text.trim(),
        coInstitutions: coInst,
        totalBudget: budget,
        ownerId: ownerId,
        assigneeId: _selectedAssigneeId,
        showInCalendar: _showInCalendar,
      );

      if (_isEditing) {
        await ref
            .read(projectListProvider.notifier)
            .updateProject(
                widget.project!.id, project);
        // 팀원 갱신
        await ref
            .read(projectRepositoryProvider)
            .updateProjectMembers(
              widget.project!.id,
              ownerId,
              _selectedMemberIds,
            );
        ref.invalidate(projectMembersProvider(
            widget.project!.id));
      } else {
        final created = await ref
            .read(projectRepositoryProvider)
            .createProject(project);
        // 팀원 추가 (owner는 이미 추가됨)
        if (_selectedMemberIds.isNotEmpty) {
          await ref
              .read(projectRepositoryProvider)
              .updateProjectMembers(
                created.id,
                ownerId,
                _selectedMemberIds,
              );
        }
        ref.invalidate(projectListProvider);
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
    final usersAsync =
        ref.watch(allUsersProvider);
    final users =
        usersAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing ? '과제 수정' : '새 과제 생성'),
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
                  // 과제명
                  TextFormField(
                    controller: _titleController,
                    decoration:
                        const InputDecoration(
                      labelText: '과제명 *',
                      prefixIcon: Icon(
                          Icons.science_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty
                            ? '과제명을 입력해주세요'
                            : null,
                  ),
                  const SizedBox(
                      height: AppSizes.md),

                  // 과제번호
                  TextFormField(
                    controller: _numberController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          '과제번호 (예: 2026-R-001)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(
                      height: AppSizes.md),

                  // 상태
                  DropdownButtonFormField<
                      ProjectStatus>(
                    initialValue: _status,
                    decoration:
                        const InputDecoration(
                      labelText: '상태',
                      prefixIcon: Icon(
                          Icons.flag_outlined),
                    ),
                    items: ProjectStatus.values
                        .map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(
                            () => _status = v);
                      }
                    },
                  ),
                  const SizedBox(
                      height: AppSizes.md),

                  // 책임자 (PI) 드롭다운
                  _buildOwnerDropdown(
                      users, theme),
                  const SizedBox(
                      height: AppSizes.md),

                  // 담당자 드롭다운
                  _buildAssigneeDropdown(
                      users, theme),
                  const SizedBox(
                      height: AppSizes.md),

                  // 팀원 선택
                  _buildMembersSection(
                      users, theme),
                  const SizedBox(
                      height: AppSizes.md),

                  // 수행기간 (DateRangePicker)
                  _DateRangeField(
                    start: _startDate,
                    end: _endDate,
                    onTap: _pickDateRange,
                    onClear: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
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
                      height: AppSizes.sm),

                  // 총연구비
                  TextFormField(
                    controller: _budgetController,
                    decoration:
                        const InputDecoration(
                      labelText: '총연구비 (원)',
                      prefixIcon: Icon(
                          Icons.attach_money),
                    ),
                    keyboardType:
                        TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                    ],
                  ),
                  const SizedBox(
                      height: AppSizes.md),

                  // 주관기관
                  TextFormField(
                    controller:
                        _leadInstController,
                    decoration:
                        const InputDecoration(
                      labelText: '주관기관',
                      prefixIcon: Icon(Icons
                          .business_outlined),
                    ),
                  ),
                  const SizedBox(
                      height: AppSizes.md),

                  // 공동연구기관
                  TextFormField(
                    controller:
                        _coInstController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          '공동연구기관 (쉼표 구분)',
                      prefixIcon: Icon(
                          Icons.groups_outlined),
                      hintText:
                          '서울대학교, KAIST',
                    ),
                  ),
                  const SizedBox(
                      height: AppSizes.md),

                  // 과제 설명
                  TextFormField(
                    controller:
                        _descriptionController,
                    decoration:
                        const InputDecoration(
                      labelText: '과제 설명',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(
                      height: AppSizes.xl),

                  // 제출 버튼
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
                        : Text(_isEditing
                            ? '수정'
                            : '생성'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerDropdown(
    List<Map<String, dynamic>> users,
    ThemeData theme,
  ) {
    final items = users
        .map(
          (u) => DropdownMenuItem<String>(
            value: u['id'] as String,
            child: Text(
              _userLabel(u),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: _selectedOwnerId,
      decoration: const InputDecoration(
        labelText: '책임자 (PI)',
        prefixIcon:
            Icon(Icons.person_outline),
      ),
      items: items,
      onChanged: (v) {
        if (v != null) {
          setState(() {
            _selectedOwnerId = v;
            // owner는 자동으로 멤버에 포함
            if (!_selectedMemberIds
                .contains(v)) {
              _selectedMemberIds.add(v);
            }
          });
        }
      },
      isExpanded: true,
    );
  }

  Widget _buildAssigneeDropdown(
    List<Map<String, dynamic>> users,
    ThemeData theme,
  ) {
    final items = [
      const DropdownMenuItem<String>(
        value: '',
        child: Text('선택 안 함'),
      ),
      ...users.map(
        (u) => DropdownMenuItem<String>(
          value: u['id'] as String,
          child: Text(
            _userLabel(u),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return DropdownButtonFormField<String>(
      initialValue:
          _selectedAssigneeId ?? '',
      decoration: const InputDecoration(
        labelText: '담당자',
        prefixIcon: Icon(
          Icons.person_pin_outlined,
        ),
      ),
      items: items,
      onChanged: (v) {
        setState(() {
          _selectedAssigneeId =
              (v == null || v.isEmpty)
                  ? null
                  : v;
        });
      },
      isExpanded: true,
    );
  }

  Widget _buildMembersSection(
    List<Map<String, dynamic>> users,
    ThemeData theme,
  ) {
    final memberNames = _selectedMemberIds
        .where((id) => id != _selectedOwnerId)
        .map((id) {
      final user = users.firstWhere(
        (u) => u['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      return user.isNotEmpty
          ? _userLabel(user)
          : id;
    }).toList();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '팀원',
              style: theme.textTheme.labelLarge,
            ),
            TextButton.icon(
              onPressed: _showMemberPicker,
              icon: const Icon(Icons.add,
                  size: 18),
              label: const Text('선택'),
            ),
          ],
        ),
        if (memberNames.isEmpty)
          Text(
            '팀원을 선택해주세요',
            style:
                theme.textTheme.bodySmall?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSizes.xs,
            runSpacing: AppSizes.xs,
            children: memberNames
                .map((name) => Chip(
                      label: Text(
                        name,
                        style: theme
                            .textTheme.bodySmall,
                      ),
                      visualDensity:
                          VisualDensity.compact,
                    ))
                .toList(),
          ),
      ],
    );
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
          labelText: '수행기간',
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
