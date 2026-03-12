import 'package:safe_device/safe_device.dart';

/// Service to handle security checks like root detection and emulator detection.
class SecurityService {
  /// Checks if the device is rooted or jailbroken.
  Future<bool> isRooted() async {
    return await SafeDevice.isJailBroken;
  }

  /// Checks if the app is running on a real device.
  Future<bool> isRealDevice() async {
    return await SafeDevice.isRealDevice;
  }

  /// Checks if developer options are enabled.
  Future<bool> isDevelopmentMode() async {
    return await SafeDevice.isDevelopmentModeEnable;
  }

  /// Comprehensive check for security threats.
  Future<Map<String, bool>> getSecurityReport() async {
    return {
      'is_rooted': await isRooted(),
      'is_emulator': !(await isRealDevice()),
      'is_dev_mode': await isDevelopmentMode(),
      'is_safe': await SafeDevice.isSafeDevice,
    };
  }

  /// Checks for any suspicious flags that should block communication.
  Future<bool> isSuspicious() async {
    final report = await getSecurityReport();
    return report['is_rooted']! || 
           report['is_emulator']! || 
           !(report['is_safe']!);
  }

  /// Placeholder for Integrity API check.
  Future<String?> getIntegrityToken() async {
    // In a real app, use the play_integrity package to get a token.
    // For now, we return a mock token or null.
    return "demo_integrity_token_${DateTime.now().millisecondsSinceEpoch}";
  }
}
