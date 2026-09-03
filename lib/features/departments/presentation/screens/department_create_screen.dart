import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/department.dart';
import '../../providers/department_provider.dart';

/// 부서 생성/수정 화면
class DepartmentCreateScreen extends ConsumerStatefulWidget {
  const DepartmentCreateScreen({super.key, this.department});

  /// 수정 모드 시 기존 부서
  final Department? department;

  @override
  ConsumerState<DepartmentCreateScreen> createState() =>
      _DepartmentCreateScreenState();
}

class _DepartmentCreateScreenState
    extends ConsumerState<DepartmentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _color;
  bool _submitting = false;

  bool get _isEditing => widget.department != null;

  static const _colors = <String>[
    '#0ABAB5',
    '#4CAF50',
    '#FF9800',
    '#795548',
    '#9E9E9E',
    '#F44336',
    '#2196F3',
    '#9C27B0',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.department;
    _nameController = TextEditingController(text: d?.name ?? '');
    _descriptionController =
        TextEditingController(text: d?.description ?? '');
    _color = d?.color ?? _colors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final input = Department(
        id: widget.department?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        color: _color,
        sortOrder: widget.department?.sortOrder ?? 0,
      );

      final notifier = ref.read(departmentListProvider.notifier);
      if (_isEditing) {
        await notifier.updateDepartment(widget.department!.id, input);
      } else {
        await notifier.create(input);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditing ? '부서가 수정되었습니다' : '부서가 생성되었습니다')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '부서 수정' : '부서 추가'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '부서명',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '부서명을 입력하세요' : null,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSizes.lg),
            Text('색상', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: _colors.map((hex) {
                final selected = hex == _color;
                final c = Color(0xFF000000 |
                    int.parse(hex.replaceAll('#', ''), radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: theme.colorScheme.onSurface, width: 3)
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
