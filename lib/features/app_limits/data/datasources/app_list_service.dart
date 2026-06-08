import 'package:flutter/services.dart';
import '../models/installed_app.dart';
import 'package:flutter/foundation.dart';

/// AppListService - Uses Native Android Method Channel (QUERY_ALL_PACKAGES solution)
/// 
/// This service uses native Kotlin code via method channel to get ALL installed apps.
/// Works with QUERY_ALL_PACKAGES permission for complete app list.
class AppListService {
  static const MethodChannel _channel = MethodChannel('app_list_service');

  /// Get list of all installed apps on the device (Native Method Channel)
  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      debugPrint('📱 [AppListService] ========== GETTING INSTALLED APPS ==========');
      debugPrint('📱 [AppListService] Using NATIVE method channel (app_list_service)...');
      debugPrint('📱 [AppListService] This uses QUERY_ALL_PACKAGES permission solution');
      
      // Get all installed apps from native Android code
      final startTime = DateTime.now();
      final List<dynamic> rawList = await _channel.invokeMethod('getInstalledApps');
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('📱 [AppListService] ✅ Received ${rawList.length} apps from native Android');
      debugPrint('📱 [AppListService] ⏱️ Time taken: ${duration.inMilliseconds}ms');
      
      if (rawList.isEmpty) {
        debugPrint('⚠️ [AppListService] ⚠️⚠️⚠️ WARNING: EMPTY APP LIST RECEIVED! ⚠️⚠️⚠️');
        debugPrint('⚠️ [AppListService] This might indicate:');
        debugPrint('   1. QUERY_ALL_PACKAGES permission not granted');
        debugPrint('   2. Native method channel error');
        debugPrint('   3. Device compatibility issue');
        debugPrint('⚠️ [AppListService] Check AndroidManifest.xml for QUERY_ALL_PACKAGES permission');
        return [];
      }
      
