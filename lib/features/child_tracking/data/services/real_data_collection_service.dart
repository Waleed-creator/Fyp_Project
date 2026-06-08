import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import '../../../url_tracking/data/services/url_tracking_firebase_service.dart';
import '../../../app_limits/data/services/app_usage_firebase_service.dart';
import 'package:flutter/foundation.dart';

class RealDataCollectionService {
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  final UrlTrackingFirebaseService _urlService = UrlTrackingFirebaseService();
  final AppUsageFirebaseService _appService = AppUsageFirebaseService();
  final MethodChannel _channel = MethodChannel('child_tracking');

  // Initialize real data collection
  Future<void> initializeRealDataCollection({
    required String childId,
    required String parentId,
  }) async {
    try {
      debugPrint('🚀 Starting real data collection for child: $childId, parent: $parentId');
      
      // Set up method channel for native communication
      _channel.setMethodCallHandler((call) async {
        debugPrint('📨 [ChildTracking] Method channel received: ${call.method}');
        debugPrint('📨 [ChildTracking] Arguments: ${call.arguments}');
        
        switch (call.method) {
          case 'onUrlVisited':
            debugPrint('🌐 [ChildTracking] Handling onUrlVisited event...');
            await _handleRealUrlVisited(call.arguments, childId, parentId);
            break;
          case 'onAppUsageUpdated':
            debugPrint('📱 [ChildTracking] Handling onAppUsageUpdated event...');
            await _handleRealAppUsage(call.arguments, childId, parentId);
            break;
          case 'onAppLaunched':
            debugPrint('🚀 [ChildTracking] Handling onAppLaunched event...');
            await _handleRealAppLaunched(call.arguments, childId, parentId);
            break;
          default:
            debugPrint('⚠️ [ChildTracking] Unknown method: ${call.method}');
        }
      });

      // Start native tracking services
      await _startNativeTracking();
      
      debugPrint('✅ Real data collection initialized successfully');
      debugPrint('📊 Listening for events on child_tracking channel...');
    } catch (e) {
      debugPrint('❌ Error initializing real data collection: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Start native Android tracking services
  Future<void> _startNativeTracking() async {
    try {
      debugPrint('🔄 [ChildTracking] Starting native Android tracking services...');
      
      // Check accessibility permission first (required for URL tracking)
      try {
        final hasAccessibility = await _channel.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
        if (hasAccessibility) {
          debugPrint('✅ [ChildTracking] Accessibility permission: GRANTED');
        } else {
          debugPrint('⚠️ [ChildTracking] Accessibility permission: NOT GRANTED');
          debugPrint('⚠️ [ChildTracking] URL tracking will not work without accessibility permission');
          debugPrint('⚠️ [ChildTracking] Please enable it in Settings > Accessibility');
        }
      } catch (e) {
        debugPrint('⚠️ [ChildTracking] Could not check accessibility permission: $e');
      }
      
      // Start URL tracking service
      debugPrint('🌐 [ChildTracking] Starting URL tracking service...');
      try {
        await _channel.invokeMethod('startUrlTracking');
        debugPrint('✅ [ChildTracking] URL tracking service started');
        debugPrint('📊 [ChildTracking] Listening for URL visits in browsers...');
      } catch (e) {
        debugPrint('❌ [ChildTracking] Failed to start URL tracking: $e');
        debugPrint('⚠️ [ChildTracking] Make sure accessibility permission is granted');
      }
      
      // Check usage stats permission (required for app tracking)
      try {
        final hasUsageStats = await _channel.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
        if (hasUsageStats) {
          debugPrint('✅ [ChildTracking] Usage stats permission: GRANTED');
        } else {
          debugPrint('⚠️ [ChildTracking] Usage stats permission: NOT GRANTED');
          debugPrint('⚠️ [ChildTracking] App tracking will not work without usage stats permission');
        }
      } catch (e) {
        debugPrint('⚠️ [ChildTracking] Could not check usage stats permission: $e');
      }
      
      // Start app usage tracking service
      debugPrint('📱 [ChildTracking] Starting app usage tracking service...');
      try {
        await _channel.invokeMethod('startAppUsageTracking');
        debugPrint('✅ [ChildTracking] App usage tracking service started');
        debugPrint('📊 [ChildTracking] Listening for app launches and usage...');
      } catch (e) {
        debugPrint('❌ [ChildTracking] Failed to start app usage tracking: $e');
        debugPrint('⚠️ [ChildTracking] Make sure usage stats permission is granted');
      }
      
      debugPrint('✅ [ChildTracking] All native tracking services started');
      debugPrint('📊 [ChildTracking] Now listening for URL visits and app usage...');
    } catch (e) {
      debugPrint('❌ [ChildTracking] Error starting native tracking: $e');
      debugPrint('❌ [ChildTracking] Stack trace: ${StackTrace.current}');
    }
  }

  // Handle real URL visited from native side
  Future<void> _handleRealUrlVisited(
    Map<dynamic, dynamic> data,
    String childId,
    String parentId,
  ) async {
    try {
      debugPrint('');
      debugPrint('🌐 ========== 🌐 URL VISITED - CHILD SIDE 🌐 ==========');
      debugPrint('🌐 URL: ${data['url']}');
      debugPrint('🌐 Title: ${data['title'] ?? 'No title'}');
      debugPrint('🌐 Package: ${data['packageName'] ?? 'Unknown'}');
      debugPrint('🌐 Browser: ${data['browserName'] ?? 'Unknown'}');
      debugPrint('🌐 Child ID: $childId');
      debugPrint('🌐 Parent ID: $parentId');
      debugPrint('🌐 Timestamp: ${DateTime.now()}');
      debugPrint('🌐 ====================================================');
      
      if (data['url'] == null || (data['url'] as String).isEmpty) {
        debugPrint('⚠️ [URL Tracking] URL is empty, skipping upload');
        return;
      }
      
      await _urlService.uploadUrlToFirebase(
        url: data['url'] ?? '',
        title: data['title'] ?? '',
        packageName: data['packageName'] ?? '',
        childId: childId,
        parentId: parentId,
        browserName: data['browserName'],
        metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      );
      
      debugPrint('✅ [URL Tracking] URL uploaded to Firebase successfully!');
      debugPrint('✅ [URL Tracking] Firebase path: parents/$parentId/children/$childId/visitedUrls');
      debugPrint('✅ [URL Tracking] Parent side should now see this URL');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ [URL Tracking] Error uploading URL: $e');
      debugPrint('❌ [URL Tracking] Stack trace: ${StackTrace.current}');
    }
  }

  // Handle real app usage from native side
  Future<void> _handleRealAppUsage(
    Map<dynamic, dynamic> data,
    String childId,
    String parentId,
  ) async {
    try {
      final appName = data['appName'] ?? 'Unknown App';
      final packageName = data['packageName'] ?? 'Unknown';
      final usageDuration = data['usageDuration'] ?? 0;
      final launchCount = data['launchCount'] ?? 0;
      
      debugPrint('');
      debugPrint('📱 ========== 📱 APP USAGE - CHILD SIDE 📱 ==========');
      debugPrint('📱 App Name: $appName');
      debugPrint('📱 Package: $packageName');
      debugPrint('📱 Usage Duration: $usageDuration minutes');
      debugPrint('📱 Launch Count: $launchCount');
      debugPrint('📱 Child ID: $childId');
      debugPrint('📱 Parent ID: $parentId');
      debugPrint('📱 Timestamp: ${DateTime.now()}');
      debugPrint('📱 =================================================');
      
      await _appService.uploadAppUsageToFirebase(
        packageName: packageName,
        appName: appName,
        usageDuration: usageDuration,
        launchCount: launchCount,
        lastUsed: data['lastUsed'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(data['lastUsed'])
            : DateTime.now(),
        childId: childId,
        parentId: parentId,
        appIcon: data['appIcon'],
        metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
        isSystemApp: data['isSystemApp'] ?? false,
        riskScore: data['riskScore']?.toDouble(),
      );
      
      debugPrint('✅ [App Tracking] App usage uploaded to Firebase successfully!');
      debugPrint('✅ [App Tracking] Firebase path: parents/$parentId/children/$childId/appUsage');
      debugPrint('✅ [App Tracking] Parent side should now see this app usage');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ [App Tracking] Error uploading app usage: $e');
      debugPrint('❌ [App Tracking] Stack trace: ${StackTrace.current}');
    }
  }

  // Handle real app launched from native side
  Future<void> _handleRealAppLaunched(
    Map<dynamic, dynamic> data,
    String childId,
    String parentId,
  ) async {
    try {
      final appName = data['appName'] ?? 'Unknown App';
      final packageName = data['packageName'] ?? 'Unknown';
      final usageDuration = data['usageDuration'] ?? 0;
      final launchCount = data['launchCount'] ?? 1; // Default to 1 if not provided
      
      debugPrint('');
      debugPrint('🚀 ========== 🚀 APP LAUNCHED - CHILD SIDE 🚀 ==========');
      debugPrint('🚀 App Name: $appName');
      debugPrint('🚀 Package: $packageName');
      debugPrint('🚀 Usage Duration: $usageDuration minutes');
      debugPrint('🚀 Launch Count: $launchCount');
      debugPrint('🚀 Child ID: $childId');
      debugPrint('🚀 Parent ID: $parentId');
      debugPrint('🚀 Timestamp: ${DateTime.now()}');
      debugPrint('🚀 ====================================================');
      
      // Use uploadAppUsageToFirebase instead of updateAppUsageInFirebase
      // This will create a new document if it doesn't exist, or update if it does
      await _appService.uploadAppUsageToFirebase(
        packageName: packageName,
        appName: appName,
        usageDuration: usageDuration,
        launchCount: launchCount,
        lastUsed: data['lastUsed'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(data['lastUsed'])
            : DateTime.now(),
        childId: childId,
        parentId: parentId,
        appIcon: data['appIcon'],
        metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
        isSystemApp: data['isSystemApp'] ?? false,
        riskScore: data['riskScore']?.toDouble(),
      );
      
      debugPrint('✅ [App Tracking] App launch uploaded to Firebase successfully!');
      debugPrint('✅ [App Tracking] Firebase path: parents/$parentId/children/$childId/appUsage');
      debugPrint('✅ [App Tracking] Parent side should now see this app launch');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ [App Tracking] Error uploading app launch: $e');
      debugPrint('❌ [App Tracking] Stack trace: ${StackTrace.current}');
    }
  }

  // Simulate real data collection for testing (remove this in production)
  Future<void> simulateRealDataCollection({
    required String childId,
    required String parentId,
  }) async {
    try {
      debugPrint('🧪 Simulating real data collection...');
      
      // Simulate real URLs
      final realUrls = [
        {
          'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'title': 'Rick Astley - Never Gonna Give You Up',
          'packageName': 'com.google.android.youtube',
          'browserName': 'Chrome',
          'visitedAt': DateTime.now().subtract(Duration(minutes: 5)),
        },
        {
          'url': 'https://www.facebook.com',
          'title': 'Facebook',
          'packageName': 'com.facebook.katana',
          'browserName': 'Facebook App',
          'visitedAt': DateTime.now().subtract(Duration(minutes: 10)),
        },
        {
          'url': 'https://www.instagram.com',
          'title': 'Instagram',
          'packageName': 'com.instagram.android',
          'browserName': 'Instagram App',
          'visitedAt': DateTime.now().subtract(Duration(minutes: 15)),
        },
      ];

      // Simulate real app usage
      final realApps = [
        {
          'packageName': 'com.google.android.youtube',
          'appName': 'YouTube',
          'usageDuration': 45, // minutes
          'launchCount': 3,
          'lastUsed': DateTime.now().subtract(Duration(minutes: 2)),
          'appIcon': 'https://play-lh.googleusercontent.com/...',
          'isSystemApp': false,
          'riskScore': 0.2,
        },
        {
          'packageName': 'com.facebook.katana',
          'appName': 'Facebook',
          'usageDuration': 30,
          'launchCount': 2,
          'lastUsed': DateTime.now().subtract(Duration(minutes: 8)),
          'appIcon': 'https://play-lh.googleusercontent.com/...',
          'isSystemApp': false,
          'riskScore': 0.3,
        },
        {
          'packageName': 'com.instagram.android',
          'appName': 'Instagram',
          'usageDuration': 25,
          'launchCount': 4,
          'lastUsed': DateTime.now().subtract(Duration(minutes: 12)),
          'appIcon': 'https://play-lh.googleusercontent.com/...',
          'isSystemApp': false,
          'riskScore': 0.1,
        },
      ];

      // Upload simulated real URLs
      for (final urlData in realUrls) {
        await _urlService.uploadUrlToFirebase(
          url: urlData['url'] as String,
          title: urlData['title'] as String,
          packageName: urlData['packageName'] as String,
          childId: childId,
          parentId: parentId,
          browserName: urlData['browserName'] as String,
          metadata: {
            'simulated': true,
            'visitedAt': urlData['visitedAt'],
          },
        );
      }

      // Upload simulated real app usage
      for (final appData in realApps) {
        await _appService.uploadAppUsageToFirebase(
          packageName: appData['packageName'] as String,
          appName: appData['appName'] as String,
          usageDuration: appData['usageDuration'] as int,
          launchCount: appData['launchCount'] as int,
          lastUsed: appData['lastUsed'] as DateTime,
          childId: childId,
          parentId: parentId,
          appIcon: appData['appIcon'] as String,
          metadata: {
            'simulated': true,
            'riskScore': appData['riskScore'],
          },
          isSystemApp: appData['isSystemApp'] as bool,
          riskScore: appData['riskScore'] as double,
        );
      }

      debugPrint('✅ Simulated real data uploaded to Firebase');
    } catch (e) {
      debugPrint('❌ Error simulating real data: $e');
    }
  }

  // Stop real data collection
  Future<void> stopRealDataCollection() async {
    try {
      await _channel.invokeMethod('stopAllTracking');
      _channel.setMethodCallHandler(null);
      debugPrint('✅ Real data collection stopped');
    } catch (e) {
      debugPrint('❌ Error stopping real data collection: $e');
    }
  }
}
