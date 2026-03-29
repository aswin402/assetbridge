import 'package:flutter/material.dart';

class PackSidebarRow extends StatelessWidget {
  const PackSidebarRow({
    super.key,
    required this.title,
    required this.countLabel,
    required this.enabled,
    required this.onChanged,
    this.onDelete,
  });

  final String title;
  final String countLabel;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      child: CheckboxListTile(
        value: enabled,
        onChanged: onChanged,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: colorScheme.primary,
        checkColor: colorScheme.onPrimary,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: enabled ? FontWeight.w500 : FontWeight.w400,
            color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              countLabel,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                color: colorScheme.error.withValues(alpha: 0.5),
                hoverColor: colorScheme.errorContainer,
                tooltip: 'Remove',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

