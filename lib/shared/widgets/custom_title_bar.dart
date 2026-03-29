import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../shared/theme/theme_mode_provider.dart';

/// Drop-in custom title bar with drag, minimize, maximize, close.
/// Place at the very top of your Scaffold body, above everything else.
class CustomTitleBar extends ConsumerStatefulWidget {
  const CustomTitleBar({super.key});

  @override
  ConsumerState<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends ConsumerState<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 44,
        color: isDark
            ? colorScheme.surface
            : colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            const SizedBox(width: 16),
            // App icon / name
            Text(
              'AssetBridge',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: -0.3,
              ),
            ),
            // Drag area fills remaining space
            const Expanded(child: SizedBox.expand()),
            // Theme toggle integrated into title bar
            IconButton(
              onPressed: () {
                final isDarkNow = Theme.of(context).brightness == Brightness.dark;
                ref.read(themeModeProvider.notifier).setThemeMode(
                      isDarkNow ? ThemeMode.light : ThemeMode.dark,
                    );
              },
              icon: Icon(
                Theme.of(context).brightness == Brightness.light
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              tooltip: 'Toggle Theme',
            ),
            const VerticalDivider(width: 1, indent: 12, endIndent: 12),
            // Window controls
            _TitleBarButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onPressed: () => windowManager.minimize(),
            ),
            _TitleBarButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded   // restore icon
                  : Icons.crop_square_rounded,  // maximize icon
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _TitleBarButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color hoverColor;
    Color iconColor;

    if (widget.isClose) {
      hoverColor = Colors.red;
      iconColor = _hovered ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.6);
    } else {
      hoverColor = colorScheme.onSurface.withValues(alpha: 0.1);
      iconColor = colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hovered ? hoverColor : Colors.transparent,
            ),
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
