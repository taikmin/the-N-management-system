import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/department.dart';

/// 부서 카드 (목록에서 사용)
class DepartmentCard extends StatelessWidget {
  const DepartmentCard({
    super.key,
    required this.department,
    this.memberCount,
    this.taskCount,
    this.onTap,
    this.onLongPress,
  });

  final Department department;
  final int? memberCount;
  final int? taskCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  Color get _color {
    final hex = department.color.replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0x0ABAB5;
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.business_outlined, color: _color, size: 22),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (department.description != null &&
                        department.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        department.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        if (department.leadName != null)
                          _MetaChip(
                            icon: Icons.person_outline,
                            label: '팀장 ${department.leadName}',
                          ),
                        if (memberCount != null) ...[
                          const SizedBox(width: AppSizes.xs),
                          _MetaChip(
                            icon: Icons.groups_outlined,
                            label: '$memberCount명',
                          ),
                        ],
                        if (taskCount != null) ...[
                          const SizedBox(width: AppSizes.xs),
                          _MetaChip(
                            icon: Icons.task_alt_outlined,
                            label: '$taskCount건',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
