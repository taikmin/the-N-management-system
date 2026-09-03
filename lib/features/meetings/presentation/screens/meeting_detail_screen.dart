import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/utils/file_downloader.dart';
import '../../../../shared/widgets/file_attachment_section.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/models/meeting.dart';
import '../../domain/models/meeting_agenda.dart';
import '../../domain/models/meeting_document.dart';
import '../../domain/models/meeting_participant.dart';
import '../../domain/models/meeting_timeline.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/recording_provider.dart';

class MeetingDetailScreen extends ConsumerWidget {
  const MeetingDetailScreen({super.key, required this.meetingId});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingDetailProvider(meetingId));

    return meetingAsync.when(
      data: (meeting) => _MeetingDetailBody(meeting: meeting),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _MeetingDetailBody extends ConsumerStatefulWidget {
  const _MeetingDetailBody({required this.meeting});
  final Meeting meeting;

  @override
  ConsumerState<_MeetingDetailBody> createState() =>
      _MeetingDetailBodyState();
}

class _MeetingDetailBodyState extends ConsumerState<_MeetingDetailBody>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;

    return Scaffold(
      appBar: AppBar(
        title: Text(meeting.title, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: '개요'),
            Tab(icon: Icon(Icons.description_outlined), text: '문서'),
            Tab(icon: Icon(Icons.list_alt), text: '안건'),
            Tab(icon: Icon(Icons.edit_note), text: '회의록'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(v, meeting),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'edit', child: Text('수정')),
              if (meeting.status != MeetingStatus.completed)
                const PopupMenuItem(
                    value: 'complete', child: Text('완료 처리')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제',
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(meeting: meeting),
          _DocumentsTab(meetingId: meeting.id),
          _AgendaTab(meetingId: meeting.id),
          _MinutesTab(meeting: meeting),
        ],
      ),
    );
  }

  Future<void> _handleAction(String action, Meeting meeting) async {
    switch (action) {
      case 'edit':
        if (mounted) {
          context.push('/meetings/edit/${meeting.id}');
        }
      case 'complete':
        await ref.read(meetingListProvider.notifier).updateMeeting(
              meeting.id,
              meeting.copyWith(status: MeetingStatus.completed),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회의가 완료 처리되었습니다')),
          );
        }
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('회의 삭제'),
            content: const Text('이 회의를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await ref
              .read(meetingListProvider.notifier)
              .deleteMeeting(meeting.id);
          if (mounted) Navigator.pop(context);
        }
    }
  }
}

