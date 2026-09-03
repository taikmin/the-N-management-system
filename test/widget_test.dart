import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_management/core/constants/app_strings.dart';
import 'package:hotel_management/core/constants/app_colors.dart';
import 'package:hotel_management/features/calendar/domain/models/calendar_event.dart';

void main() {
  // ─── Auth Models ───



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
        type: CalendarEventType.task,
        title: '기간 업무',
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
    test('should have correct label', () {
      expect(CalendarEventType.task.label, '업무');
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
