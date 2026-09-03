import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/supabase_config.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/file_attachment_section.dart';
import '../../domain/models/memo.dart';
import '../../providers/memo_provider.dart';

/// 메모 상세/편집 화면
class MemoDetailScreen extends ConsumerStatefulWidget {
  const MemoDetailScreen({
    super.key,
    this.memoId,
  });

  /// null이면 새 메모 생성 모드
  final String? memoId;

  @override
  ConsumerState<MemoDetailScreen> createState() =>
      _MemoDetailScreenState();
}

class _MemoDetailScreenState
    extends ConsumerState<MemoDetailScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _category;
  MemoPriority _priority = MemoPriority.none;
  bool _isPinned = false;
  bool _loaded = false;
  bool _saving = false;
  String? _createdMemoId;

  bool get _isCreate => widget.memoId == null;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _loadMemo(Memo memo) {
    if (_loaded) return;
    _titleController.text = memo.title;
    _contentController.text = memo.content;
    _category = memo.category;
    _priority = memo.priority;
    _isPinned = memo.isPinned;
    _loaded = true;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final userId =
          SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
        }
        return;
      }
      final memo = Memo(
        id: '',
        userId: userId,
        title: title,
        content: _contentController.text.trim(),
        category: _category,
        isPinned: _isPinned,
        priority: _priority,
      );

      if (_isCreate && _createdMemoId == null) {
        final created = await ref
            .read(myMemosProvider.notifier)
            .createMemo(memo);
        _createdMemoId = created.id;
        setState(() {});
      } else {
        final id =
            _createdMemoId ?? widget.memoId!;
        await ref
            .read(myMemosProvider.notifier)
            .updateMemo(id, memo);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 완료')),
        );
        if (_isCreate && _createdMemoId != null) {
          // 생성 후 편집 모드로 유지 (파일 첨부를 위해)
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 수정 모드: 기존 메모 로드
    if (!_isCreate) {
      final memoAsync = ref.watch(
          memoDetailProvider(widget.memoId!));
      return memoAsync.when(
        data: (memo) {
          _loadMemo(memo);
          return _buildScaffold(theme, memo.id);
        },
        loading: () => const Scaffold(
          body: Center(
              child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('오류: $e')),
        ),
      );
    }

    return _buildScaffold(
        theme, _createdMemoId);
  }

  Widget _buildScaffold(
      ThemeData theme, String? memoId) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate && _createdMemoId == null
            ? '새 메모'
            : '메모 편집'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: '저장',
              onPressed: _save,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // 제목
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '메모 제목을 입력하세요',
              ),
              style:
                  theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSizes.md),

            // 내용
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '메모 내용을 입력하세요...',
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 5,
            ),
            const SizedBox(height: AppSizes.md),

            // 카테고리 선택
            Text('카테고리',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              children: [
                _catChip('아이디어', Colors.purple),
                _catChip('메모', Colors.blue),
                _catChip('할일', Colors.orange),
                _catChip('기타', Colors.grey),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            // 우선순위
            Text('우선순위',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              children: MemoPriority.values.map((p) {
                return ChoiceChip(
                  label: Text(p.label),
                  selected: _priority == p,
                  onSelected: (_) => setState(
                      () => _priority = p),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSizes.md),

            // 고정 토글
            SwitchListTile(
              title: const Text('상단 고정'),
              secondary: const Icon(Icons.push_pin),
              value: _isPinned,
              onChanged: (v) =>
                  setState(() => _isPinned = v),
            ),

            // 첨부 파일 (저장 후에만 표시)
            if (memoId != null) ...[
              const SizedBox(height: AppSizes.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(
                      AppSizes.md),
                  child: FileAttachmentSection(
                    entityType: 'memo',
                    entityId: memoId,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _catChip(String label, Color color) {
    final selected = _category == label;
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.2),
      onSelected: (_) => setState(() {
        _category = selected ? null : label;
      }),
    );
  }
}
