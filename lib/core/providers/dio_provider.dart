import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared HTTP client (GitHub API + release zip downloads).
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'AssetBridge/1.0',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );
});