// ─── Tab 1: Overview ───

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync =
        ref.watch(meetingParticipantsProvider(meeting.id));
    final timelineAsync = ref.watch(meetingTimelineProvider(meeting.id));
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 회의 정보 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(status: meeting.status),
                      const SizedBox(width: AppSizes.xs),
                      _TypeBadge(type: meeting.meetingType),
                      const SizedBox(width: AppSizes.xs),
                      _ModeBadge(mode: meeting.meetingMode),
                      const Spacer(),
                      Text(
                        meeting.isToday
                            ? 'D-Day'
                            : meeting.isPast
                                ? '종료'
                                : 'D-${meeting.daysUntil}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: meeting.isToday
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InfoRow(
                    icon: Icons.science_outlined,
                    label: '과제',
                    value: meeting.projectTitle ?? '-',
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: '일시',
                    value: _formatDateTime(meeting.meetingDate),
                  ),
                  if (meeting.location != null)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: '장소',
                      value: meeting.location!,
                    ),
                  if (meeting.roomName != null)
                    _InfoRow(
                      icon: Icons.meeting_room_outlined,
                      label: '회의실',
                      value: meeting.roomName!,
                    ),
                  _InfoRow(
                    icon: Icons.people_outline,
                    label: '예상 참석',
                    value: '${meeting.expectedAttendees}명',
                  ),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: '등록자',
                    value: meeting.creatorName ?? '-',
                  ),
                  if (meeting.mealReservation)
                    _InfoRow(
                      icon: Icons.restaurant,
                      label: '식사',
                      value: meeting.mealLocation ?? '예약됨',
                    ),
                  // 온라인 회의 정보
                  if (meeting.meetingMode !=
                      MeetingMode.inPerson) ...[
                    const Divider(),
                    if (meeting.onlinePlatform != null)
                      _InfoRow(
                        icon: Icons.videocam,
                        label: '플랫폼',
                        value: meeting.onlinePlatform!,
                      ),
                    if (meeting.onlineLink != null)
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              icon: Icons.link,
                              label: '링크',
                              value:
                                  meeting.onlineLink!,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.copy,
                                size: 16),
                            tooltip: '링크 복사',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                    text: meeting
                                        .onlineLink!),
                              );
                              ScaffoldMessenger.of(
                                      context)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        '링크가 복사되었습니다')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.open_in_new,
                                size: 16),
                            tooltip: '회의 참여',
                            onPressed: () async {
                              final uri = Uri.parse(
                                  meeting
                                      .onlineLink!);
                              if (await canLaunchUrl(
                                  uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode
                                        .externalApplication);
                              }
                            },
                          ),
                        ],
                      ),
                    if (meeting.onlineMeetingId !=
                        null)
                      _InfoRow(
                        icon: Icons.tag,
                        label: '회의 ID',
                        value:
                            meeting.onlineMeetingId!,
                      ),
                    if (meeting.onlinePassword !=
                        null)
                      _InfoRow(
                        icon: Icons.lock_outline,
                        label: '비밀번호',
                        value:
                            meeting.onlinePassword!,
                      ),
                  ],
                  if (meeting.description != null) ...[
                    const Divider(),
                    Text(meeting.description!,
                        style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // 참석자 섹션
          Text(
            '참석자',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSizes.xs),
          participantsAsync.when(
            data: (participants) {
              if (participants.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Center(
                      child: Text(
                        '등록된 참석자가 없습니다',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: participants
                      .map((p) => _ParticipantTile(participant: p))
                      .toList(),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('오류: $e'),
          ),
          const SizedBox(height: AppSizes.md),

          // 타임라인 섹션
          Text(
            '준비 타임라인',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSizes.xs),
          timelineAsync.when(
            data: (milestones) {
              if (milestones.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Center(
                      child: Text(
                        '타임라인이 없습니다',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  Card(
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (oldIdx, newIdx) {
                        if (newIdx > oldIdx) newIdx--;
                        final reordered =
                            List<MeetingTimeline>.from(
                          milestones,
                        );
                        final item =
                            reordered.removeAt(oldIdx);
                        reordered.insert(newIdx, item);
                        ref
                            .read(
                              meetingTimelineProvider(
                                meeting.id,
                              ).notifier,
                            )
                            .reorderTimeline(
                              reordered
                                  .map((m) => m.id)
                                  .toList(),
                            );
                      },
                      children: [
                        for (var i = 0;
                            i < milestones.length;
                            i++)
                          _TimelineTile(
                            key: ValueKey(
                              milestones[i].id,
                            ),
                            milestone: milestones[i],
                            meetingId: meeting.id,
                            dragIndex: i,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _showAddTimelineDialog(
                        context,
                        ref,
                        meeting.id,
                      ),
                      icon: const Icon(
                        Icons.add,
                        size: 18,
                      ),
                      label: const Text('항목 추가'),
                    ),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('오류: $e'),
          ),

          // 회의 녹음 버튼 (준비중/진행중일 때)
          if (meeting.status ==
                  MeetingStatus.preparing ||
              meeting.status ==
                  MeetingStatus.inProgress ||
              meeting.status ==
                  MeetingStatus.notified) ...[
            const SizedBox(height: AppSizes.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final rec =
                      ref.read(recordingProvider);
                  if (rec.isFloatingVisible) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          '이미 녹음 중입니다',
                        ),
                        duration:
                            Duration(seconds: 1),
                      ),
                    );
                    return;
                  }
                  final dt =
                      meeting.meetingDate;
                  ref
                      .read(recordingProvider
                          .notifier)
                      .startRecording(
                        meetingId: meeting.id,
                        meetingTitle:
                            meeting.title,
                        meetingDate:
                            '${dt.year}.'
                            '${dt.month.toString().padLeft(2, '0')}.'
                            '${dt.day.toString().padLeft(2, '0')}',
                        projectTitle:
                            meeting.projectTitle,
                      );
                },
                icon: const Icon(Icons.mic),
                label: const Text('회의 녹음 시작'),
              ),
            ),
          ],

          // 첨부 파일
          const SizedBox(height: AppSizes.md),
          Text(
            '첨부 파일',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSizes.xs),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(AppSizes.md),
              child: FileAttachmentSection(
                entityType: 'meeting',
                entityId: meeting.id,
                title: '회의 첨부 파일',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});
  final MeetingParticipant participant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attendanceColor = switch (participant.attendance) {
      AttendanceStatus.confirmed => AppColors.done,
      AttendanceStatus.declined => AppColors.error,
      AttendanceStatus.pending => AppColors.warning,
    };

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          (participant.userName ?? '?')[0],
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(participant.userName ?? '이름 없음'),
      subtitle: Text(participant.role.label),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: attendanceColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          participant.attendance.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: attendanceColor,
          ),
        ),
      ),
    );
  }
}

