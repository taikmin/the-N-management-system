import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// 통합 캘린더 이벤트 유형
enum CalendarEventType {
  task('업무', AppColors.primary, Icons.task_alt);

  const CalendarEventType(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

/// 통합 캘린더 이벤트 모델 (호텔 도메인: tasks 마감일 기반)
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.endDate,
    this.subtitle,
    this.isAllDay = false,
    this.isDelayed = false,
    this.routePath,
  });

  final String id;
  final CalendarEventType type;
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String? subtitle;
  final bool isAllDay;
  final bool isDelayed;

  /// 탭하면 이동할 경로 (예: /tasks/xxx)
  final String? routePath;

  Color get color => isDelayed ? AppColors.error : type.color;

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(date.year, date.month, date.day);
    if (endDate == null) return d == start;
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}
