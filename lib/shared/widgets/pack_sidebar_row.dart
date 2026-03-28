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
    return CheckboxListTile(
      value: enabled,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            countLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
              tooltip: 'Delete pack',
            ),
          ],
        ],
      ),
    );
  }
}
