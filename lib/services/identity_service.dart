import 'dart:io';
import 'dart:ui' as ui;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Service to handle unique device identification and metadata collection.
class IdentityService {
  static const String _installIdKey = 'install_id';
  final _storage = const FlutterSecureStorage();
  final _deviceInfo = DeviceInfoPlugin();

  /// Gets the primary device identifier (Android ID).
  Future<String> getDeviceId() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id; // ANDROID_ID
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios_unknown';
    }
    return 'unknown_platform';
  }

  /// Gets or generates a secondary installation UUID stored in secure storage.
  Future<String> getInstallId() async {
    String? id = await _storage.read(key: _installIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _installIdKey, value: id);
    }
    return id;
  }

  /// Collects comprehensive device metadata for backend registration.
  Future<Map<String, dynamic>> getDeviceMetadata({String? screenResolution}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final String language = Platform.localeName;
    final String timezone = DateTime.now().timeZoneName;
    
    // Attempt to get resolution if not provided
    String resolution = screenResolution ?? 'unknown';
    if (resolution == 'unknown') {
      try {
        final window = ui.PlatformDispatcher.instance.views.first.physicalSize;
        resolution = "${window.width.toInt()}x${window.height.toInt()}";
      } catch (_) {}
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'device_id': androidInfo.id,
        'install_id': await getInstallId(),
        'device_model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'android_version': androidInfo.version.release,
        'cpu_architecture': androidInfo.supportedAbis.isNotEmpty ? androidInfo.supportedAbis.first : 'unknown',
        'language': language,
        'timezone': timezone,
        'screen_resolution': resolution,
        'app_version': packageInfo.version,
        'package_name': packageInfo.packageName,
        'install_timestamp': DateTime.now().toIso8601String(),
      };
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return {
        'device_id': iosInfo.identifierForVendor ?? 'ios_unknown',
        'install_id': await getInstallId(),
        'device_model': iosInfo.utsname.machine,
        'manufacturer': 'Apple',
        'android_version': iosInfo.systemVersion,
        'cpu_architecture': iosInfo.utsname.machine,
        'language': language,
        'timezone': timezone,
        'screen_resolution': resolution,
        'app_version': packageInfo.version,
        'package_name': packageInfo.packageName,
        'install_timestamp': DateTime.now().toIso8601String(),
      };
    }
    
    return {};
  }
}