      // Convert to InstalledApp model
      debugPrint('📱 [AppListService] Converting ${rawList.length} apps to InstalledApp model...');
      final List<InstalledApp> installedApps = rawList.map((data) {
        final map = Map<String, dynamic>.from(data);
        return InstalledApp(
          packageName: map['packageName'] ?? '',
          appName: map['appName'] ?? 'Unknown',
          versionName: map['versionName'],
          versionCode: map['versionCode']?.toInt() ?? 0,
          isSystemApp: map['isSystemApp'] ?? false,
          installTime: DateTime.fromMillisecondsSinceEpoch(
            map['installTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(
            map['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          iconPath: map['iconPath'],
        );
      }).toList();
      
      // Count system vs user apps
      final systemAppsCount = installedApps.where((app) => app.isSystemApp).length;
      final userAppsCount = installedApps.length - systemAppsCount;
      debugPrint('📱 [AppListService] Breakdown:');
      debugPrint('   - Total Apps: ${installedApps.length}');
      debugPrint('   - User Apps: $userAppsCount');
      debugPrint('   - System Apps: $systemAppsCount');
      
      // Print first 10 apps for debugging
      debugPrint('📱 [AppListService] Sample apps (first 10):');
      for (var i = 0; i < (installedApps.length > 10 ? 10 : installedApps.length); i++) {
        final app = installedApps[i];
        debugPrint('   ${i + 1}. ${app.appName} (${app.packageName}) [${app.isSystemApp ? "System" : "User"}]');
      }
      
      debugPrint('✅ [AppListService] Successfully converted ${installedApps.length} apps to InstalledApp model');
      debugPrint('📱 [AppListService] ============================================');
      return installedApps;
    } catch (e, stackTrace) {
      debugPrint('❌ [AppListService] ========== ERROR GETTING APPS ==========');
      debugPrint('❌ [AppListService] Error: $e');
      debugPrint('❌ [AppListService] Stack trace: $stackTrace');
      debugPrint('❌ [AppListService] Make sure:');
      debugPrint('   1. QUERY_ALL_PACKAGES permission is in AndroidManifest.xml');
      debugPrint('   2. AppListPlugin.kt is registered in MainActivity.kt');
      debugPrint('   3. Native method channel "app_list_service" is working');
      debugPrint('❌ [AppListService] =========================================');
      return [];
    }
  }

  /// Get list of user-installed apps (excluding system apps) - Native Method Channel
  Future<List<InstalledApp>> getUserApps() async {
    try {
      debugPrint('📱 [AppListService] Getting user apps only (native)...');
      
      final List<dynamic> rawList = await _channel.invokeMethod('getUserApps');
      
      return rawList.map((data) {
        final map = Map<String, dynamic>.from(data);
        return InstalledApp(
          packageName: map['packageName'] ?? '',
          appName: map['appName'] ?? 'Unknown',
          versionName: map['versionName'],
          versionCode: map['versionCode']?.toInt() ?? 0,
          isSystemApp: false,
          installTime: DateTime.fromMillisecondsSinceEpoch(
            map['installTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(
            map['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          iconPath: map['iconPath'],
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ [AppListService] Error getting user apps: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get list of system apps only - Native Method Channel
  Future<List<InstalledApp>> getSystemApps() async {
    try {
      debugPrint('📱 [AppListService] Getting system apps only (native)...');
      
      final List<dynamic> rawList = await _channel.invokeMethod('getSystemApps');
      
      return rawList.map((data) {
        final map = Map<String, dynamic>.from(data);
        return InstalledApp(
          packageName: map['packageName'] ?? '',
          appName: map['appName'] ?? 'Unknown',
          versionName: map['versionName'],
          versionCode: map['versionCode']?.toInt() ?? 0,
          isSystemApp: true,
          installTime: DateTime.fromMillisecondsSinceEpoch(
            map['installTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(
            map['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          iconPath: map['iconPath'],
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ [AppListService] Error getting system apps: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Launch an app by package name - Native Method Channel
  Future<bool> launchApp(String packageName) async {
    try {
      debugPrint('🚀 [AppListService] Launching app: $packageName');
      final bool launched = await _channel.invokeMethod('launchApp', {'packageName': packageName});
      if (launched) {
        debugPrint('✅ [AppListService] App launched successfully: $packageName');
      } else {
        debugPrint('❌ [AppListService] Failed to launch app: $packageName');
      }
      return launched;
    } catch (e) {
      debugPrint('❌ [AppListService] Error launching app: $e');
      return false;
    }
  }

  /// Uninstall an app by package name - Native Method Channel
  Future<bool> uninstallApp(String packageName) async {
    try {
      debugPrint('🗑️ [AppListService] Uninstalling app: $packageName');
      final bool uninstalled = await _channel.invokeMethod('uninstallApp', {'packageName': packageName});
      if (uninstalled) {
        debugPrint('✅ [AppListService] App uninstalled successfully: $packageName');
      } else {
        debugPrint('❌ [AppListService] Failed to uninstall app: $packageName');
      }
      return uninstalled;
    } catch (e) {
      debugPrint('❌ [AppListService] Error uninstalling app: $e');
      return false;
    }
  }

  /// Get app info by package name - Native Method Channel
  Future<InstalledApp?> getAppInfo(String packageName) async {
    try {
      debugPrint('📱 [AppListService] Getting app info: $packageName');
      final Map<dynamic, dynamic>? appData = await _channel.invokeMethod('getAppInfo', {'packageName': packageName});
      
      if (appData == null) {
        debugPrint('⚠️ [AppListService] App not found: $packageName');
        return null;
      }
      
      final map = Map<String, dynamic>.from(appData);
      return InstalledApp(
        packageName: map['packageName'] ?? '',
        appName: map['appName'] ?? 'Unknown',
        versionName: map['versionName'],
        versionCode: map['versionCode']?.toInt() ?? 0,
        isSystemApp: map['isSystemApp'] ?? false,
        installTime: DateTime.fromMillisecondsSinceEpoch(
          map['installTime'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
        lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(
          map['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
        iconPath: map['iconPath'],
      );
    } catch (e) {
      debugPrint('❌ [AppListService] Error getting app info: $e');
      return null;
    }
  }

  /// Check if an app is installed - Native Method Channel
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('isAppInstalled', {'packageName': packageName});
      return result;
    } catch (e) {
      debugPrint('❌ [AppListService] Error checking if app is installed: $e');
      return false;
    }
  }
}
