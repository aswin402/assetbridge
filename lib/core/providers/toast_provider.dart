import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum ToastType { error, success, info }

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.message,
    this.type = ToastType.info,
    this.duration = const Duration(seconds: 4),
    this.createdAt,
  });

  final String id;
  final String message;
  final ToastType type;
  final Duration duration;
  final DateTime? createdAt;

  ToastMessage copyWith({
    String? id,
    String? message,
    ToastType? type,
    Duration? duration,
    DateTime? createdAt,
  }) {
    return ToastMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

final toastProvider = NotifierProvider<ToastNotifier, List<ToastMessage>>(ToastNotifier.new);

class ToastNotifier extends Notifier<List<ToastMessage>> {
  @override
  List<ToastMessage> build() => [];

  void show(String message, {ToastType type = ToastType.info, Duration? duration}) {
    final id = const Uuid().v4();
    final toast = ToastMessage(
      id: id,
      message: message,
      type: type,
      duration: duration ?? (type == ToastType.error ? const Duration(seconds: 6) : const Duration(seconds: 4)),
      createdAt: DateTime.now(),
    );

    state = [...state, toast];

    // Auto-dismiss
    Future.delayed(toast.duration, () {
      dismiss(id);
    });
  }

  void dismiss(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void error(String message) => show(message, type: ToastType.error);
  void success(String message) => show(message, type: ToastType.success);
}
