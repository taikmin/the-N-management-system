import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import 'responsive_layout.dart';

/// 반응형 네비게이션 셸
/// 모바일: BottomNavigationBar
/// 태블릿: NavigationRail
/// 데스크톱: NavigationRail + 확장 라벨
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  static const _destinations = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: AppStrings.dashboard,
    ),
    _NavItem(
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      label: AppStrings.departments,
    ),
    _NavItem(
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      label: AppStrings.tasks,
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: AppStrings.calendar,
    ),
    _NavItem(
      icon: Icons.note_alt_outlined,
      selectedIcon: Icons.note_alt,
      label: AppStrings.memos,
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: AppStrings.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _MobileLayout(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        child: child,
      ),
      tablet: _TabletLayout(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        child: child,
      ),
      desktop: _DesktopLayout(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        child: child,
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 모바일: 5탭 + "더보기" BottomSheet
class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  /// 모바일에서 표시할 탭 4개 (0~3) + 더보기(4)
  static const _mobileTabCount = 4;

  /// 현재 선택이 4~6(캘린더/메모/설정)이면 "더보기" 탭 강조
  int get _displayIndex =>
      currentIndex >= _mobileTabCount
          ? _mobileTabCount
          : currentIndex;

  void _showMoreSheet(BuildContext context) {
    final theme = Theme.of(context);
    final moreItems =
        AppNavigationShell._destinations
            .sublist(_mobileTabCount);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSizes.sm),
            ...List.generate(
              moreItems.length,
              (i) {
                final d = moreItems[i];
                final realIndex =
                    _mobileTabCount + i;
                final selected =
                    currentIndex == realIndex;
                return ListTile(
                  leading: Icon(
                    selected
                        ? d.selectedIcon
                        : d.icon,
                    color: selected
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    d.label,
                    style: selected
                        ? TextStyle(
                            color: theme
                                .colorScheme.primary,
                            fontWeight:
                                FontWeight.bold,
                          )
                        : null,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDestinationSelected(
                      realIndex,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSizes.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDest = AppNavigationShell
        ._destinations
        .take(_mobileTabCount)
        .map(
          (d) => NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
        )
        .toList();

    // "더보기" 탭 추가
    visibleDest.add(
      const NavigationDestination(
        icon: Icon(Icons.more_horiz),
        selectedIcon: Icon(Icons.more_horiz),
        label: '더보기',
      ),
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _displayIndex,
        onDestinationSelected: (idx) {
          if (idx == _mobileTabCount) {
            _showMoreSheet(context);
          } else {
            onDestinationSelected(idx);
          }
        },
        destinations: visibleDest,
      ),
    );
  }
}

/// 태블릿: 접힌 NavigationRail
class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            minWidth: AppSizes.navRailWidth,
            destinations: AppNavigationShell._destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 데스크톱: 확장된 NavigationRail
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            extended: true,
            minExtendedWidth: AppSizes.navDrawerWidth,
            destinations: AppNavigationShell._destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
