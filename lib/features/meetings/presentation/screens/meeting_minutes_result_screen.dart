import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../shared/utils/file_downloader.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../tasks/domain/models/task.dart';
import '../../../tasks/providers/task_provider.dart';
import '../../domain/models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/recording_provider.dart';

/// 회의록 결과 + 업무 등록 화면
class MeetingMinutesResultScreen
    extends ConsumerStatefulWidget {
  const MeetingMinutesResultScreen({
    super.key,
    this.meetingId,
  });

  final String? meetingId;

  @override
  ConsumerState<MeetingMinutesResultScreen>
      createState() =>
          _MeetingMinutesResultScreenState();
}

class _MeetingMinutesResultScreenState
    extends ConsumerState<
        MeetingMinutesResultScreen> {
  late TextEditingController _minutesController;
  late List<_TaskSelection> _taskSelections;
  String? _analysisNote;
  bool _isSaving = false;
  bool _isRegistering = false;
  bool _isRegenerating = false;
  bool _loadedFromMeeting = false;
  bool _projectsMatched = false;
  bool _assigneesMatched = false;
  bool _duplicatesChecked = false;

  bool get _isStandalone =>
      widget.meetingId == null;

  @override
  void initState() {
    super.initState();
    final state = ref.read(recordingProvider);
    final result = state.minutesResult;

    if (result != null) {
      _minutesController =
          TextEditingController(
        text: result.minutes,
      );
      _taskSelections = result.tasks
          .map(
            (t) => _TaskSelection(
              task: t,
              selected: true,
            ),
          )
          .toList();
      _analysisNote = result.analysisNote;
    } else {
      _minutesController =
          TextEditingController();
      _taskSelections = [];
      _loadedFromMeeting = true;
    }
  }

  /// 클라이언트 측 중복 체크
  void _checkDuplicates(List<Task> existingTasks) {
    if (_duplicatesChecked) return;
    _duplicatesChecked = true;

    for (final sel in _taskSelections) {
      final title =
          (sel.overrideTitle ?? sel.task.title)
              .trim();
      if (title.isEmpty) continue;

      String? bestMatch;
      double bestScore = 0;

      for (final existing in existingTasks) {
        final score = _titleSimilarity(
          title,
          existing.title,
        );
        if (score > bestScore) {
          bestScore = score;
          bestMatch = existing.title;
        }
      }

      if (bestScore >= 0.8 && bestMatch != null) {
        sel.similarExistingTask = bestMatch;
        sel.selected = false; // 중복 의심 → 기본 해제
      }
    }
  }

  /// 제목 유사도 계산 (bigram 기반)
  double _titleSimilarity(String a, String b) {
    final aNorm = a.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          '',
        );
    final bNorm = b.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          '',
        );

    if (aNorm == bNorm) return 1.0;
    if (aNorm.length < 2 || bNorm.length < 2) {
      return 0.0;
    }

    final aBigrams = <String>{};
    for (var i = 0; i < aNorm.length - 1; i++) {
      aBigrams.add(aNorm.substring(i, i + 2));
    }
    final bBigrams = <String>{};
    for (var i = 0; i < bNorm.length - 1; i++) {
      bBigrams.add(bNorm.substring(i, i + 2));
    }

    final intersection =
        aBigrams.intersection(bBigrams).length;
    final union = aBigrams.union(bBigrams).length;

    return union > 0 ? intersection / union : 0.0;
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  /// 재작성 버튼 위젯
  Widget _buildRegenerateButton(
    Meeting? meeting,
  ) {
    // 원본 텍스트가 있는지 확인
    final recording =
        ref.read(recordingProvider);
    final hasTranscript =
        recording.fullTranscript.trim().isNotEmpty ||
            (meeting?.rawTranscript != null &&
                meeting!
                    .rawTranscript!.isNotEmpty);

    if (!hasTranscript) {
      return const SizedBox.shrink();
    }

    if (_isRegenerating) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: () => _regenerateMinutes(
        meeting,
      ),
      icon: const Icon(
        Icons.refresh,
        size: 18,
      ),
      label: const Text('재작성'),
    );
  }

  /// AI 재작성 실행
  Future<void> _regenerateMinutes(
    Meeting? meeting,
  ) async {
    setState(() => _isRegenerating = true);

    try {
      final recording =
          ref.read(recordingProvider);
      final notifier =
          ref.read(recordingProvider.notifier);

      // 원본 텍스트: recording state 우선,
      // 없으면 meeting DB에서
      final transcript =
          recording.fullTranscript.trim().isNotEmpty
              ? recording.fullTranscript
              : meeting?.rawTranscript ?? '';

      if (transcript.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                '원본 녹음 텍스트가 없어 '
                '재작성할 수 없습니다.',
              ),
            ),
          );
        }
        return;
      }

      final dt = meeting?.meetingDate ??
          DateTime.now();
      final dateStr = '${dt.year}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.day.toString().padLeft(2, '0')}';

      await notifier.regenerateMinutes(
        rawTranscript: transcript,
        meetingId: widget.meetingId,
        meetingTitle: meeting?.title,
        meetingDate: dateStr,
        projectTitle: meeting?.projectTitle,
      );

      if (!mounted) return;
      final newState = ref.read(recordingProvider);
      if (newState.minutesResult != null) {
        final result = newState.minutesResult!;
        setState(() {
          _minutesController.text =
              result.minutes;
          _taskSelections = result.tasks
              .map(
                (t) => _TaskSelection(
                  task: t,
                  selected: true,
                ),
              )
              .toList();
          _analysisNote = result.analysisNote;
          _projectsMatched = false;
          _assigneesMatched = false;
          _duplicatesChecked = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                '회의록이 재작성되었습니다.',
              ),
            ),
          );
        }
      } else if (newState.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                newState.error!,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'AI 재작성 실패: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isRegenerating = false,
        );
      }
    }
  }

  /// AI project_title → project_id 초기 매칭
  void _matchProjects(
    List<Project> projects,
    Meeting? meeting,
  ) {
    if (_projectsMatched) return;
    _projectsMatched = true;

    for (final sel in _taskSelections) {
      // AI가 매칭한 프로젝트 확인
      if (sel.task.projectTitle != null) {
        final match = projects
            .where(
              (p) =>
                  p.title ==
                  sel.task.projectTitle,
            )
            .firstOrNull;
        if (match != null) {
          sel.overrideProjectId = match.id;
          continue;
        }
      }
      // AI 매칭 실패 → 회의 소속 프로젝트 사용
      if (meeting?.projectId != null) {
        sel.overrideProjectId =
            meeting!.projectId;
      }
    }
  }

  /// AI assigneeName → profiles.id 자동 매칭
  void _matchAssignees(
    List<Map<String, dynamic>> users,
  ) {
    if (_assigneesMatched) return;
    _assigneesMatched = true;

    for (final sel in _taskSelections) {
      if (sel.overrideAssigneeId != null) continue;
      final name = sel.task.assigneeName;
      if (name == null || name.isEmpty) continue;

      // full_name 완전 일치 검색
      final match = users
          .where(
            (u) =>
                (u['full_name'] as String?)
                    ?.trim() ==
                name.trim(),
          )
          .firstOrNull;
      if (match != null) {
        sel.overrideAssigneeId =
            match['id'] as String;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 프로젝트 목록 (드롭다운용)
    final projectsAsync =
        ref.watch(projectListProvider);
    final projects =
        projectsAsync.valueOrNull ?? [];

    // 사용자 목록 (담당자 자동 매칭용)
    final usersAsync =
        ref.watch(allUsersProvider);
    final users = usersAsync.valueOrNull;
    if (users != null && !_assigneesMatched) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _matchAssignees(users);
          });
        }
      });
    }

    // 기존 업무 중복 체크
    final allTasksAsync =
        ref.watch(allMyTasksProvider);
    final allTasks =
        allTasksAsync.valueOrNull ?? [];
    if (allTasks.isNotEmpty &&
        !_duplicatesChecked &&
        _taskSelections.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _checkDuplicates(allTasks);
          });
        }
      });
    }

    if (_isStandalone) {
      _matchProjects(projects, null);
      return Scaffold(
        appBar: AppBar(
          title: const Text('회의록 결과'),
          actions: [
            _buildRegenerateButton(null),
          ],
        ),
        body: _buildScrollBody(
          context,
          null,
          projects,
          theme,
        ),
        bottomNavigationBar: _buildBottomBar(
          null,
          theme,
        ),
      );
    }

    final meetingAsync = ref.watch(
      meetingDetailProvider(widget.meetingId!),
    );

    return meetingAsync.when(
      data: (meeting) {
        _matchProjects(projects, meeting);

        if (_loadedFromMeeting &&
            _minutesController.text.isEmpty &&
            meeting.meetingNotes != null) {
          _loadedFromMeeting = false;
          WidgetsBinding.instance
              .addPostFrameCallback((_) {
            if (mounted) {
              _minutesController.text =
                  meeting.meetingNotes!;
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('회의록 결과'),
            actions: [
              _buildRegenerateButton(meeting),
            ],
          ),
          body: _buildScrollBody(
            context,
            meeting,
            projects,
            theme,
          ),
          bottomNavigationBar: _buildBottomBar(
            meeting,
            theme,
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('회의록 결과'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('회의록 결과'),
        ),
        body: Center(child: Text('오류: $e')),
      ),
    );
  }

  Widget _buildTaskSectionHeader(ThemeData theme) {
    final selected = _taskSelections
        .where((t) => t.selected)
        .length;
    final total = _taskSelections.length;
    final duplicates = _taskSelections
        .where((t) => t.isDuplicate)
        .length;
    final newCount = total - duplicates;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '추출된 업무 ($selected/$total)',
          icon: Icons.task_alt,
          theme: theme,
        ),
        if (duplicates > 0)
          Padding(
            padding: const EdgeInsets.only(
              top: 4,
              left: 28,
            ),
            child: Text(
              '신규 $newCount건 / '
              '중복 의심 $duplicates건',
              style: theme.textTheme.labelSmall
                  ?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScrollBody(
    BuildContext context,
    Meeting? meeting,
    List<Project> projects,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // AI 분석 안내 메시지
          if (_analysisNote != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(
                bottom: AppSizes.sm,
              ),
              padding: const EdgeInsets.all(
                AppSizes.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning
                    .withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _analysisNote!,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 회의록 섹션
          _SectionHeader(
            title: '회의록',
            icon: Icons.description_outlined,
            theme: theme,
          ),
          const SizedBox(height: AppSizes.xs),
          TextField(
            controller: _minutesController,
            maxLines: null,
            minLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '회의록 내용...',
            ),
          ),

          const SizedBox(height: AppSizes.lg),

          // 추출된 업무 섹션
          _buildTaskSectionHeader(theme),
          const SizedBox(height: AppSizes.xs),

          if (_taskSelections.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(
                  AppSizes.lg,
                ),
                child: Center(
                  child: Text(
                    _loadedFromMeeting
                        ? '저장된 회의록입니다 '
                            '(추출된 업무 없음)'
                        : 'AI가 추출한 업무가 '
                            '없습니다',
                    style: theme
                        .textTheme.bodyMedium
                        ?.copyWith(
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            ..._taskSelections
                .asMap()
                .entries
                .map(
                  (e) => _TaskCard(
                    key: ValueKey(
                      '${e.key}_'
                      '${e.value.overrideAssigneeId}'
                      '_${e.value.overrideProjectId}'
                      '_${e.value.overrideParentTaskId}'
                      '_${e.value.isDuplicate}',
                    ),
                    index: e.key,
                    selection: e.value,
                    projects: projects,
                    onChanged: (val) {
                      setState(() {
                        e.value.selected =
                            val ?? true;
                      });
                    },
                    onTitleChanged: (val) {
                      e.value.overrideTitle =
                          val;
                    },
                    onDescriptionChanged:
                        (val) {
                      e.value
                              .overrideDescription =
                          val;
                    },
                    onAssigneeChanged: (val) {
                      setState(() {
                        e.value
                                .overrideAssigneeId =
                            val;
                      });
                    },
                    onDeadlineChanged: (val) {
                      setState(() {
                        e.value
                                .overrideDeadline =
                            val;
                      });
                    },
                    onProjectChanged: (val) {
                      setState(() {
                        e.value
                                .overrideProjectId =
                            val;
                        // 프로젝트 변경 시 부모 업무 초기화
                        e.value
                                .overrideParentTaskId =
                            null;
                      });
                    },
                    onSubTaskToggled: (val) {
                      setState(() {
                        e.value.asSubTask = val;
                        if (!val) {
                          e.value
                                  .overrideParentTaskId =
                              null;
                        }
                      });
                    },
                    onParentTaskChanged: (val) {
                      setState(() {
                        e.value
                                .overrideParentTaskId =
                            val;
                      });
                    },
                    theme: theme,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    Meeting? meeting,
    ThemeData theme,
  ) {
    final selectedCount = _taskSelections
        .where((t) => t.selected)
        .length;

    return Container(
      padding:
          const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: theme
            .colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme
                .colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _downloadMarkdown(
                      meeting,
                    ),
                    icon: const Icon(
                      Icons.download,
                      size: 18,
                    ),
                    label:
                        const Text('다운로드'),
                  ),
                ),
                const SizedBox(
                  width: AppSizes.sm,
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _saveMinutes(
                              meeting,
                            ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save,
                            size: 18,
                          ),
                    label: Text(
                      _isSaving
                          ? '저장 중...'
                          : '저장',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRegistering ||
                        selectedCount == 0
                    ? null
                    : () => _registerTasks(
                          meeting,
                        ),
                icon: _isRegistering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons
                            .playlist_add_check,
                      ),
                label: Text(
                  _isRegistering
                      ? '등록 중...'
                      : '선택 업무 등록 '
                          '($selectedCount건)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMinutes(
    Meeting? meeting,
  ) async {
    setState(() => _isSaving = true);

    try {
      final recording =
          ref.read(recordingProvider);
      String targetMeetingId;

      if (widget.meetingId != null) {
        targetMeetingId = widget.meetingId!;
      } else {
        final userId = SupabaseConfig
            .auth.currentUser?.id;
        if (userId == null) {
          throw Exception('로그인이 필요합니다');
        }

        final now = DateTime.now();
        final autoTitle = '업무점검 회의 '
            '(${now.year}.'
            '${now.month.toString().padLeft(2, '0')}.'
            '${now.day.toString().padLeft(2, '0')})';

        final newMeeting = await ref
            .read(
                meetingListProvider.notifier)
            .createMeeting(
              Meeting(
                id: '',
                title: autoTitle,
                meetingDate: now,
                status:
                    MeetingStatus.completed,
                creatorId: userId,
              ),
            );
        targetMeetingId = newMeeting.id;
      }

      await ref
          .read(meetingRepositoryProvider)
          .saveMeetingNotes(
            targetMeetingId,
            meetingNotes: _minutesController
                .text
                .trim(),
            rawTranscript: recording
                    .fullTranscript.isEmpty
                ? null
                : recording.fullTranscript,
          );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('회의록이 저장되었습니다'),
          ),
        );
        if (widget.meetingId != null) {
          ref.invalidate(
            meetingDetailProvider(
              widget.meetingId!,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _downloadMarkdown(
    Meeting? meeting,
  ) async {
    if (!kIsWeb) return;

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final title = meeting?.title ??
        '업무점검 회의 ($dateStr)';

    final buf = StringBuffer();
    buf.writeln('# $title');
    buf.writeln();
    buf.writeln('- 일시: $dateStr');
    if (meeting?.location != null) {
      buf.writeln(
        '- 장소: ${meeting!.location}',
      );
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.writeln('## 회의록');
    buf.writeln();
    buf.writeln(
      _minutesController.text.trim(),
    );
    buf.writeln();

    final selected = _taskSelections
        .where((t) => t.selected)
        .toList();
    if (selected.isNotEmpty) {
      buf.writeln('---');
      buf.writeln();
      buf.writeln(
        '## 추출된 업무 '
        '(${selected.length}건)',
      );
      buf.writeln();
      for (var i = 0;
          i < selected.length;
          i++) {
        final sel = selected[i];
        final et = sel.task;
        final taskTitle =
            sel.overrideTitle ?? et.title;
        final taskDesc =
            sel.overrideDescription ??
                et.description;
        buf.writeln(
          '### ${i + 1}. $taskTitle',
        );
        if (taskDesc != null &&
            taskDesc.isNotEmpty) {
          buf.writeln('- 설명: $taskDesc');
        }
        buf.writeln(
          '- 우선순위: '
          '${TaskPriority.fromString(et.priority).label}',
        );
        if (et.assigneeName != null) {
          buf.writeln(
            '- 담당자: ${et.assigneeName}',
          );
        }
        if (et.projectTitle != null) {
          buf.writeln(
            '- 프로젝트: ${et.projectTitle}',
          );
        }
        final deadline =
            sel.overrideDeadline != null
                ? '${sel.overrideDeadline!.year}-${sel.overrideDeadline!.month.toString().padLeft(2, '0')}-${sel.overrideDeadline!.day.toString().padLeft(2, '0')}'
                : et.deadline;
        if (deadline != null) {
          buf.writeln('- 마감일: $deadline');
        }
        buf.writeln();
      }
    }

    final bytes = utf8.encode(buf.toString());
    final fileName =
        '회의록_${dateStr}_$title.md'
            .replaceAll(
      RegExp(r'[/\\:*?"<>|]'),
      '_',
    );

    try {
      await saveFileToDevice(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('파일이 다운로드되었습니다'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text('다운로드 실패: $e'),
          ),
        );
      }
    }
  }

  Future<void> _registerTasks(
    Meeting? meeting,
  ) async {
    final selected = _taskSelections
        .where((t) => t.selected)
        .toList();
    if (selected.isEmpty) return;

    setState(() => _isRegistering = true);

    try {
      final userId = SupabaseConfig
          .auth.currentUser?.id;

      final now = DateTime.now();
      final meetingLabel = meeting?.title ??
          '업무점검 회의 '
              '(${now.year}.'
              '${now.month.toString().padLeft(2, '0')}.'
              '${now.day.toString().padLeft(2, '0')})';

      final tasks = selected.map((sel) {
        final et = sel.task;
        DateTime? deadline;
        if (sel.overrideDeadline != null) {
          deadline = sel.overrideDeadline;
        } else if (et.deadline != null) {
          deadline = DateTime.tryParse(
            et.deadline!,
          );
        }

        // 프로젝트: 개별 업무 드롭다운 > 회의 소속
        final projId =
            sel.overrideProjectId ??
                meeting?.projectId;

        return Task(
          id: '',
          projectId: projId,
          parentTaskId: sel.asSubTask
              ? sel.overrideParentTaskId
              : null,
          title:
              sel.overrideTitle ?? et.title,
          description:
              sel.overrideDescription ??
                  et.description ??
                  '회의 "$meetingLabel"에서 '
                      '도출된 업무',
          status: TaskStatus.planned,
          priority: TaskPriority.fromString(
            et.priority,
          ),
          assigneeId:
              sel.overrideAssigneeId ??
                  userId,
          createdBy: userId,
          plannedStart: deadline,
          plannedEnd: deadline,
        );
      }).toList();

      await ref
          .read(allMyTasksProvider.notifier)
          .createTasks(tasks);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              '${tasks.length}건의 업무가 '
              '등록되었습니다',
            ),
          ),
        );
        ref
            .read(
                recordingProvider.notifier)
            .reset();
        if (_isStandalone) {
          context.go('/tasks');
        } else {
          context.go(
            '/meetings/${widget.meetingId}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              '업무 등록 실패: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isRegistering = false,
        );
      }
    }
  }
}

// ─── Helper Models ───

class _TaskSelection {
  _TaskSelection({
    required this.task,
    this.selected = true,
  });

  final ExtractedTask task;
  bool selected;
  String? overrideTitle;
  String? overrideDescription;
  String? overrideAssigneeId;
  DateTime? overrideDeadline;
  String? overrideProjectId;
  String? overrideParentTaskId;
  bool asSubTask = false;

  /// 유사한 기존 업무 제목 (중복 감지 시)
  String? similarExistingTask;

  bool get isDuplicate =>
      similarExistingTask != null;
}

// ─── Widgets ───

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.theme,
  });
  final String title;
  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    super.key,
    required this.index,
    required this.selection,
    required this.projects,
    required this.onChanged,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onAssigneeChanged,
    required this.onDeadlineChanged,
    required this.onProjectChanged,
    required this.onSubTaskToggled,
    required this.onParentTaskChanged,
    required this.theme,
  });

  final int index;
  final _TaskSelection selection;
  final List<Project> projects;
  final ValueChanged<bool?> onChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String>
      onDescriptionChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final ValueChanged<DateTime?>
      onDeadlineChanged;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<bool> onSubTaskToggled;
  final ValueChanged<String?>
      onParentTaskChanged;
  final ThemeData theme;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final task = selection.task;
    final usersAsync =
        ref.watch(allUsersProvider);

    final priorityColor =
        switch (task.priority) {
      'urgent' => AppColors.error,
      'high' => AppColors.warning,
      'medium' => AppColors.info,
      _ => AppColors.done,
    };

    return Card(
      margin: const EdgeInsets.only(
        bottom: AppSizes.sm,
      ),
      color: selection.isDuplicate
          ? theme.colorScheme.surfaceContainerHigh
          : null,
      child: Padding(
        padding:
            const EdgeInsets.all(AppSizes.sm),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selection.selected,
              onChanged: onChanged,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // 중복 경고
                  if (selection.isDuplicate)
                    Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(
                        bottom: 4,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning
                            .withValues(
                          alpha: 0.1,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          4,
                        ),
                      ),
                      child: Text(
                        '기존 유사: '
                        '${selection.similarExistingTask}',
                        style: theme
                            .textTheme.labelSmall
                            ?.copyWith(
                          color:
                              AppColors.warning,
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),

                  // 제목 + 우선순위
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: selection
                                  .overrideTitle ??
                              task.title,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w600,
                            decoration: selection
                                    .selected
                                ? null
                                : TextDecoration
                                    .lineThrough,
                            color: selection
                                    .selected
                                ? null
                                : theme
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          decoration:
                              const InputDecoration(
                            isDense: true,
                            contentPadding:
                                EdgeInsets
                                    .symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            border: InputBorder
                                .none,
                          ),
                          onChanged:
                              onTitleChanged,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color: priorityColor
                              .withValues(
                            alpha: 0.15,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(4),
                        ),
                        child: Text(
                          TaskPriority
                              .fromString(
                            task.priority,
                          ).label,
                          style: theme
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color:
                                priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 설명
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: selection
                            .overrideDescription ??
                        task.description ??
                        '',
                    style: theme
                        .textTheme.bodySmall
                        ?.copyWith(
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                    decoration:
                        const InputDecoration(
                      isDense: true,
                      hintText: '설명 추가...',
                      contentPadding:
                          EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      border:
                          InputBorder.none,
                    ),
                    maxLines: 2,
                    onChanged:
                        onDescriptionChanged,
                  ),

                  const SizedBox(
                    height: AppSizes.xs,
                  ),

                  // 프로젝트 드롭다운
                  DropdownButtonFormField<
                      String>(
                    isExpanded: true,
                    isDense: true,
                    decoration:
                        const InputDecoration(
                      labelText: '프로젝트',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    initialValue:
                        selection
                            .overrideProjectId,
                    items: [
                      const DropdownMenuItem<
                          String>(
                        value: null,
                        child: Text(
                          '독립 업무 '
                          '(프로젝트 없음)',
                        ),
                      ),
                      ...projects.map(
                        (p) =>
                            DropdownMenuItem<
                                String>(
                          value: p.id,
                          child: Text(
                            p.title,
                            style: theme
                                .textTheme
                                .bodySmall,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged:
                        onProjectChanged,
                  ),

                  const SizedBox(
                    height: AppSizes.xs,
                  ),

                  // 연계 업무 토글 + 부모 업무 선택
                  _SubTaskSection(
                    selection: selection,
                    onSubTaskToggled:
                        onSubTaskToggled,
                    onParentTaskChanged:
                        onParentTaskChanged,
                    theme: theme,
                  ),

                  const SizedBox(
                    height: AppSizes.xs,
                  ),

                  // 담당자 + 마감일
                  Row(
                    children: [
                      Expanded(
                        child:
                            usersAsync.when(
                          data: (users) {
                            return DropdownButtonFormField<
                                String>(
                              isExpanded: true,
                              isDense: true,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    '담당자',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      8,
                                  vertical: 8,
                                ),
                              ),
                              initialValue: selection
                                          .overrideAssigneeId !=
                                      null
                                  ? users.any(
                                      (u) =>
                                          u['id'] ==
                                          selection
                                              .overrideAssigneeId,
                                    )
                                      ? selection
                                          .overrideAssigneeId
                                      : null
                                  : null,
                              hint: Text(
                                task.assigneeName ??
                                    '미지정',
                                style: theme
                                    .textTheme
                                    .bodySmall,
                              ),
                              items: users
                                  .map(
                                    (u) =>
                                        DropdownMenuItem(
                                      value: u[
                                              'id']
                                          as String,
                                      child:
                                          Text(
                                        u['full_name']
                                                as String? ??
                                            '',
                                        style: theme
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  onAssigneeChanged,
                            );
                          },
                          loading: () =>
                              const LinearProgressIndicator(),
                          error: (_, _) =>
                              const SizedBox(),
                        ),
                      ),
                      const SizedBox(
                        width: AppSizes.xs,
                      ),
                      SizedBox(
                        width: 140,
                        child: InkWell(
                          onTap: () async {
                            final picked =
                                await showDatePicker(
                              context: context,
                              initialDate: selection
                                      .overrideDeadline ??
                                  (task.deadline !=
                                          null
                                      ? DateTime
                                          .tryParse(
                                          task
                                              .deadline!,
                                        )
                                      : null) ??
                                  DateTime.now()
                                      .add(
                                    const Duration(
                                      days: 7,
                                    ),
                                  ),
                              firstDate:
                                  DateTime
                                      .now(),
                              lastDate:
                                  DateTime.now()
                                      .add(
                                const Duration(
                                  days: 365,
                                ),
                              ),
                            );
                            if (picked !=
                                null) {
                              onDeadlineChanged(
                                picked,
                              );
                            }
                          },
                          child:
                              InputDecorator(
                            decoration:
                                const InputDecoration(
                              labelText:
                                  '마감일',
                              isDense: true,
                              contentPadding:
                                  EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              suffixIcon:
                                  Icon(
                                Icons
                                    .calendar_today,
                                size: 16,
                              ),
                            ),
                            child: Text(
                              _formatDeadline(
                                selection,
                              ),
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
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

  String _formatDeadline(
    _TaskSelection sel,
  ) {
    if (sel.overrideDeadline != null) {
      final d = sel.overrideDeadline!;
      return '${d.month}/${d.day}';
    }
    if (sel.task.deadline != null) {
      return sel.task.deadline!;
    }
    return '미정';
  }
}

/// 연계 업무(서브태스크) 토글 + 부모 업무 선택
class _SubTaskSection extends ConsumerWidget {
  const _SubTaskSection({
    required this.selection,
    required this.onSubTaskToggled,
    required this.onParentTaskChanged,
    required this.theme,
  });

  final _TaskSelection selection;
  final ValueChanged<bool> onSubTaskToggled;
  final ValueChanged<String?>
      onParentTaskChanged;
  final ThemeData theme;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // 토글
        Row(
          children: [
            SizedBox(
              height: 28,
              width: 28,
              child: Checkbox(
                value: selection.asSubTask,
                onChanged: (val) =>
                    onSubTaskToggled(val ?? false),
                visualDensity:
                    VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '연계 업무로 등록',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),

        // 부모 업무 드롭다운
        if (selection.asSubTask)
          _ParentTaskDropdown(
            selection: selection,
            onParentTaskChanged:
                onParentTaskChanged,
            theme: theme,
          ),
      ],
    );
  }
}

/// 부모 업무 선택 드롭다운 (검색 가능)
class _ParentTaskDropdown
    extends ConsumerStatefulWidget {
  const _ParentTaskDropdown({
    required this.selection,
    required this.onParentTaskChanged,
    required this.theme,
  });

  final _TaskSelection selection;
  final ValueChanged<String?>
      onParentTaskChanged;
  final ThemeData theme;

  @override
  ConsumerState<_ParentTaskDropdown>
      createState() =>
          _ParentTaskDropdownState();
}

class _ParentTaskDropdownState
    extends ConsumerState<_ParentTaskDropdown> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tasksAsync =
        ref.watch(allMyTasksProvider);
    final allTasks =
        tasksAsync.valueOrNull ?? [];

    // 독립 업무(부모 없는 업무)만 필터
    var candidates = allTasks
        .where((t) => t.parentTaskId == null)
        .toList();

    // 선택된 프로젝트에 따라 필터
    final projId =
        widget.selection.overrideProjectId;
    if (projId != null) {
      candidates = candidates
          .where((t) => t.projectId == projId)
          .toList();
    }

    // 검색어 필터
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      candidates = candidates
          .where(
            (t) => t.title
                .toLowerCase()
                .contains(q),
          )
          .toList();
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        // 검색 필드
        TextField(
          decoration: const InputDecoration(
            hintText: '부모 업무 검색...',
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
            ),
          ),
          style:
              widget.theme.textTheme.bodySmall,
          onChanged: (val) =>
              setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 4),

        // 후보 목록
        Container(
          constraints: const BoxConstraints(
            maxHeight: 150,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.theme.colorScheme
                  .outlineVariant,
            ),
            borderRadius:
                BorderRadius.circular(8),
          ),
          child: candidates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(
                    12,
                  ),
                  child: Text(
                    projId != null
                        ? '해당 프로젝트에 '
                            '독립 업무가 없습니다'
                        : '독립 업무가 없습니다',
                    style: widget
                        .theme.textTheme.bodySmall
                        ?.copyWith(
                      color: widget
                          .theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount:
                      candidates.length,
                  itemBuilder: (ctx, i) {
                    final t = candidates[i];
                    final isSelected = widget
                            .selection
                            .overrideParentTaskId ==
                        t.id;
                    return ListTile(
                      dense: true,
                      visualDensity:
                          VisualDensity.compact,
                      selected: isSelected,
                      selectedTileColor: widget
                          .theme
                          .colorScheme
                          .primaryContainer
                          .withValues(
                        alpha: 0.3,
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons
                                .radio_button_checked
                            : Icons
                                .radio_button_off,
                        size: 18,
                        color: isSelected
                            ? widget
                                .theme
                                .colorScheme
                                .primary
                            : null,
                      ),
                      title: Text(
                        t.title,
                        style: widget.theme
                            .textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow
                            .ellipsis,
                      ),
                      subtitle: t.projectTitle !=
                              null
                          ? Text(
                              t.projectTitle!,
                              style: widget
                                  .theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: widget
                                    .theme
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            )
                          : null,
                      onTap: () {
                        widget.onParentTaskChanged(
                          isSelected
                              ? null
                              : t.id,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
