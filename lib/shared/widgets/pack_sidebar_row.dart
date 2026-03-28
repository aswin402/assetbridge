import 'package:flutter/material.dart';

class PackSidebarRow extends StatelessWidget {
  const PackSidebarRow({
    super.key,
    required this.title,
    required this.countLabel,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String countLabel;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: enabled,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      secondary: Text(
        countLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
