import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int versionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool mandatory;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    this.mandatory = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['version'] as String? ?? '1.0.0',
      versionCode: json['version_code'] as int? ?? 1,
      apkUrl: json['apk_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class AppUpdateManager {
  static const String currentVersion = '8.6.0';
  static const int currentVersionCode = 86;
  static const String versionCheckUrl = 'https://raw.githubusercontent.com/mohamedabdalhamied139/letsfly_mobile/main/version.json';

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateNotice = false}) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        versionCheckUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        final updateInfo = AppUpdateInfo.fromJson(data);

        if (updateInfo.versionCode > currentVersionCode) {
          if (context.mounted) {
            _showUpdateDialog(context, updateInfo);
          }
        } else if (showNoUpdateNotice && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أنت تستخدم أحدث إصدار بالفعل.')),
          );
        }
      }
    } catch (_) {
      // Gracefully ignore network errors on silent check
    }
  }

  static void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (ctx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;
        String statusText = '';

        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('تحديث جديد متوفر ()'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.releaseNotes.isNotEmpty
                        ? info.releaseNotes
                        : 'يتوفر تحديث جديد لتطبيق Let\'s Fly، يرجى التحديث الآن للحصول على أحدث الميزات والإصلاحات.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (isDownloading) ...[
                    LinearProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress : null,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText.isNotEmpty ? statusText : 'جاري التحميل... %',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!info.mandatory && !isDownloading)
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('تخطي'),
                  ),
                if (!isDownloading)
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        isDownloading = true;
                        statusText = 'جاري التحميل...';
                      });
                      try {
                        final dio = Dio();
                        await dio.download(
                          info.apkUrl,
                          '/sdcard/Download/letsfly_update_.apk',
                          onReceiveProgress: (received, total) {
                            if (total != -1) {
                              setState(() {
                                downloadProgress = received / total;
                              });
                            }
                          },
                        );
                        setState(() {
                          statusText = 'تم التحميل بنجاح! يرجى فتح ملف التثبيت.';
                        });
                      } catch (e) {
                        setState(() {
                          statusText = 'تعذر التثبيت التلقائي. يرجى إعادة المحاولة.';
                          isDownloading = false;
                        });
                      }
                    },
                    child: const Text('تحديث الآن'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
