import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// A wrapper widget that provides transparent resize handles on all edges and corners
/// for a frameless window.
class WindowResizer extends StatelessWidget {
  const WindowResizer({
    super.key,
    required this.child,
    this.edgeWidth = 4.0,
    this.cornerWidth = 8.0,
  });

  final Widget child;
  final double edgeWidth;
  final double cornerWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content
        Positioned.fill(child: child),

        // ── Edges ────────────────────────────────────────────────────────────
        // Left
        Positioned(
          left: 0,
          top: cornerWidth,
          bottom: cornerWidth,
          width: edgeWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeLeft,
            onResize: () => windowManager.startResizing(ResizeEdge.left),
          ),
        ),
        // Right
        Positioned(
          right: 0,
          top: cornerWidth,
          bottom: cornerWidth,
          width: edgeWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeRight,
            onResize: () => windowManager.startResizing(ResizeEdge.right),
          ),
        ),
        // Top
        Positioned(
          top: 0,
          left: cornerWidth,
          right: cornerWidth,
          height: edgeWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeUp,
            onResize: () => windowManager.startResizing(ResizeEdge.top),
          ),
        ),
        // Bottom
        Positioned(
          bottom: 0,
          left: cornerWidth,
          right: cornerWidth,
          height: edgeWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeDown,
            onResize: () => windowManager.startResizing(ResizeEdge.bottom),
          ),
        ),

        // ── Corners ──────────────────────────────────────────────────────────
        // Top Left
        Positioned(
          left: 0,
          top: 0,
          width: cornerWidth,
          height: cornerWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeUpLeft,
            onResize: () => windowManager.startResizing(ResizeEdge.topLeft),
          ),
        ),
        // Top Right
        Positioned(
          right: 0,
          top: 0,
          width: cornerWidth,
          height: cornerWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeUpRight,
            onResize: () => windowManager.startResizing(ResizeEdge.topRight),
          ),
        ),
        // Bottom Left
        Positioned(
          left: 0,
          bottom: 0,
          width: cornerWidth,
          height: cornerWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeDownLeft,
            onResize: () => windowManager.startResizing(ResizeEdge.bottomLeft),
          ),
        ),
        // Bottom Right
        Positioned(
          right: 0,
          bottom: 0,
          width: cornerWidth,
          height: cornerWidth,
          child: _ResizeArea(
            cursor: SystemMouseCursors.resizeDownRight,
            onResize: () => windowManager.startResizing(ResizeEdge.bottomRight),
          ),
        ),
      ],
    );
  }
}

class _ResizeArea extends StatelessWidget {
  const _ResizeArea({
    required this.cursor,
    required this.onResize,
  });

  final MouseCursor cursor;
  final VoidCallback onResize;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanStart: (_) => onResize(),
        behavior: HitTestBehavior.translucent,
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
