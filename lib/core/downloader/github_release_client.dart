import 'package:dio/dio.dart';

/// Minimal GitHub Releases API client (unauthenticated; rate limits apply).
class GitHubReleaseClient {
  GitHubReleaseClient(this._dio);

  final Dio _dio;

  static const _accept = 'application/vnd.github+json';

  /// Latest release for [owner]/[repo], or `null` if none.
  Future<GitHubRelease?> fetchLatestRelease({
    required String owner,
    required String repo,
    CancelToken? cancelToken,
  }) async {
    final url = 'https://api.github.com/repos/$owner/$repo/releases/latest';
    final response = await _dio.get<Map<String, dynamic>>(
      url,
      cancelToken: cancelToken,
      options: Options(
        headers: {'Accept': _accept},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200 || response.data == null) {
      throw GitHubApiException(
        'GitHub API error ${response.statusCode} for $url',
      );
    }
    return GitHubRelease.fromJson(response.data!);
  }
}

class GitHubApiException implements Exception {
  GitHubApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GitHubRelease {
  GitHubRelease({
    required this.tagName,
    required this.htmlUrl,
    required this.zipballUrl,
    required this.assets,
  });

  final String tagName;
  final String htmlUrl;
  final String zipballUrl;
  final List<GitHubReleaseAsset> assets;

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'] as List<dynamic>? ?? const [];
    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      zipballUrl: json['zipball_url'] as String? ?? '',
      assets: rawAssets
          .map((e) => GitHubReleaseAsset.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GitHubReleaseAsset {
  GitHubReleaseAsset({required this.name, required this.browserDownloadUrl, required this.size});

  final String name;
  final String browserDownloadUrl;
  final int size;

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}
