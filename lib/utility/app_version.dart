import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static String? appVersion;

  static Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;
  }

  static String getVersion() {
    return appVersion ?? 'Unknown';
  }
}

