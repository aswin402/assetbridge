import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/toast_provider.dart';
import 'app_toast.dart';

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);

    return Material(
      child: Stack(
        children: [
          child,
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(toasts.length, (index) {
                    final toast = toasts[index];
                    return AppToast(
                      key: ValueKey(toast.id),
                      id: toast.id,
                      message: toast.message,
                      type: toast.type,
                      onDismiss: () => ref.read(toastProvider.notifier).dismiss(toast.id),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
