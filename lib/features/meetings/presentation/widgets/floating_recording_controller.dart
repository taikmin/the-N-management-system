import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../data/services/speech_service.dart';
import '../../domain/models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/recording_provider.dart';
import '../helpers/beforeunload_helper.dart';

/// 플로팅 녹음 컨트롤러
/// 앱 전체에 떠있는 바 형태 위젯
class FloatingRecordingController
    extends ConsumerStatefulWidget {
  const FloatingRecordingController({super.key});

  @override
  ConsumerState<FloatingRecordingController>
      createState() =>
          _FloatingRecordingControllerState();
}

class _FloatingRecordingControllerState
    extends ConsumerState<FloatingRecordingController> {
  bool _expanded = false;

  @override
  void dispose() {
    disableBeforeUnloadWarning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(recordingProvider);
    final theme = Theme.of(context);
    final isMobile =
        ResponsiveLayout.isMobile(context);

    // beforeunload 경고 관리
    if (kIsWeb) {
      if (recording.transcriptLines.isNotEmpty ||
          recording.isRecording ||
          recording.isPaused) {
        enableBeforeUnloadWarning();
      } else {
        disableBeforeUnloadWarning();
      }
    }

    // 회의록 생성 완료 시 자동 이동
    ref.listen(recordingProvider, (prev, next) {
      if (prev?.minutesResult == null &&
          next.minutesResult != null) {
        final mid = next.meetingId;
        if (mid != null && mid.isNotEmpty) {
          context.push(
            '/meetings/$mid/minutes-result',
          );
        } else {
          context.push('/tasks/minutes-result');
        }
      }
    });

    if (!recording.isFloatingVisible) {
      return const SizedBox.shrink();
    }

    final hMargin =
        isMobile ? AppSizes.xs : AppSizes.sm;

    return Positioned(
      left: hMargin,
      right: hMargin,
      bottom: isMobile ? 88.0 : AppSizes.sm,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme
            .colorScheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: const Duration(
            milliseconds: 200,
          ),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactBar(
                recording,
                theme,
                isMobile,
              ),
              if (_expanded) ...[
                Divider(
                  height: 1,
                  color: theme
                      .colorScheme.outlineVariant,
                ),
                _buildExpandedSection(
                  recording,
                  theme,
                  isMobile,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBar(
    RecordingState recording,
    ThemeData theme,
    bool isMobile,
  ) {
    if (recording.isWaiting) {
      return _buildWaitingBar(
        recording,
        theme,
        isMobile,
      );
    }

    final stateLabel =
        switch (recording.speechState) {
      SpeechState.idle => recording.isGenerating
          ? (recording.progressMessage ??
              'AI 생성 중')
          : '녹음 완료',
      SpeechState.listening => '녹음 중',
      SpeechState.paused => '일시 정지',
    };

    final stateColor =
        switch (recording.speechState) {
      SpeechState.idle =>
        theme.colorScheme.onSurfaceVariant,
      SpeechState.listening => AppColors.error,
      SpeechState.paused => AppColors.warning,
    };

    final hPad =
        isMobile ? AppSizes.sm : AppSizes.md;

    return InkWell(
      onTap: () =>
          setState(() => _expanded = !_expanded),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hPad,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            // 상태 표시
            if (recording.isRecording)
              _PulsingDot(color: AppColors.error)
            else if (recording.isGenerating)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                Icons.mic_off,
                size: 14,
                color: stateColor,
              ),
            const SizedBox(width: 6),

            // 상태 라벨
            Flexible(
              child: Text(
                stateLabel,
                style: theme.textTheme.labelMedium
                    ?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),

            // 경과 시간
            Text(
              recording.formattedTime,
              style: theme.textTheme.labelMedium
                  ?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            // 컨트롤 버튼
            if (recording.isRecording)
              _CompactButton(
                icon: Icons.pause,
                tooltip: '일시 정지',
                onPressed: () => ref
                    .read(
                        recordingProvider.notifier)
                    .pauseRecording(),
              ),
            if (recording.isPaused)
              _CompactButton(
                icon: Icons.fiber_manual_record,
                color: AppColors.error,
                tooltip: '재개',
                onPressed: () => ref
                    .read(
                        recordingProvider.notifier)
                    .resumeRecording(),
              ),
            if (recording.isRecording ||
                recording.isPaused)
              _CompactButton(
                icon: Icons.stop,
                tooltip: '중지',
                onPressed: () => ref
                    .read(
                        recordingProvider.notifier)
                    .stopRecording(),
              ),

            // 확장/축소 아이콘
            Icon(
              _expanded
                  ? Icons.expand_more
                  : Icons.expand_less,
              size: 20,
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 대기 상태 바 (녹음 시작 전)
  Widget _buildWaitingBar(
    RecordingState recording,
    ThemeData theme,
    bool isMobile,
  ) {
    final hPad =
        isMobile ? AppSizes.sm : AppSizes.md;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic_none,
            size: 20,
            color: theme
                .colorScheme.onSurfaceVariant,
          ),
          // 모바일에서 "녹음 대기" 숨김
          if (!isMobile) ...[
            const SizedBox(width: 8),
            Text(
              '녹음 대기',
              style: theme.textTheme.labelMedium
                  ?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),

          // 불러오기: 모바일은 아이콘만
          if (isMobile)
            _CompactButton(
              icon: Icons.folder_open,
              tooltip: '불러오기',
              onPressed: _showSavedMinutesSheet,
            )
          else
            _CompactTextButton(
              icon: Icons.folder_open,
              label: '불러오기',
              onPressed: _showSavedMinutesSheet,
            ),
          SizedBox(width: isMobile ? 4 : 8),

          // 파일 업로드
          if (isMobile)
            _CompactButton(
              icon: Icons.attach_file,
              tooltip: '파일 업로드',
              onPressed: _pickAudioFile,
            )
          else
            _CompactTextButton(
              icon: Icons.attach_file,
              label: '파일',
              onPressed: _pickAudioFile,
            ),
          SizedBox(width: isMobile ? 4 : 8),

          // 녹음 시작: 모바일은 "시작"
          FilledButton.icon(
            onPressed: () => ref
                .read(recordingProvider.notifier)
                .startRecording(),
            icon: const Icon(
              Icons.fiber_manual_record,
              size: 14,
              color: Colors.white,
            ),
            label: Text(
              isMobile ? '시작' : '녹음 시작',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12,
                vertical: 0,
              ),
              textStyle:
                  theme.textTheme.labelMedium
                      ?.copyWith(
                color: Colors.white,
              ),
              minimumSize: const Size(0, 32),
            ),
          ),
          SizedBox(width: isMobile ? 2 : 8),

          // 닫기 버튼
          _CompactButton(
            icon: Icons.close,
            tooltip: '닫기',
            onPressed: () => ref
                .read(recordingProvider.notifier)
                .reset(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSection(
    RecordingState recording,
    ThemeData theme,
    bool isMobile,
  ) {
    final hPad =
        isMobile ? AppSizes.sm : AppSizes.md;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hPad,
        AppSizes.xs,
        hPad,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 진행 메시지
          if (recording.isGenerating &&
              recording.progressMessage != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSizes.xs,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recording.progressMessage!,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 재시도 메시지
          if (recording.retryMessage != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSizes.xs,
              ),
              child: Text(
                recording.retryMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),

          // 에러 메시지
          if (recording.error != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSizes.xs,
              ),
              child: Text(
                recording.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: AppColors.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // 최근 텍스트 2줄
          if (recording
              .transcriptLines.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Text(
                recording.transcriptLines.length >
                        2
                    ? recording.transcriptLines
                        .sublist(
                          recording.transcriptLines
                                  .length -
                              2,
                        )
                        .join('\n')
                    : recording.transcriptLines
                        .join('\n'),
                style:
                    theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
          ],

          // 버튼 행 — Wrap으로 줄바꿈 허용
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              // 메모 추가
              _ActionChip(
                icon: Icons.edit_note,
                label: isMobile ? '메모' : '메모 추가',
                onPressed:
                    _showManualInputDialog,
              ),

              // 상세 보기
              _ActionChip(
                icon: Icons.open_in_full,
                label: '상세',
                onPressed: () {
                  final mid =
                      recording.meetingId;
                  if (mid != null &&
                      mid.isNotEmpty) {
                    context.push(
                      '/meetings/$mid/record'
                      '?detail=true',
                    );
                  } else {
                    context.push(
                      '/tasks/record'
                      '?detail=true',
                    );
                  }
                },
              ),

              // 불러오기
              _ActionChip(
                icon: Icons.folder_open,
                label:
                    isMobile ? '불러오기' : '불러오기',
                onPressed:
                    _showSavedMinutesSheet,
              ),

              // 파일 업로드
              _ActionChip(
                icon: Icons.attach_file,
                label: isMobile
                    ? '파일'
                    : '파일 업로드',
                onPressed: _pickAudioFile,
              ),

              // 회의록 생성 버튼
              if (!recording.isGenerating &&
                  recording.transcriptLines
                      .isNotEmpty)
                FilledButton.icon(
                  onPressed: () => ref
                      .read(
                          recordingProvider.notifier)
                      .generateMinutes(),
                  icon: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                  ),
                  label: Text(
                    isMobile ? '생성' : '회의록 생성',
                  ),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    textStyle: theme
                        .textTheme.labelMedium,
                    minimumSize:
                        const Size(0, 32),
                  ),
                ),

              // 초기화 버튼
              if (recording.isStopped ||
                  (recording.isIdle &&
                      !recording.isGenerating &&
                      recording.transcriptLines
                          .isEmpty))
                _CompactButton(
                  icon: Icons.close,
                  tooltip: '닫기',
                  onPressed: _confirmReset,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '수동 입력 (메모, 보충 내용)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (text) {
            if (text.trim().isNotEmpty) {
              ref
                  .read(
                      recordingProvider.notifier)
                  .addManualText(text);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final text =
                  controller.text.trim();
              if (text.isNotEmpty) {
                ref
                    .read(recordingProvider
                        .notifier)
                    .addManualText(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showSavedMinutesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return _SavedMinutesSheet(
          onSelected: (meeting) {
            Navigator.pop(ctx);
            final rec =
                ref.read(recordingProvider);
            if (rec.transcriptLines.isNotEmpty) {
              _confirmNavigateToMeeting(
                meeting.id,
              );
            } else {
              ref
                  .read(
                      recordingProvider.notifier)
                  .reset();
              context.push(
                '/meetings/${meeting.id}',
              );
            }
          },
        );
      },
    );
  }

  Future<void> _confirmNavigateToMeeting(
    String meetingId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('녹음 데이터 확인'),
        content: const Text(
          '현재 녹음된 내용이 있습니다.\n'
          '다른 회의록으로 이동하면 녹음 데이터가 '
          '삭제됩니다.\n\n'
          '계속하시겠습니까?',
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
              '이동',
              style: TextStyle(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref
          .read(recordingProvider.notifier)
          .reset();
      context.push('/meetings/$meetingId');
    }
  }

  Future<void> _confirmReset() async {
    final recording = ref.read(recordingProvider);
    if (recording.transcriptLines.isEmpty) {
      ref.read(recordingProvider.notifier).reset();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('녹음 종료'),
        content: const Text(
          '녹음된 내용이 있습니다.\n'
          '정말 닫으시겠습니까?',
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
              '닫기',
              style: TextStyle(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(recordingProvider.notifier).reset();
    }
  }

  Future<void> _pickAudioFile() async {
    // 기존 녹음 데이터 확인
    final recording = ref.read(recordingProvider);
    if (recording.transcriptLines.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('확인'),
          content: const Text(
            '현재 녹음된 내용이 있습니다.\n'
            '파일을 업로드하면 기존 내용이 '
            '대체됩니다.\n\n'
            '계속하시겠습니까?',
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
              child: const Text('계속'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final result =
        await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'm4a',
        'mp3',
        'wav',
        'ogg',
        'flac',
        'aac',
        'webm',
      ],
      withData: true,
    );

    if (result == null ||
        result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('파일을 읽을 수 없습니다'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    _showAudioInfoDialog(bytes, file.name);
  }

  void _showAudioInfoDialog(
    Uint8List bytes,
    String fileName,
  ) {
    final titleCtl = TextEditingController();
    final now = DateTime.now();
    final dateStr =
        '${now.year}.'
        '${now.month.toString().padLeft(2, '0')}.'
        '${now.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) {
        final dlgTheme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('오디오 파일 분석'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // 파일 정보
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dlgTheme.colorScheme
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.audio_file,
                      size: 20,
                      color: dlgTheme.colorScheme
                          .primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        overflow:
                            TextOverflow.ellipsis,
                        style: dlgTheme
                            .textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      _formatFileSize(
                        bytes.length,
                      ),
                      style: dlgTheme
                          .textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtl,
                decoration:
                    const InputDecoration(
                  labelText: '회의 제목 (선택)',
                  hintText: '미입력 시 자동 생성',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '회의 날짜: $dateStr',
                style: dlgTheme
                    .textTheme.bodySmall
                    ?.copyWith(
                  color: dlgTheme.colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final title = titleCtl
                        .text
                        .trim()
                        .isEmpty
                    ? null
                    : titleCtl.text.trim();
                ref
                    .read(recordingProvider
                        .notifier)
                    .processAudioFile(
                  audioBytes: bytes,
                  fileName: fileName,
                  meetingId: ref
                      .read(recordingProvider)
                      .meetingId,
                  meetingTitle: title,
                  meetingDate: dateStr,
                );
              },
              icon: const Icon(
                Icons.auto_awesome,
                size: 16,
              ),
              label: const Text('분석 시작'),
            ),
          ],
        );
      },
    ).then((_) => titleCtl.dispose());
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}'
          ' KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}'
          ' MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}'
        ' GB';
  }
}

// ─── 저장된 회의록 목록 BottomSheet ───

class _SavedMinutesSheet
    extends ConsumerWidget {
  const _SavedMinutesSheet({
    required this.onSelected,
  });

  final ValueChanged<Meeting> onSelected;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final meetingsAsync =
        ref.watch(meetingsWithNotesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // 핸들
            Padding(
              padding: const EdgeInsets.only(
                top: 12,
                bottom: 8,
              ),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme.outlineVariant,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '저장된 회의록',
                    style: theme
                        .textTheme.titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: meetingsAsync.when(
                data: (meetings) {
                  if (meetings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons
                                .description_outlined,
                            size: 48,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(
                            height: AppSizes.sm,
                          ),
                          Text(
                            '저장된 회의록이 없습니다',
                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                    itemCount: meetings.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final m = meetings[i];
                      final dt = m.meetingDate;
                      final dateStr =
                          '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
                      final preview =
                          (m.meetingNotes ?? '')
                              .replaceAll(
                                '\n',
                                ' ',
                              )
                              .trim();

                      return ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary
                                  .withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.description,
                            size: 20,
                            color:
                                AppColors.primary,
                          ),
                        ),
                        title: Text(
                          m.title,
                          maxLines: 1,
                          overflow: TextOverflow
                              .ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              dateStr,
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: theme
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            if (preview
                                .isNotEmpty)
                              Text(
                                preview,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons
                              .chevron_right,
                          size: 20,
                        ),
                        onTap: () =>
                            onSelected(m),
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
}

// ─── 헬퍼 위젯 ───

class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        color: color,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}

class _CompactTextButton extends StatelessWidget {
  const _CompactTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),
        textStyle: theme.textTheme.labelMedium,
        minimumSize: const Size(0, 32),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
      materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelStyle:
          Theme.of(context).textTheme.labelSmall,
    );
  }
}

/// 맥동하는 빨간 점 (녹음 중 표시)
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() =>
      _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1000,
      ),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(
              alpha: 0.5 + _controller.value * 0.5,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
