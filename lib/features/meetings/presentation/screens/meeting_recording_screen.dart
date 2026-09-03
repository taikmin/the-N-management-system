import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../data/services/speech_service.dart';
import '../../domain/models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/recording_provider.dart';

/// 회의 녹음 화면 (상세 보기 모드 지원)
/// meetingId가 null이면 독립 녹음 모드
/// isDetailMode가 true면 플로팅 위젯에서 진입
class MeetingRecordingScreen
    extends ConsumerStatefulWidget {
  const MeetingRecordingScreen({
    super.key,
    this.meetingId,
    this.isDetailMode = false,
  });

  final String? meetingId;
  final bool isDetailMode;

  @override
  ConsumerState<MeetingRecordingScreen>
      createState() =>
          _MeetingRecordingScreenState();
}

class _MeetingRecordingScreenState
    extends ConsumerState<MeetingRecordingScreen> {
  final _manualController = TextEditingController();
  final _scrollController = ScrollController();

  bool get _isStandalone =>
      widget.meetingId == null;

  @override
  void dispose() {
    _manualController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController
              .position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 300,
          ),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recording =
        ref.watch(recordingProvider);
    final theme = Theme.of(context);

    // 자동 스크롤
    ref.listen(recordingProvider, (prev, next) {
      if ((prev?.transcriptLines.length ?? 0) <
          next.transcriptLines.length) {
        _scrollToBottom();
      }
    });

    // 비웹 플랫폼 안내
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('회의 녹음'),
        ),
        body: const Center(
          child: Text(
            '음성 인식은 웹(Chrome/Edge)에서만\n'
            '사용할 수 있습니다.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 독립 녹음 모드: 회의 정보 없이 바로 본문
    if (_isStandalone) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isDetailMode
                ? '녹음 상세'
                : '회의 녹음',
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleBack(
              recording,
            ),
          ),
        ),
        body: _buildBody(
          context,
          null,
          recording,
          theme,
        ),
      );
    }

    // 회의 연결 모드
    final meetingAsync = ref.watch(
      meetingDetailProvider(widget.meetingId!),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isDetailMode
              ? '녹음 상세'
              : '회의 녹음',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleBack(
            recording,
          ),
        ),
      ),
      body: meetingAsync.when(
        data: (meeting) => _buildBody(
          context,
          meeting,
          recording,
          theme,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          child: Text('오류: $e'),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Meeting? meeting,
    RecordingState recording,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // 타이머 + 상태
        _TimerSection(
          recording: recording,
          theme: theme,
        ),
        const Divider(height: 1),

        // 실시간 텍스트 영역
        Expanded(
          child: _TranscriptArea(
            recording: recording,
            scrollController: _scrollController,
            theme: theme,
          ),
        ),
        const Divider(height: 1),

        // 수동 입력 영역
        _ManualInputSection(
          controller: _manualController,
          onAdd: () {
            final text =
                _manualController.text.trim();
            if (text.isNotEmpty) {
              ref
                  .read(
                      recordingProvider.notifier)
                  .addManualText(text);
              _manualController.clear();
            }
          },
          theme: theme,
        ),

        // 진행 상태 / 재시도 / 에러 메시지
        if (recording.isGenerating &&
            recording.progressMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            color: AppColors.primary
                .withValues(alpha: 0.08),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording
                            .progressMessage!,
                        style: theme
                            .textTheme.bodySmall
                            ?.copyWith(
                          color:
                              AppColors.primary,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gemini 2.5 Pro로 분석 중 '
                        '(약 30초~1분 소요)',
                        style: theme
                            .textTheme.labelSmall
                            ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (recording.retryMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.xs,
            ),
            color: AppColors.warning
                .withValues(alpha: 0.1),
            child: Text(
              recording.retryMessage!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        if (recording.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.xs,
            ),
            color: AppColors.error
                .withValues(alpha: 0.1),
            child: Text(
              recording.error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),

        // 컨트롤 버튼
        _ControlSection(
          recording: recording,
          onStart: () => ref
              .read(recordingProvider.notifier)
              .startRecording(
                meetingId: widget.meetingId,
              ),
          onPause: () => ref
              .read(recordingProvider.notifier)
              .pauseRecording(),
          onResume: () => ref
              .read(recordingProvider.notifier)
              .resumeRecording(),
          onStop: () => ref
              .read(recordingProvider.notifier)
              .stopRecording(),
          onGenerate: () =>
              _generateMinutes(meeting),
          theme: theme,
        ),
      ],
    );
  }

  Future<void> _generateMinutes(
    Meeting? meeting,
  ) async {
    final notifier =
        ref.read(recordingProvider.notifier);

    await notifier.generateMinutes(
      meetingTitle: meeting?.title,
      meetingDate: meeting != null
          ? '${meeting.meetingDate.year}.'
              '${meeting.meetingDate.month.toString().padLeft(2, '0')}.'
              '${meeting.meetingDate.day.toString().padLeft(2, '0')}'
          : null,
      projectTitle: meeting?.projectTitle,
    );

    if (!mounted) return;
    final state = ref.read(recordingProvider);
    if (state.minutesResult != null) {
      if (_isStandalone) {
        context.push('/tasks/minutes-result');
      } else {
        context.push(
          '/meetings/${widget.meetingId}'
          '/minutes-result',
        );
      }
    }
  }

  /// 뒤로가기 처리
  void _handleBack(RecordingState recording) {
    // 상세 보기 모드: 상태 유지하고 돌아감
    if (widget.isDetailMode) {
      Navigator.pop(context);
      return;
    }

    // 일반 모드: 내용 있으면 확인 후 리셋
    _confirmExit(recording);
  }

  Future<void> _confirmExit(
    RecordingState recording,
  ) async {
    if (recording.transcriptLines.isEmpty) {
      ref.read(recordingProvider.notifier).reset();
      if (mounted) Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('녹음 종료'),
        content: const Text(
          '녹음된 내용이 있습니다.\n'
          '정말 나가시겠습니까?',
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
              '나가기',
              style: TextStyle(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    ref.read(recordingProvider.notifier).reset();
    if (context.mounted) Navigator.pop(context);
  }
}

// ─── 타이머 섹션 ───

class _TimerSection extends StatelessWidget {
  const _TimerSection({
    required this.recording,
    required this.theme,
  });
  final RecordingState recording;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final stateLabel =
        switch (recording.speechState) {
      SpeechState.idle => '대기',
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

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        children: [
          Text(
            recording.formattedTime,
            style: theme.textTheme.displaySmall
                ?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              if (recording.isRecording)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(
                    right: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                stateLabel,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 트랜스크립트 영역 ───

class _TranscriptArea extends StatelessWidget {
  const _TranscriptArea({
    required this.recording,
    required this.scrollController,
    required this.theme,
  });
  final RecordingState recording;
  final ScrollController scrollController;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (recording.transcriptLines.isEmpty &&
        recording.interimText.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none,
              size: 48,
              color: theme
                  .colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              '녹음을 시작하면 텍스트가 표시됩니다',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(
                color: theme
                    .colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding:
          const EdgeInsets.all(AppSizes.md),
      itemCount:
          recording.transcriptLines.length +
              (recording.interimText.isNotEmpty
                  ? 1
                  : 0),
      itemBuilder: (context, index) {
        if (index <
            recording.transcriptLines.length) {
          final line =
              recording.transcriptLines[index];
          final isManual =
              line.startsWith('[수동]');
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppSizes.xs,
            ),
            child: Text(
              line,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(
                color: isManual
                    ? AppColors.primary
                    : null,
                fontStyle: isManual
                    ? FontStyle.italic
                    : null,
              ),
            ),
          );
        }
        // interim text
        return Padding(
          padding: const EdgeInsets.only(
            bottom: AppSizes.xs,
          ),
          child: Text(
            recording.interimText,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      },
    );
  }
}

// ─── 수동 입력 ───

class _ManualInputSection extends StatelessWidget {
  const _ManualInputSection({
    required this.controller,
    required this.onAdd,
    required this.theme,
  });
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText:
                    '수동 입력 (메모, 보충 내용)',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(
              Icons.add,
              size: 20,
            ),
            tooltip: '추가',
          ),
        ],
      ),
    );
  }
}

// ─── 컨트롤 버튼 ───

class _ControlSection extends StatelessWidget {
  const _ControlSection({
    required this.recording,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onGenerate,
    required this.theme,
  });

  final RecordingState recording;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onGenerate;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color:
                theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 녹음 컨트롤 버튼
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                // 녹음/재개 버튼
                if (recording.isIdle ||
                    recording.isPaused)
                  _ControlButton(
                    icon:
                        Icons.fiber_manual_record,
                    color: AppColors.error,
                    label: recording.isPaused
                        ? '재개'
                        : '녹음',
                    onPressed: recording.isPaused
                        ? onResume
                        : onStart,
                  ),
                // 일시 정지 버튼
                if (recording.isRecording)
                  _ControlButton(
                    icon: Icons.pause,
                    color: AppColors.warning,
                    label: '일시 정지',
                    onPressed: onPause,
                  ),
                const SizedBox(
                  width: AppSizes.lg,
                ),
                // 중지 버튼
                if (recording.isRecording ||
                    recording.isPaused)
                  _ControlButton(
                    icon: Icons.stop,
                    color: theme.colorScheme
                        .onSurfaceVariant,
                    label: '중지',
                    onPressed: onStop,
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            // AI 회의록 생성 버튼
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    recording.isGenerating ||
                            recording
                                .transcriptLines
                                .isEmpty
                        ? null
                        : onGenerate,
                icon: recording.isGenerating
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
                        Icons.auto_awesome,
                      ),
                label: Text(
                  recording.isGenerating
                      ? 'AI 생성 중...'
                      : '회의록 생성 (AI)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          color: color,
          style: IconButton.styleFrom(
            backgroundColor:
                color.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