void _showAddTimelineDialog(
  BuildContext context,
  WidgetRef ref,
  String meetingId,
) {
  final labelCtrl = TextEditingController();
  var selectedDate = DateTime.now().add(const Duration(days: 7));

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('타임라인 항목 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '예: 자료 배포',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜'),
              trailing: Text(
                '${selectedDate.year}.'
                '${selectedDate.month.toString().padLeft(2, '0')}.'
                '${selectedDate.day.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setDialogState(() => selectedDate = picked);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final label = labelCtrl.text.trim();
              if (label.isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(meetingTimelineProvider(meetingId).notifier)
                  .addMilestone(
                    MeetingTimeline(
                      id: '',
                      meetingId: meetingId,
                      milestone: 'custom',
                      label: label,
                      dueDate: selectedDate,
                    ),
                  );
            },
            child: const Text('추가'),
          ),
        ],
      ),
    ),
  );
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({
    super.key,
    required this.milestone,
    required this.meetingId,
    required this.dragIndex,
  });
  final MeetingTimeline milestone;
  final String meetingId;
  final int dragIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final color = milestone.isCompleted
        ? AppColors.done
        : milestone.isOverdue
            ? AppColors.error
            : AppColors.info;

    return ListTile(
      dense: true,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: dragIndex,
            child: const Icon(
              Icons.drag_indicator,
              size: 20,
              color: Colors.grey,
            ),
          ),
          IconButton(
            icon: Icon(
              milestone.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: color,
            ),
            onPressed: () => ref
                .read(meetingTimelineProvider(meetingId)
                    .notifier)
                .toggleMilestone(
                  milestone.id,
                  isCompleted: !milestone.isCompleted,
                ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      title: Text(
        milestone.label,
        style: TextStyle(
          decoration: milestone.isCompleted
              ? TextDecoration.lineThrough
              : null,
          color: milestone.isCompleted
              ? theme.colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      subtitle: Text(
        '${milestone.dueDate.month}/${milestone.dueDate.day}',
        style: TextStyle(
          color: milestone.isOverdue
              ? AppColors.error
              : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (milestone.isOverdue &&
              !milestone.isCompleted)
            const Icon(
              Icons.warning_amber,
              color: AppColors.error,
              size: 20,
            ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
            ),
            onPressed: () =>
                _showEditDialog(context, ref),
            visualDensity: VisualDensity.compact,
            tooltip: '수정',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: theme.colorScheme.error,
            ),
            onPressed: () =>
                _confirmDelete(context, ref),
            visualDensity: VisualDensity.compact,
            tooltip: '삭제',
          ),
        ],
      ),
      onTap: () => _showEditDialog(context, ref),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final labelCtrl = TextEditingController(text: milestone.label);
    var selectedDate = milestone.dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('타임라인 항목 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: '내용',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('날짜'),
                trailing: Text(
                  '${selectedDate.year}.'
                  '${selectedDate.month.toString().padLeft(2, '0')}.'
                  '${selectedDate.day.toString().padLeft(2, '0')}',
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                Navigator.pop(ctx);
                await ref
                    .read(meetingTimelineProvider(meetingId).notifier)
                    .updateMilestone(
                      milestone.id,
                      label: label,
                      dueDate: selectedDate,
                    );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('타임라인 항목 삭제'),
        content: Text('"${milestone.label}" 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(meetingTimelineProvider(meetingId).notifier)
                  .deleteMilestone(milestone.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Documents ───

class _DocumentsTab extends ConsumerStatefulWidget {
  const _DocumentsTab({required this.meetingId});
  final String meetingId;

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  final _titleController = TextEditingController();
  DocType _docType = DocType.template;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(meetingDocumentsProvider(widget.meetingId));
    final theme = Theme.of(context);

    return Column(
      children: [
        // 문서 추가 입력란
        Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<DocType>(
                  initialValue: _docType,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: DocType.values
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.label,
                                style: theme.textTheme.bodySmall),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _docType = v);
                  },
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '문서 제목',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addDocument,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 문서 목록
        Expanded(
          child: docsAsync.when(
            data: (docs) {
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    '등록된 문서가 없습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              // 유형별 그룹
              final grouped = <DocType, List<MeetingDocument>>{};
              for (final d in docs) {
                (grouped[d.docType] ??= []).add(d);
              }

              return ListView(
                padding: const EdgeInsets.all(AppSizes.sm),
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.xs,
                            horizontal: AppSizes.sm),
                        child: Text(
                          entry.key.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...entry.value.map((doc) =>
                          _DocumentTile(
                            doc: doc,
                            meetingId: widget.meetingId,
                          )),
                      const SizedBox(height: AppSizes.sm),
                    ],
                  );
                }).toList(),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }

  Future<void> _addDocument() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final doc = MeetingDocument(
      id: '',
      meetingId: widget.meetingId,
      docType: _docType,
      title: title,
      uploaderId: user.id,
    );

    await ref
        .read(meetingDocumentsProvider(widget.meetingId).notifier)
        .createDocument(doc);
    _titleController.clear();
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.doc, required this.meetingId});
  final MeetingDocument doc;
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = switch (doc.submitStatus) {
      SubmitStatus.submitted => AppColors.done,
      SubmitStatus.revisionRequested => AppColors.warning,
      SubmitStatus.notSubmitted => doc.isOverdue ? AppColors.error : AppColors.todo,
    };

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.insert_drive_file_outlined,
          color: statusColor,
        ),
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                doc.uploaderName ?? '',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
            if (doc.dueDate != null) ...[
              const Text(' · '),
              Text(
                '마감: ${doc.dueDate!.month}/${doc.dueDate!.day}',
                style: TextStyle(
                  color: doc.isOverdue
                      ? AppColors.error
                      : null,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<SubmitStatus>(
          tooltip: '상태 변경',
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              doc.submitStatus.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
              ),
            ),
          ),
          onSelected: (status) {
            ref
                .read(meetingDocumentsProvider(meetingId).notifier)
                .updateDocumentStatus(doc.id, status);
          },
          itemBuilder: (context) => SubmitStatus.values
              .map((s) => PopupMenuItem(
                    value: s,
                    child: Text(s.label),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Tab 3: Agenda ───

class _AgendaTab extends ConsumerStatefulWidget {
  const _AgendaTab({required this.meetingId});
  final String meetingId;

  @override
  ConsumerState<_AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends ConsumerState<_AgendaTab> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '10');

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agendaAsync = ref.watch(meetingAgendaProvider(widget.meetingId));
    final theme = Theme.of(context);

    return Column(
      children: [
        // 안건 추가
        Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '안건 제목',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    suffixText: '분',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addAgendaItem,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 안건 목록
        Expanded(
          child: agendaAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    '등록된 안건이 없습니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final totalMinutes =
                  items.fold<int>(0, (sum, i) => sum + i.durationMinutes);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md, vertical: AppSizes.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '총 ${items.length}건',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '예상 소요: $totalMinutes분',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) =>
                          _reorder(items, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          key: ValueKey(item.id),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(item.title),
                            subtitle: Row(
                              children: [
                                Text(
                                  '${item.durationMinutes}분',
                                ),
                                if (item.presenterName !=
                                    null) ...[
                                  const Text(
                                    ' · ',
                                  ),
                                  Flexible(
                                    child: Text(
                                      item.presenterName!,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20),
                              onPressed: () => ref
                                  .read(meetingAgendaProvider(
                                          widget.meetingId)
                                      .notifier)
                                  .deleteAgendaItem(item.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }

  Future<void> _addAgendaItem() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final agendaItems =
        ref.read(meetingAgendaProvider(widget.meetingId)).valueOrNull ?? [];

    final item = MeetingAgenda(
      id: '',
      meetingId: widget.meetingId,
      orderIndex: agendaItems.length,
      title: title,
      durationMinutes: int.tryParse(_durationController.text) ?? 10,
    );

    await ref
        .read(meetingAgendaProvider(widget.meetingId).notifier)
        .createAgendaItem(item);
    _titleController.clear();
  }

  Future<void> _reorder(
      List<MeetingAgenda> items, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<MeetingAgenda>.from(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    final updates = <Map<String, dynamic>>[];
    for (int i = 0; i < reordered.length; i++) {
      updates.add({'id': reordered[i].id, 'order_index': i});
    }

    await ref
        .read(meetingAgendaProvider(widget.meetingId).notifier)
        .updateOrder(updates);
  }
}

// ─── Tab 4: Minutes ───

class _MinutesTab extends ConsumerStatefulWidget {
  const _MinutesTab({required this.meeting});
  final Meeting meeting;

  @override
  ConsumerState<_MinutesTab> createState() =>
      _MinutesTabState();
}

class _MinutesTabState
    extends ConsumerState<_MinutesTab> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isRegenerating = false;
  bool _isExtractingTasks = false;
  late TextEditingController _notesController;

  Meeting get meeting => widget.meeting;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: meeting.meetingNotes ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _MinutesTab old) {
    super.didUpdateWidget(old);
    if (old.meeting.meetingNotes !=
            meeting.meetingNotes &&
        !_isEditing) {
      _notesController.text =
          meeting.meetingNotes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 회의록이 있으면 표시
    if (meeting.meetingNotes != null &&
        meeting.meetingNotes!.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // 헤더: 제목 + 버튼들
            Row(
              children: [
                Text(
                  '회의록',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (kIsWeb)
                  IconButton(
                    onPressed: _downloadMinutes,
                    icon: const Icon(
                      Icons.download,
                      size: 20,
                    ),
                    tooltip: '마크다운 다운로드',
                  ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        // 취소 시 원래 값으로
                        _notesController.text =
                            meeting.meetingNotes ??
                                '';
                      }
                    });
                  },
                  icon: Icon(
                    _isEditing
                        ? Icons.close
                        : Icons.edit,
                    size: 20,
                  ),
                  tooltip:
                      _isEditing ? '취소' : '편집',
                ),
                // AI 재작성 버튼 (원문이 있을 때만)
                if (meeting.rawTranscript !=
                        null &&
                    meeting.rawTranscript!
                        .isNotEmpty)
                  TextButton.icon(
                    onPressed: _isRegenerating
                        ? null
                        : () => _confirmRegenerate(
                              context,
                            ),
                    icon: _isRegenerating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 16,
                          ),
                    label: Text(
                      _isRegenerating
                          ? 'AI 재작성 중...'
                          : 'AI 재작성',
                    ),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      _startRecording(context),
                  icon: const Icon(
                    Icons.mic,
                    size: 16,
                  ),
                  label: const Text('다시 녹음'),
                ),
                TextButton.icon(
                  onPressed: _isExtractingTasks
                      ? null
                      : _extractTasks,
                  icon: _isExtractingTasks
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.assignment,
                          size: 16,
                        ),
                  label: Text(
                    _isExtractingTasks
                        ? '추출 중...'
                        : '업무 추출',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(
                  AppSizes.md,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '회의명: ${meeting.title}',
                      style: theme
                          .textTheme.bodyMedium,
                    ),
                    const SizedBox(
                      height: AppSizes.xs,
                    ),
                    Text(
                      '일시: ${_formatDate(meeting.meetingDate)}',
                      style: theme
                          .textTheme.bodyMedium,
                    ),
                    if (meeting.location !=
                        null) ...[
                      const SizedBox(
                        height: AppSizes.xs,
                      ),
                      Text(
                        '장소: ${meeting.location}',
                        style: theme
                            .textTheme.bodyMedium,
                      ),
                    ],
                    const Divider(),
                    if (_isEditing) ...[
                      TextField(
                        controller:
                            _notesController,
                        maxLines: null,
                        minLines: 10,
                        decoration:
                            const InputDecoration(
                          border:
                              OutlineInputBorder(),
                          hintText: '회의록 내용...',
                        ),
                      ),
                      const SizedBox(
                        height: AppSizes.sm,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child:
                            FilledButton.icon(
                          onPressed: _isSaving
                              ? null
                              : _saveEdited,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors
                                            .white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save,
                                ),
                          label: Text(
                            _isSaving
                                ? '저장 중...'
                                : '회의록 저장',
                          ),
                        ),
                      ),
                    ] else
                      SelectableText(
                        meeting.meetingNotes!,
                        style: theme
                            .textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),

            // 원문 텍스트 (접을 수 있게)
            if (meeting.rawTranscript != null &&
                meeting
                    .rawTranscript!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              ExpansionTile(
                title: Text(
                  '녹음 원문',
                  style:
                      theme.textTheme.titleSmall,
                ),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.all(
                      AppSizes.md,
                    ),
                    child: SelectableText(
                      meeting.rawTranscript!,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: theme.colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // 회의록 없음 — 녹음 안내
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_none,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            '회의를 녹음하고 AI로 회의록을 생성하세요',
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          FilledButton.icon(
            onPressed: () =>
                _startRecording(context),
            icon: const Icon(Icons.mic),
            label: const Text('녹음 시작'),
          ),
        ],
      ),
    );
  }

  Future<void> _extractTasks() async {
    setState(
      () => _isExtractingTasks = true,
    );

    try {
      final dt = meeting.meetingDate;
      final dateStr = '${dt.year}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.day.toString().padLeft(2, '0')}';

      final notifier =
          ref.read(recordingProvider.notifier);

      await notifier.extractTasksFromMinutes(
        minutesText: meeting.meetingNotes!,
        meetingId: meeting.id,
        meetingTitle: meeting.title,
        meetingDate: dateStr,
        rawTranscript: meeting.rawTranscript,
      );

      if (!mounted) return;
      final state = ref.read(recordingProvider);
      if (state.minutesResult != null) {
        context.push(
          '/meetings/${meeting.id}'
          '/minutes-result',
        );
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '업무 추출 실패: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isExtractingTasks = false,
        );
      }
    }
  }

  Future<void> _confirmRegenerate(
    BuildContext context,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 재작성'),
        content: const Text(
          '녹음 원문을 기반으로 회의록을 다시 '
          '생성합니다.\n\n'
          '기존 회의록은 새 결과로 교체됩니다.\n'
          '계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, true),
            child: const Text('재작성'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    await _regenerateMinutes();
  }

  Future<void> _regenerateMinutes() async {
    setState(() => _isRegenerating = true);

    try {
      final dt = meeting.meetingDate;
      final dateStr = '${dt.year}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.day.toString().padLeft(2, '0')}';

      final notifier =
          ref.read(recordingProvider.notifier);

      await notifier.regenerateMinutes(
        rawTranscript: meeting.rawTranscript!,
        meetingId: meeting.id,
        meetingTitle: meeting.title,
        meetingDate: dateStr,
        projectTitle: meeting.projectTitle,
      );

      if (!mounted) return;
      final state = ref.read(recordingProvider);
      if (state.minutesResult != null) {
        context.push(
          '/meetings/${meeting.id}'
          '/minutes-result',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _saveEdited() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(meetingRepositoryProvider)
          .saveMeetingNotes(
            meeting.id,
            meetingNotes:
                _notesController.text.trim(),
          );
      ref.invalidate(
        meetingDetailProvider(meeting.id),
      );
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회의록이 저장되었습니다'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _downloadMinutes() async {
    final now = meeting.meetingDate;
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer();
    buf.writeln('# ${meeting.title}');
    buf.writeln();
    buf.writeln('- 일시: $dateStr');
    if (meeting.location != null) {
      buf.writeln('- 장소: ${meeting.location}');
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.writeln('## 회의록');
    buf.writeln();
    buf.writeln(
      _isEditing
          ? _notesController.text.trim()
          : (meeting.meetingNotes ?? ''),
    );
    buf.writeln();

    final bytes = utf8.encode(buf.toString());
    final fileName =
        '회의록_${dateStr}_${meeting.title}.md'
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('파일이 다운로드되었습니다'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 실패: $e'),
          ),
        );
      }
    }
  }

  void _startRecording(BuildContext context) {
    final rec = ref.read(recordingProvider);
    if (rec.isFloatingVisible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 녹음 중입니다'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final dt = meeting.meetingDate;
    ref
        .read(recordingProvider.notifier)
        .activate(
          meetingId: meeting.id,
          meetingTitle: meeting.title,
          meetingDate: '${dt.year}.'
              '${dt.month.toString().padLeft(2, '0')}.'
              '${dt.day.toString().padLeft(2, '0')}',
          projectTitle: meeting.projectTitle,
        );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Shared Widgets ───

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MeetingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MeetingStatus.preparing => AppColors.warning,
      MeetingStatus.notified => AppColors.info,
      MeetingStatus.inProgress => AppColors.inProgress,
      MeetingStatus.completed => AppColors.done,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final MeetingType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});
  final MeetingMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (mode) {
      MeetingMode.inPerson => (
          Icons.groups,
          AppColors.done
        ),
      MeetingMode.online => (
          Icons.videocam,
          AppColors.info
        ),
      MeetingMode.hybrid => (
          Icons.desktop_windows,
          AppColors.warning
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            mode.label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}


