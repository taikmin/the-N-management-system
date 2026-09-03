import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_management/core/constants/app_strings.dart';
import 'package:hotel_management/features/auth/domain/models/app_user.dart';
import 'package:hotel_management/features/auth/domain/models/user_role.dart';
import 'package:hotel_management/features/projects/domain/models/project.dart';
import 'package:hotel_management/features/tasks/domain/models/task.dart';
import 'package:hotel_management/features/tasks/domain/models/daily_log.dart';
import 'package:hotel_management/features/tasks/domain/models/task_comment.dart';
import 'package:hotel_management/core/constants/app_colors.dart';
import 'package:hotel_management/features/calendar/domain/models/calendar_event.dart';

void main() {
  // ─── Auth Models ───

  group('AppUser', () {
    test('should create from JSON', () {
      final json = {
        'id': 'test-id',
        'email': 'test@example.com',
        'full_name': '홍길동',
        'department': '로봇메카트로닉스연구실',
        'role': 'pi',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.fullName, '홍길동');
      expect(user.role, UserRole.pi);
    });

    test('should generate correct greeting for PI', () {
      const user = AppUser(
        id: '1',
        email: 'test@example.com',
        fullName: '홍길동',
        role: UserRole.pi,
      );
      expect(user.greeting, '홍길동 책임연구원님, 환영합니다');
    });

    test('should generate correct greeting for researcher', () {
      const user = AppUser(
        id: '2',
        email: 'test@example.com',
        fullName: '김연구',
        role: UserRole.researcher,
      );
      expect(user.greeting, '김연구 연구원님, 환영합니다');
    });

    test('should generate correct greeting for external', () {
      const user = AppUser(
        id: '3',
        email: 'test@example.com',
        fullName: '이외부',
        role: UserRole.external_,
      );
      expect(user.greeting, '이외부님, 환영합니다');
    });

    test('should convert to JSON and back', () {
      const user = AppUser(
        id: '1',
        email: 'test@example.com',
        fullName: '홍길동',
        department: '연구실',
        role: UserRole.pi,
      );

      final json = user.toJson();
      expect(json['id'], '1');
      expect(json['full_name'], '홍길동');
      expect(json['role'], 'pi');
      expect(json['is_admin'], false);
    });

    test('should parse isAdmin from JSON', () {
      final json = {
        'id': 'admin-1',
        'email': 'admin@example.com',
        'full_name': '관리자',
        'role': 'pi',
        'is_admin': true,
      };

      final user = AppUser.fromJson(json);
      expect(user.isAdmin, true);
    });

    test('isAdmin should default to false', () {
      final json = {
        'id': 'user-1',
        'email': 'user@example.com',
        'full_name': '일반유저',
        'role': 'researcher',
      };

      final user = AppUser.fromJson(json);
      expect(user.isAdmin, false);
    });

    test('any authenticated user canEdit/canDelete any resource', () {
      const admin = AppUser(
        id: 'admin-1',
        email: 'admin@example.com',
        fullName: '관리자',
        isAdmin: true,
      );

      expect(admin.canEdit('other-user'), true);
      expect(admin.canDelete('other-user'), true);
      expect(admin.canEdit(null), true);
      expect(admin.canDelete(null), true);

      const user = AppUser(
        id: 'user-1',
        email: 'user@example.com',
        fullName: '일반유저',
      );

      expect(user.canEdit('user-1'), true);
      expect(user.canDelete('user-1'), true);
      expect(user.canEdit('other-user'), true);
      expect(user.canDelete('other-user'), true);
      expect(user.canEdit(null), true);
      expect(user.canDelete(null), true);
    });

    test('copyWith should preserve isAdmin', () {
      const admin = AppUser(
        id: '1',
        email: 'admin@example.com',
        fullName: '관리자',
        isAdmin: true,
      );

      final updated = admin.copyWith(fullName: '새이름');
      expect(updated.isAdmin, true);
      expect(updated.fullName, '새이름');

      final demoted = admin.copyWith(isAdmin: false);
      expect(demoted.isAdmin, false);
    });
  });

  group('UserRole', () {
    test('should parse from string', () {
      expect(UserRole.fromString('pi'), UserRole.pi);
      expect(UserRole.fromString('researcher'), UserRole.researcher);
      expect(UserRole.fromString('external_'), UserRole.external_);
    });

    test('should default to researcher for unknown string', () {
      expect(UserRole.fromString('unknown'), UserRole.researcher);
    });
  });

  // ─── Project Model ───

  group('Project', () {
    test('should create from JSON', () {
      final json = {
        'id': 'proj-1',
        'title': '로봇 제어 시스템 연구',
        'project_number': '2026-R-001',
        'status': 'active',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'total_budget': 500000000,
        'owner_id': 'user-1',
        'lead_institution': '한국기계연구원',
        'co_institutions': ['서울대학교', 'KAIST'],
        'profiles': {'full_name': '박철훈'},
      };

      final project = Project.fromJson(json);

      expect(project.id, 'proj-1');
      expect(project.title, '로봇 제어 시스템 연구');
      expect(project.projectNumber, '2026-R-001');
      expect(project.status, ProjectStatus.active);
      expect(project.totalBudget, 500000000);
      expect(project.ownerName, '박철훈');
      expect(project.coInstitutions.length, 2);
    });

    test('should display budget correctly', () {
      const p1 = Project(
        id: '1',
        title: 't',
        ownerId: 'u',
        totalBudget: 500000000,
      );
      expect(p1.budgetDisplay, '5.0억원');

      const p2 = Project(
        id: '2',
        title: 't',
        ownerId: 'u',
        totalBudget: 50000000,
      );
      expect(p2.budgetDisplay, '5000만원');

      const p3 = Project(id: '3', title: 't', ownerId: 'u', totalBudget: 5000);
      expect(p3.budgetDisplay, '5000원');
    });

    test('should calculate progress by date', () {
      final p = Project(
        id: '1',
        title: 't',
        ownerId: 'u',
        startDate: DateTime.now().subtract(const Duration(days: 50)),
        endDate: DateTime.now().add(const Duration(days: 50)),
      );
      expect(p.progressByDate, closeTo(0.5, 0.05));
    });

    test('should parse all status values', () {
      expect(ProjectStatus.fromString('planning'), ProjectStatus.planning);
      expect(ProjectStatus.fromString('active'), ProjectStatus.active);
      expect(ProjectStatus.fromString('completed'), ProjectStatus.completed);
      expect(ProjectStatus.fromString('on_hold'), ProjectStatus.onHold);
      expect(ProjectStatus.fromString('cancelled'), ProjectStatus.cancelled);
      expect(ProjectStatus.fromString('unknown'), ProjectStatus.planning);
    });

    test('should produce correct toInsertJson', () {
      final p = Project(
        id: '1',
        title: '테스트 과제',
        projectNumber: '2026-T-001',
        ownerId: 'user-1',
        status: ProjectStatus.active,
        totalBudget: 100000000,
      );
      final json = p.toInsertJson();
      expect(json['title'], '테스트 과제');
      expect(json['owner_id'], 'user-1');
      expect(json['status'], 'active');
    });
  });

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
