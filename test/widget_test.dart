import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_management/core/constants/app_strings.dart';
import 'package:hotel_management/features/tasks/domain/models/task.dart';
import 'package:hotel_management/features/tasks/domain/models/daily_log.dart';
import 'package:hotel_management/features/tasks/domain/models/task_comment.dart';
import 'package:hotel_management/core/constants/app_colors.dart';
import 'package:hotel_management/features/calendar/domain/models/calendar_event.dart';

void main() {
  // ─── Auth Models ───



  // ─── Task Model ───

  group('Task', () {
    test('should create from JSON', () {
      final json = {
        'id': 'task-1',
        'project_id': 'proj-1',
        'title': '센서 모듈 설계',
        'status': 'in_progress',
        'priority': 'high',
        'plan_type': 'A',
        'planned_start': '2026-02-01',
        'planned_end': '2026-03-01',
        'order_index': 1,
        'profiles': {'full_name': '김연구'},
      };

      final task = Task.fromJson(json);

      expect(task.id, 'task-1');
      expect(task.title, '센서 모듈 설계');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.high);
      expect(task.planType, PlanType.a);
      expect(task.assigneeName, '김연구');
    });

    test('should detect delayed tasks', () {
      final delayed = Task(
        id: '1',
        projectId: 'p1',
        title: '지연 태스크',
        status: TaskStatus.inProgress,
        plannedEnd: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(delayed.isDelayed, true);
      expect(delayed.delayDays, 5);
    });

    test('completed task should not be delayed', () {
      final completed = Task(
        id: '2',
        projectId: 'p1',
        title: '완료 태스크',
        status: TaskStatus.completed,
        plannedEnd: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(completed.isDelayed, false);
    });

    test('should detect today tasks', () {
      final todayTask = Task(
        id: '3',
        projectId: 'p1',
        title: '오늘 태스크',
        plannedEnd: DateTime.now(),
      );
      expect(todayTask.isDueToday, true);
    });

    test('should parse all status values', () {
      expect(TaskStatus.fromString('planned'), TaskStatus.planned);
      expect(TaskStatus.fromString('in_progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('delayed'), TaskStatus.delayed);
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
      expect(TaskStatus.fromString('blocked'), TaskStatus.blocked);
    });

    test('should parse all priority values', () {
      expect(TaskPriority.fromString('low'), TaskPriority.low);
      expect(TaskPriority.fromString('medium'), TaskPriority.medium);
      expect(TaskPriority.fromString('high'), TaskPriority.high);
      expect(TaskPriority.fromString('urgent'), TaskPriority.urgent);
    });

    test('should parse Plan types', () {
      expect(PlanType.fromString('A'), PlanType.a);
      expect(PlanType.fromString('B'), PlanType.b);
      expect(PlanType.fromString('C'), PlanType.c);
      expect(PlanType.fromString('a'), PlanType.a);
    });

    test('should produce correct toInsertJson', () {
      final task = Task(
        id: '1',
        projectId: 'p1',
        title: '태스크',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        planType: PlanType.b,
      );
      final json = task.toInsertJson();
      expect(json['status'], 'in_progress');
      expect(json['priority'], 'high');
      expect(json['plan_type'], 'B');
    });
  });

  // ─── DailyLog Model ───

  group('DailyLog', () {
    test('should create from JSON', () {
      final json = {
        'id': 'log-1',
        'task_id': 'task-1',
        'author_id': 'user-1',
        'log_date': '2026-02-22',
        'content': '센서 회로 설계 완료',
        'issues': 'PCB 납품 지연',
        'next_plan': '소프트웨어 테스트',
        'profiles': {'full_name': '박연구'},
      };

      final log = DailyLog.fromJson(json);
      expect(log.content, '센서 회로 설계 완료');
      expect(log.issues, 'PCB 납품 지연');
      expect(log.authorName, '박연구');
    });

    test('should produce toInsertJson', () {
      final log = DailyLog(
        id: '',
        taskId: 'task-1',
        authorId: 'user-1',
        logDate: DateTime(2026, 2, 22),
        content: '작업 완료',
      );
      final json = log.toInsertJson();
      expect(json['task_id'], 'task-1');
      expect(json['log_date'], '2026-02-22');
    });
  });

  // ─── TaskComment Model ───

  group('TaskComment', () {
    test('should create from JSON', () {
      final json = {
        'id': 'comment-1',
        'task_id': 'task-1',
        'author_id': 'user-1',
        'content': '잘 진행되고 있습니다',
        'profiles': {'full_name': '홍길동'},
        'created_at': '2026-02-22T10:30:00Z',
      };

      final comment = TaskComment.fromJson(json);
      expect(comment.content, '잘 진행되고 있습니다');
      expect(comment.authorName, '홍길동');
    });
  });

  // ─── CalendarEvent Model ───

  group('CalendarEvent', () {
    test('should create with correct properties', () {
      final event = CalendarEvent(
        id: 'evt-1',
        type: CalendarEventType.task,
        title: '진도점검회의',
        date: DateTime(2026, 3, 15, 14, 0),
        subtitle: '진도점검 · 준비중',
        routePath: '/tasks/m1',
      );

      expect(event.id, 'evt-1');
      expect(event.type, CalendarEventType.task);
      expect(event.title, '진도점검회의');
      expect(event.routePath, '/tasks/m1');
      expect(event.isAllDay, false);
      expect(event.isDelayed, false);
    });

    test('should use type color when not delayed', () {
      final event = CalendarEvent(
        id: '1',
        type: CalendarEventType.task,
        title: '태스크',
        date: DateTime(2026, 3, 15),
      );
      expect(event.color, CalendarEventType.task.color);
    });

    test('should use error color when delayed', () {
      final event = CalendarEvent(
        id: '2',
        type: CalendarEventType.task,
        title: '지연 태스크',
        date: DateTime(2026, 3, 15),
        isDelayed: true,
      );
      expect(event.color, AppColors.error);
    });

    test('should detect single-day event occurrence', () {
      final event = CalendarEvent(
        id: '1',
        type: CalendarEventType.task,
        title: '회의',
        date: DateTime(2026, 3, 15),
      );

      expect(event.occursOn(DateTime(2026, 3, 15)), true);
      expect(event.occursOn(DateTime(2026, 3, 14)), false);
      expect(event.occursOn(DateTime(2026, 3, 16)), false);
    });

    test('should detect range event occurrence', () {
      final event = CalendarEvent(
        id: '1',
        type: CalendarEventType.project,
        title: '과제',
        date: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        isAllDay: true,
      );

      expect(event.occursOn(DateTime(2026, 3, 1)), true);
      expect(event.occursOn(DateTime(2026, 3, 15)), true);
      expect(event.occursOn(DateTime(2026, 3, 31)), true);
      expect(event.occursOn(DateTime(2026, 2, 28)), false);
      expect(event.occursOn(DateTime(2026, 4, 1)), false);
    });

    test('should ignore time when checking occurrence', () {
      final event = CalendarEvent(
        id: '1',
        type: CalendarEventType.task,
        title: '오후 회의',
        date: DateTime(2026, 3, 15, 14, 30),
      );

      // 같은 날짜라면 시간 관계없이 true
      expect(event.occursOn(DateTime(2026, 3, 15, 9, 0)), true);
      expect(event.occursOn(DateTime(2026, 3, 15, 0, 0)), true);
    });
  });

  group('CalendarEventType', () {
    test('should have correct labels', () {
      expect(CalendarEventType.project.label, '과제');
      expect(CalendarEventType.task.label, '태스크');
    });

    test('should have distinct colors', () {
      final colors = CalendarEventType.values.map((t) => t.color).toSet();
      expect(colors.length, CalendarEventType.values.length);
    });
  });

  // ─── Constants ───

  group('AppStrings', () {
    test('should have non-empty app name', () {
      expect(AppStrings.appName.isNotEmpty, true);
    });

    test('should have calendar string', () {
      expect(AppStrings.calendar, '캘린더');
    });
  });
}
