import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../projects/providers/project_provider.dart';
import '../../domain/models/meeting.dart';
import '../../domain/models/meeting_timeline.dart';
import '../../providers/meeting_provider.dart';

const _onlinePlatforms = [
  'Zoom',
  'Google Meet',
  'Microsoft Teams',
  'Webex',
  '기타',
];

class MeetingCreateScreen extends ConsumerStatefulWidget {
  const MeetingCreateScreen({
    super.key,
    this.projectId,
    this.meeting,
  });

  final String? projectId;
  final Meeting? meeting;

  @override
  ConsumerState<MeetingCreateScreen> createState() =>
      _MeetingCreateScreenState();
}

class _MeetingCreateScreenState
    extends ConsumerState<MeetingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _roomController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _attendeesController;
  late final TextEditingController
      _mealLocationController;

  late MeetingType _meetingType;
  late MeetingMode _meetingMode;
  late DateTime _meetingDate;
  late TimeOfDay _meetingTime;
  late bool _mealReservation;
  bool _autoTimeline = true;
  String? _selectedProjectId;
  bool _isLoading = false;
  final List<MeetingTimeline> _importedTimelines = [];

  late final TextEditingController
      _onlineLinkController;
  late final TextEditingController
      _onlineMeetingIdController;
  late final TextEditingController
      _onlinePasswordController;
  String? _onlinePlatform;

  bool get _isEditing => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    _selectedProjectId =
        m?.projectId ?? widget.projectId;
    _meetingType =
        m?.meetingType ?? MeetingType.progressCheck;
    _meetingMode =
        m?.meetingMode ?? MeetingMode.inPerson;
    _meetingDate = m?.meetingDate ??
        DateTime.now().add(const Duration(days: 14));
    _meetingTime = m != null
        ? TimeOfDay(
            hour: m.meetingDate.hour,
            minute: m.meetingDate.minute,
          )
        : const TimeOfDay(hour: 14, minute: 0);
    _mealReservation = m?.mealReservation ?? false;
    _titleController =
        TextEditingController(text: m?.title ?? '');
    _locationController =
        TextEditingController(text: m?.location ?? '');
    _roomController =
        TextEditingController(text: m?.roomName ?? '');
    _descriptionController = TextEditingController(
        text: m?.description ?? '');
    _attendeesController = TextEditingController(
      text: m != null && m.expectedAttendees > 0
          ? '${m.expectedAttendees}'
          : '',
    );
    _mealLocationController = TextEditingController(
        text: m?.mealLocation ?? '');
    _onlineLinkController = TextEditingController(
        text: m?.onlineLink ?? '');
    _onlineMeetingIdController =
        TextEditingController(
            text: m?.onlineMeetingId ?? '');
    _onlinePasswordController =
        TextEditingController(
            text: m?.onlinePassword ?? '');
    _onlinePlatform = m?.onlinePlatform;

    // Zoom 기본값 적용 (신규 생성 시)
    if (!_isEditing) {
      Future.microtask(() {
        final user = ref
            .read(currentUserProvider)
            .valueOrNull;
        if (user != null &&
            user.defaultZoomLink != null) {
          _onlineLinkController.text =
              user.defaultZoomLink!;
          _onlineMeetingIdController.text =
              user.defaultZoomId ?? '';
          _onlinePasswordController.text =
              user.defaultZoomPassword ?? '';
          _onlinePlatform ??= 'Zoom';
        }
      });
    }

    if (_isEditing) _autoTimeline = false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _roomController.dispose();
    _descriptionController.dispose();
    _attendeesController.dispose();
    _mealLocationController.dispose();
    _onlineLinkController.dispose();
    _onlineMeetingIdController.dispose();
    _onlinePasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date != null) {
      setState(() => _meetingDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _meetingTime,
    );
    if (time != null) {
      setState(() => _meetingTime = time);
    }
  }

  DateTime get _fullMeetingDateTime => DateTime(
        _meetingDate.year,
        _meetingDate.month,
        _meetingDate.day,
        _meetingTime.hour,
        _meetingTime.minute,
      );

  void _showLoadPreviousMeetingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) =>
            _CreateScreenMeetingPicker(
          scrollController: scrollCtrl,
          onMeetingSelected: (meeting, timelines) {
            setState(() {
              // 폼 필드 채우기
              _titleController.text = meeting.title;
              _selectedProjectId = meeting.projectId;
              _meetingType = meeting.meetingType;
              _meetingMode = meeting.meetingMode;
              if (meeting.location != null) {
                _locationController.text =
                    meeting.location!;
              }
              if (meeting.roomName != null) {
                _roomController.text =
                    meeting.roomName!;
              }
              if (meeting.description != null) {
                _descriptionController.text =
                    meeting.description!;
              }
              _attendeesController.text =
                  meeting.expectedAttendees > 0
                      ? '${meeting.expectedAttendees}'
                      : '';
              _mealReservation =
                  meeting.mealReservation;
              if (meeting.mealLocation != null) {
                _mealLocationController.text =
                    meeting.mealLocation!;
              }
              // 온라인 설정
              _onlinePlatform =
                  meeting.onlinePlatform;
              if (meeting.onlineLink != null) {
                _onlineLinkController.text =
                    meeting.onlineLink!;
              }
              if (meeting.onlineMeetingId != null) {
                _onlineMeetingIdController.text =
                    meeting.onlineMeetingId!;
              }
              if (meeting.onlinePassword != null) {
                _onlinePasswordController.text =
                    meeting.onlinePassword!;
              }
              // 타임라인
              _importedTimelines
                ..clear()
                ..addAll(timelines);
              _autoTimeline = false;
            });
          },
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('과제를 선택해주세요')),
      );
      return;
    }

    final user =
        ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final meeting = Meeting(
        id: widget.meeting?.id ?? '',
        projectId: _selectedProjectId,
        title: _titleController.text.trim(),
        meetingType: _meetingType,
        meetingMode: _meetingMode,
        meetingDate: _fullMeetingDateTime,
        status: widget.meeting?.status ??
            MeetingStatus.preparing,
        location: _locationController.text
                .trim()
                .isNotEmpty
            ? _locationController.text.trim()
            : null,
        roomName:
            _roomController.text.trim().isNotEmpty
                ? _roomController.text.trim()
                : null,
        mealReservation: _mealReservation,
        mealLocation: _mealLocationController.text
                .trim()
                .isNotEmpty
            ? _mealLocationController.text.trim()
            : null,
        expectedAttendees: int.tryParse(
                _attendeesController.text.trim()) ??
            0,
        description: _descriptionController.text
                .trim()
                .isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        onlinePlatform:
            _meetingMode != MeetingMode.inPerson
                ? _onlinePlatform
                : null,
        onlineLink:
            _meetingMode != MeetingMode.inPerson &&
                    _onlineLinkController.text
                        .trim()
                        .isNotEmpty
                ? _onlineLinkController.text.trim()
                : null,
        onlineMeetingId:
            _meetingMode != MeetingMode.inPerson &&
                    _onlineMeetingIdController.text
                        .trim()
                        .isNotEmpty
                ? _onlineMeetingIdController.text
                    .trim()
                : null,
        onlinePassword:
            _meetingMode != MeetingMode.inPerson &&
                    _onlinePasswordController.text
                        .trim()
                        .isNotEmpty
                ? _onlinePasswordController.text
                    .trim()
                : null,
        creatorId:
            widget.meeting?.creatorId ?? user.id,
      );

      if (_isEditing) {
        await ref
            .read(meetingListProvider.notifier)
            .updateMeeting(
                widget.meeting!.id, meeting);
        if (mounted) context.pop();
      } else {
        final created = await ref
            .read(meetingListProvider.notifier)
            .createMeeting(meeting);

        if (_autoTimeline) {
          final milestones =
              MeetingTimeline.generateDefaults(
            meetingId: created.id,
            meetingDate: _fullMeetingDateTime,
          );
          await ref
              .read(meetingTimelineProvider(created.id)
                  .notifier)
              .createTimeline(milestones);
        } else if (_importedTimelines.isNotEmpty) {
          final milestones = _importedTimelines
              .asMap()
              .entries
              .map(
                (e) => MeetingTimeline(
                  id: '',
                  meetingId: created.id,
                  milestone: e.value.milestone,
                  label: e.value.label,
                  dueDate: _fullMeetingDateTime
                      .subtract(
                    Duration(
                      days: (_importedTimelines
                                  .length -
                              1 -
                              e.key) *
                          2,
                    ),
                  ),
                  sortOrder: e.key,
                ),
              )
              .toList();
          await ref
              .read(meetingTimelineProvider(created.id)
                  .notifier)
              .createTimeline(milestones);
        }

        if (mounted) {
          context.pop();
          context.push('/meetings/${created.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync =
        ref.watch(projectListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing ? '회의 수정' : '새 회의 생성'),
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
                  // 이전 회의 불러오기 (새 회의 생성 시에만)
                  if (!_isEditing)
                    OutlinedButton.icon(
                      onPressed:
                          _showLoadPreviousMeetingSheet,
                      icon: const Icon(
                        Icons.content_paste_go,
                        size: 18,
                      ),
                      label: const Text(
                        '이전 회의 불러오기',
                      ),
                    ),
                  if (!_isEditing)
                    const SizedBox(
                      height: AppSizes.md,
                    ),

                  // 과제 선택
                  projectsAsync.when(
                    data: (projects) {
                      return DropdownButtonFormField<
                          String>(
                        initialValue:
                            _selectedProjectId,
                        decoration:
                            const InputDecoration(
                          labelText: '과제 선택 *',
                          prefixIcon: Icon(
                              Icons.science_outlined),
                        ),
                        items: projects.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.title,
                              overflow: TextOverflow
                                  .ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(
                          () =>
                              _selectedProjectId = v,
                        ),
                        validator: (v) => v == null
                            ? '과제를 선택해주세요'
                            : null,
                      );
                    },
                    loading: () =>
                        const LinearProgressIndicator(),
                    error: (e, _) =>
                        Text('과제 로딩 오류: $e'),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 회의명
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '회의명 *',
                      prefixIcon: Icon(
                          Icons.groups_outlined),
                      hintText:
                          '예: 2026년 1차 진도점검회의',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty
                            ? '회의명을 입력해주세요'
                            : null,
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 회의 유형
                  DropdownButtonFormField<MeetingType>(
                    initialValue: _meetingType,
                    decoration: const InputDecoration(
                      labelText: '회의 유형',
                      prefixIcon: Icon(
                          Icons.category_outlined),
                    ),
                    items: MeetingType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(
                            () => _meetingType = v);
                      }
                    },
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 회의 모드 (대면/비대면/하이브리드)
                  Text('회의 방식',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSizes.xs),
                  SegmentedButton<MeetingMode>(
                    segments: MeetingMode.values
                        .map((m) => ButtonSegment(
                              value: m,
                              label: Text(m.label),
                              icon: Icon(_modeIcon(m)),
                            ))
                        .toList(),
                    selected: {_meetingMode},
                    onSelectionChanged: (s) =>
                        setState(
                      () => _meetingMode = s.first,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 온라인 설정 (비대면/하이브리드 시)
                  if (_meetingMode !=
                      MeetingMode.inPerson) ...[
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                                AppSizes.sm),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                  Icons.videocam),
                              title: const Text(
                                  '온라인 회의 설정'),
                            ),
                            Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                horizontal:
                                    AppSizes.md,
                              ),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<
                                      String>(
                                    initialValue:
                                        _onlinePlatform,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          '플랫폼',
                                      prefixIcon: Icon(
                                          Icons
                                              .computer),
                                      isDense: true,
                                    ),
                                    items: _onlinePlatforms
                                        .map(
                                            (p) =>
                                                DropdownMenuItem(
                                                  value:
                                                      p,
                                                  child:
                                                      Text(p),
                                                ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(
                                      () =>
                                          _onlinePlatform =
                                              v,
                                    ),
                                  ),
                                  const SizedBox(
                                      height:
                                          AppSizes
                                              .sm),
                                  TextFormField(
                                    controller:
                                        _onlineLinkController,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          '회의 링크',
                                      prefixIcon: Icon(
                                          Icons.link),
                                      hintText:
                                          'https://...',
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(
                                      height:
                                          AppSizes
                                              .sm),
                                  Row(
                                    children: [
                                      Expanded(
                                        child:
                                            TextFormField(
                                          controller:
                                              _onlineMeetingIdController,
                                          decoration:
                                              const InputDecoration(
                                            labelText:
                                                '회의 ID',
                                            isDense:
                                                true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                          width:
                                              AppSizes
                                                  .sm),
                                      Expanded(
                                        child:
                                            TextFormField(
                                          controller:
                                              _onlinePasswordController,
                                          decoration:
                                              const InputDecoration(
                                            labelText:
                                                '비밀번호',
                                            isDense:
                                                true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                      height:
                                          AppSizes
                                              .sm),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: AppSizes.md),
                  ],

                  // 일시
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _DateTimeField(
                          label: '회의 날짜',
                          value:
                              '${_meetingDate.year}.'
                              '${_meetingDate.month.toString().padLeft(2, '0')}.'
                              '${_meetingDate.day.toString().padLeft(2, '0')}',
                          icon: Icons
                              .calendar_today_outlined,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(
                          width: AppSizes.sm),
                      Expanded(
                        flex: 2,
                        child: _DateTimeField(
                          label: '시간',
                          value:
                              '${_meetingTime.hour.toString().padLeft(2, '0')}:'
                              '${_meetingTime.minute.toString().padLeft(2, '0')}',
                          icon: Icons.access_time,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 장소
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: '장소',
                      prefixIcon: Icon(
                          Icons.location_on_outlined),
                      hintText: '예: 본관 대회의실',
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 회의실
                  TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: '회의실명',
                      prefixIcon: Icon(
                          Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 예상 인원
                  TextFormField(
                    controller: _attendeesController,
                    decoration: const InputDecoration(
                      labelText: '예상 참석인원',
                      prefixIcon: Icon(
                          Icons.people_outline),
                    ),
                    keyboardType:
                        TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 식사 예약
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                          AppSizes.sm),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('식사 예약'),
                            subtitle: const Text(
                                '회의 참석자 식사를 예약합니다'),
                            secondary: const Icon(
                                Icons.restaurant),
                            value: _mealReservation,
                            onChanged: (v) => setState(
                              () =>
                                  _mealReservation = v,
                            ),
                          ),
                          if (_mealReservation) ...[
                            const SizedBox(
                                height: AppSizes.xs),
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    AppSizes.md,
                              ),
                              child: TextFormField(
                                controller:
                                    _mealLocationController,
                                decoration:
                                    const InputDecoration(
                                  labelText: '식사 장소',
                                  hintText:
                                      '예: 구내식당, 외부 식당명',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(
                                height: AppSizes.sm),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // 자동 타임라인 (생성 시에만)
                  if (!_isEditing) ...[
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text(
                              '준비 타임라인 자동 생성',
                            ),
                            subtitle: Text(
                              _autoTimeline
                                  ? 'D-14 양식배포 → D-7 제출마감 → D-3 취합 → D-1 사전검토'
                                  : '수동으로 타임라인을 관리합니다',
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                            secondary: const Icon(
                              Icons.timeline,
                            ),
                            value: _autoTimeline,
                            onChanged: (v) =>
                                setState(
                              () =>
                                  _autoTimeline =
                                      v,
                            ),
                          ),
                          // 불러온 타임라인 미리보기
                          if (_importedTimelines
                              .isNotEmpty) ...[
                            const Divider(
                                height: 1),
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .all(8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '불러온 타임라인 '
                                        '(${_importedTimelines.length}건)',
                                        style: theme
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed:
                                            () =>
                                                setState(
                                          () => _importedTimelines
                                              .clear(),
                                        ),
                                        child:
                                            const Text(
                                          '초기화',
                                        ),
                                      ),
                                    ],
                                  ),
                                  ..._importedTimelines
                                      .map(
                                    (t) =>
                                        Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        vertical:
                                            2,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons
                                                .check_circle_outline,
                                            size:
                                                16,
                                            color:
                                                Colors.grey,
                                          ),
                                          const SizedBox(
                                            width:
                                                8,
                                          ),
                                          Text(
                                            t.label,
                                            style: theme
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: AppSizes.md,
                    ),
                  ],

                  // 설명
                  TextFormField(
                    controller:
                        _descriptionController,
                    decoration: const InputDecoration(
                      labelText: '비고',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSizes.xl),

                  // 제출
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : _handleSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(_isEditing
                            ? Icons.save
                            : Icons.add),
                    label: Text(_isEditing
                        ? '회의 수정'
                        : '회의 생성'),
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

IconData _modeIcon(MeetingMode mode) {
  switch (mode) {
    case MeetingMode.inPerson:
      return Icons.groups;
    case MeetingMode.online:
      return Icons.videocam;
    case MeetingMode.hybrid:
      return Icons.desktop_windows;
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(value),
      ),
    );
  }
}

/// 이전 회의 선택 위젯 (생성 화면용)
class _CreateScreenMeetingPicker
    extends ConsumerStatefulWidget {
  const _CreateScreenMeetingPicker({
    required this.scrollController,
    required this.onMeetingSelected,
  });

  final ScrollController scrollController;
  final void Function(
    Meeting meeting,
    List<MeetingTimeline> timelines,
  ) onMeetingSelected;

  @override
  ConsumerState<_CreateScreenMeetingPicker>
      createState() =>
          _CreateScreenMeetingPickerState();
}

class _CreateScreenMeetingPickerState
    extends ConsumerState<
        _CreateScreenMeetingPicker> {
  List<Map<String, dynamic>>? _meetings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings([
    String? query,
  ]) async {
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(meetingRepositoryProvider)
          .getRecentMeetingsWithTimelineCount(
            searchQuery: query,
          );
      if (mounted) {
        setState(() {
          _meetings = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme
                .colorScheme.onSurfaceVariant
                .withValues(alpha: 0.4),
            borderRadius:
                BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(
            AppSizes.md,
          ),
          child: Text(
            '이전 회의 불러오기',
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '회의명 검색...',
              prefixIcon:
                  Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (val) => _loadMeetings(
              val.isEmpty ? null : val,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _meetings == null ||
                      _meetings!.isEmpty
                  ? Center(
                      child: Text(
                        '회의가 없습니다',
                        style: theme
                            .textTheme.bodyMedium
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: widget
                          .scrollController,
                      itemCount:
                          _meetings!.length,
                      itemBuilder: (ctx, i) {
                        final m = _meetings![i];
                        final id =
                            m['id'] as String;
                        final title = m['title']
                                as String? ??
                            '제목 없음';
                        final dateStr =
                            m['meeting_date']
                                as String?;
                        final date =
                            dateStr != null
                                ? DateTime
                                    .tryParse(
                                    dateStr,
                                  )
                                : null;
                        final timelineData =
                            m['meeting_timeline'];
                        int count = 0;
                        if (timelineData
                            is List) {
                          if (timelineData
                                  .isNotEmpty &&
                              timelineData.first
                                  is Map) {
                            count =
                                (timelineData
                                            .first
                                        as Map)[
                                    'count'] as int? ?? 0;
                          }
                        }

                        return ListTile(
                          title: Text(title),
                          subtitle: Text(
                            '${date != null ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}' : '날짜 미정'}'
                            ' · 타임라인 $count건',
                            style: theme.textTheme
                                .bodySmall,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 20,
                          ),
                          onTap: () =>
                              _loadAndReturn(id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _loadAndReturn(
    String meetingId,
  ) async {
    final repo =
        ref.read(meetingRepositoryProvider);
    final meeting =
        await repo.getMeeting(meetingId);
    final timelines =
        await repo.getTimeline(meetingId);

    if (mounted) {
      widget.onMeetingSelected(
        meeting,
        timelines,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${meeting.title}" 회의 정보를 '
            '불러왔습니다'
            '${timelines.isNotEmpty ? ' (타임라인 ${timelines.length}건)' : ''}',
          ),
        ),
      );
    }
  }
}
