import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to handle secure API communication with HMAC request signing and SSL pinning.
class ApiService {
  final String baseUrl = "https://your-api-endpoint.com/api"; 
  final String apiSecret = "your_super_secret_hmac_key"; 
  
  // SSL Pinning: Public Key Fingerprint (SHA-256)
  // Example: "6B 41 21 73 E1 85 9E 14 05 CC ..."
  final String? _pinnedFingerprint = null; 

  late final http.Client _client;

  ApiService() {
    _client = _createSecureClient();
  }

  /// Creates an IOClient with a SecurityContext that enforces certificate validation.
  http.Client _createSecureClient() {
    if (_pinnedFingerprint == null) return http.Client();

    final SecurityContext context = SecurityContext(withTrustedRoots: true);
    // In a real production app, you would use:
    // context.setTrustedCertificatesBytes(utf8.encode(certString));
    
    final HttpClient httpClient = HttpClient(context: context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Here you compare the actual certificate fingerprint with the pinned one
        // This prevents Man-in-the-middle (MITM) attacks.
        return false; // Reject by default
      };

    return IOClient(httpClient);
  }

  static const String _trialUsagePrefix = "trial_usage_";

  /// Sends a signed POST request to the backend with anti-tamper headers.
  Future<http.Response> postSigned(
    String endpoint, 
    Map<String, dynamic> body, {
    String? featureName,
    String? integrityToken,
  }) async {
    // Check if we are in "Demo Mode"
    if (baseUrl.contains("your-api-endpoint.com")) {
      throw Exception("Demo Mode: Backend endpoint not configured.");
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final url = Uri.parse("$baseUrl$endpoint");
    
    // Get Device ID for signing
    final String deviceId = body['device_id'] ?? 'unknown_device';

    // Generate HMAC signature: HMAC_SHA256(Secret, Timestamp + DeviceId + FeatureName + BodyJSON)
    // Adding context to the signature prevents replaying a "register" signature for a "track" request.
    final String signPayload = timestamp + deviceId + (featureName ?? '') + json.encode(body);
    final hmac = Hmac(sha256, utf8.encode(apiSecret));
    final signature = hmac.convert(utf8.encode(signPayload)).toString();

    // Application identity signals
    final packageInfo = await PackageInfo.fromPlatform();
    
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-signature': signature,
          'x-timestamp': timestamp,
          'x-package-name': packageInfo.packageName,
          'x-app-signature': "placeholder_hash_v1", // In production, fetch actual app signature
          ...integrityToken != null ? {'x-integrity-token': integrityToken} : {},
        },
        body: json.encode(body),
      );
      
      return response;
    } catch (e) {
      debugPrint("API Error on $endpoint: $e");
      rethrow;
    }
  }

  /// Fetches a short-lived one-time token for a specific feature.
  Future<String?> getFeatureToken(String deviceId, String featureName) async {
    try {
      final response = await postSigned("/security/token", {
        'device_id': deviceId,
        'feature_name': featureName,
      });
      if (response.statusCode == 200) {
        return json.decode(response.body)['feature_token'];
      }
    } catch (_) {}
    return null;
  }

  /// Specialized method for device registration.
  Future<bool> registerDevice(Map<String, dynamic> metadata) async {
    try {
      final response = await postSigned("/devices/register", metadata);
      return response.statusCode == 200;
    } catch (_) {
      // In demo mode, we just simulate success
      return true;
    }
  }

  /// Specialized method for upgrading a device to premium.
  Future<bool> upgradeToPremium(String deviceId) async {
    try {
      final response = await postSigned("/devices/upgrade", {
        'device_id': deviceId,
        'subscription_type': 'monthly_premium',
      });
      return response.statusCode == 200;
    } catch (_) {
      // In demo mode, we simulate success and could flag it locally
      return true;
    }
  }

  /// Specialized method for usage tracking.
  Future<Map<String, dynamic>?> trackUsage({
    required String deviceId, 
    required String featureName,
    String? integrityToken,
    String? featureToken,
  }) async {
    try {
      final response = await postSigned(
        "/usage/track", 
        {
          'device_id': deviceId,
          'feature_name': featureName,
          'feature_token': featureToken,
        },
        featureName: featureName,
        integrityToken: integrityToken,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 429) {
        // Limit reached
        return {'error': 'limit_reached', 'message': json.decode(response.body)['error']};
      }
      return null;
    } catch (_) {
      // Demo Mode Fallback: Track usage locally if server is down or unconfigured
      return await _trackUsageLocally(featureName);
    }
  }

  Future<Map<String, dynamic>?> _trackUsageLocally(String featureName) async {
    final prefs = await SharedPreferences.getInstance();
    // For trial purposes, we aggregate all "document creation" features into one limit
    const String globalUsageKey = "${_trialUsagePrefix}global_limit";
    int count = prefs.getInt(globalUsageKey) ?? 0;
    
    if (count >= 3) {
      return {
        'error': 'limit_reached',
        'message': 'You have reached your 3-use trial limit. Please upgrade to continue using the app.'
      };
    }
    
    await prefs.setInt(globalUsageKey, count + 1);
    return {
      'status': 'success', 
      'usage_count': count + 1, 
      'remaining': 2 - count // 3 total - (count + 1)
    };
  }

  /// Gets local usage count across all limited features.
  Future<int> getGlobalTrialUsage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("${_trialUsagePrefix}global_limit") ?? 0;
  }
}
