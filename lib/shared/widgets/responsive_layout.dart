import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

/// 반응형 레이아웃을 위한 빌더 위젯
/// 모바일 / 태블릿 / 데스크톱 별로 다른 위젯을 표시한다.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppSizes.mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppSizes.mobile && width < AppSizes.desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppSizes.desktop;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppSizes.desktop && desktop != null) {
      return desktop!;
    }
    if (width >= AppSizes.mobile && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}
