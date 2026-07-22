import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.releaseUrl,
  });

  final int versionCode;
  final String versionName;
  final String notes;
  final String apkUrl;
  final String releaseUrl;
}

class AppUpdaterService {
  AppUpdaterService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String githubOwner = 'muhammadahmad545-code';
  static const String githubRepo = 'lifeos_ai';

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final int currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

    final Response<dynamic> releaseResponse = await _dio.get<dynamic>(
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest',
      options: Options(
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'LIFEOS-AI-Updater',
        },
      ),
    );

    final Map<String, dynamic> release = Map<String, dynamic>.from(releaseResponse.data as Map<dynamic, dynamic>);
    final List<dynamic> assets = (release['assets'] as List<dynamic>? ?? const <dynamic>[]);
    final String releaseUrl = release['html_url'] as String? ?? '';

    Map<String, dynamic>? versionJson;
    String? apkUrl;

    for (final dynamic asset in assets) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(asset as Map<dynamic, dynamic>);
      final String name = map['name'] as String? ?? '';
      final String url = map['browser_download_url'] as String? ?? '';
      if (name == 'version.json' && url.isNotEmpty) {
        final Response<dynamic> versionResponse = await _dio.get<dynamic>(url);
        versionJson = Map<String, dynamic>.from(versionResponse.data as Map<dynamic, dynamic>);
      } else if (name.endsWith('.apk') && url.isNotEmpty) {
        apkUrl = url;
      }
    }

    if (apkUrl == null) {
      return null;
    }

    final int remoteCode = (versionJson?['versionCode'] as num?)?.toInt() ??
        _versionCodeFromTag(release['tag_name'] as String?);
    final String remoteName = versionJson?['versionName'] as String? ??
        (release['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
    final String notes = (versionJson?['notes'] as String?)?.trim().isNotEmpty == true
        ? versionJson!['notes'] as String
        : (release['body'] as String? ?? 'A new version of LIFEOS AI is available.');

    if (remoteCode <= currentCode) {
      return null;
    }

    return AppUpdateInfo(
      versionCode: remoteCode,
      versionName: remoteName.isEmpty ? 'latest' : remoteName,
      notes: notes,
      apkUrl: apkUrl,
      releaseUrl: releaseUrl,
    );
  }

  int _versionCodeFromTag(String? tag) {
    if (tag == null || tag.isEmpty) {
      return 0;
    }
    final RegExpMatch? match = RegExp(r'(\d+)\s*$').firstMatch(tag);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  Future<File> downloadApk(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/lifeos-ai-${info.versionName}.apk');
    await _dio.download(
      info.apkUrl,
      file.path,
      onReceiveProgress: (int received, int total) {
        if (total > 0) {
          onProgress?.call(received / total);
        }
      },
      options: Options(
        headers: <String, String>{
          'Accept': 'application/octet-stream',
          'User-Agent': 'LIFEOS-AI-Updater',
        },
      ),
    );
    return file;
  }

  Future<bool> ensureInstallPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final PermissionStatus status = await Permission.requestInstallPackages.status;
    if (status.isGranted) {
      return true;
    }
    final PermissionStatus requested = await Permission.requestInstallPackages.request();
    return requested.isGranted;
  }

  Future<OpenResult> installApk(File apkFile) async {
    final bool allowed = await ensureInstallPermission();
    if (!allowed) {
      throw StateError('Install permission is required to update the app.');
    }
    return OpenFilex.open(apkFile.path, type: 'application/vnd.android.package-archive');
  }
}
