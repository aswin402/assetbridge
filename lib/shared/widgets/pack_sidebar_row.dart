import 'package:flutter/material.dart';

class PackSidebarRow extends StatelessWidget {
  const PackSidebarRow({
    super.key,
    required this.title,
    required this.countLabel,
    required this.selected,
    required this.onTap,
    this.onDelete,
    this.onRescan,
    this.showIcon = true,
  });

  final String title;
  final String countLabel;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRescan;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: colorScheme.primary.withValues(alpha: 0.05),
          highlightColor: colorScheme.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                if (showIcon) ...[
                  Icon(
                    selected ? Icons.folder_open_rounded : Icons.folder_outlined,
                    size: 16,
                    color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  countLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? colorScheme.primary.withValues(alpha: 0.7) : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                if (onRescan != null) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: onRescan,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    color: colorScheme.primary.withValues(alpha: 0.6),
                    hoverColor: colorScheme.primaryContainer,
                    tooltip: 'Rescan for new files',
                  ),
                ],
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
        ),
      ),
    );
  }
}

