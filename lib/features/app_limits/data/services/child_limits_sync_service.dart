import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'child_limits_service.dart';
import '../datasources/local_storage_service.dart';
import 'package:flutter/foundation.dart';

/// Service to Sync Firebase App Limits to Local Storage
///
/// This service:
/// - Listens to Firebase app limits in real-time
/// - Syncs them to local storage for fast access
/// - Updates when parent changes limits
class ChildLimitsSyncService {
  final ChildLimitsService _childLimitsService = ChildLimitsService();
  final LocalStorageService _localStorage = LocalStorageService();

  StreamSubscription<List<Map<String, dynamic>>>? _limitsSubscription;
  String? _childId;
  String? _parentId;

  /// Initialize service with child and parent IDs
  void initialize({required String childId, required String parentId}) {
    _childId = childId;
    _parentId = parentId;

    // Initialize child limits service
    _childLimitsService.initialize(childId: childId, parentId: parentId);

    debugPrint('✅ [ChildLimitsSyncService] Initialized for child: $childId');
  }

  /// Start listening to Firebase limits and syncing to local storage
  void startSyncing() {
    if (_childId == null || _parentId == null) {
      debugPrint(
        '❌ [ChildLimitsSyncService] Not initialized. Call initialize() first.',
      );
      return;
    }

    if (_limitsSubscription != null) {
      debugPrint('⚠️ [ChildLimitsSyncService] Already syncing');
      return;
    }

    debugPrint('🔄 [ChildLimitsSyncService] Starting Firebase limits sync...');

    // Listen to Firebase app limits stream
    _limitsSubscription = _childLimitsService.getAppLimitsStream().listen(
      (limits) {
        _syncLimitsToLocalStorage(limits);
      },
      onError: (error) {
        debugPrint('❌ [ChildLimitsSyncService] Error in limits stream: $error');
      },
    );

    debugPrint(
      '✅ [ChildLimitsSyncService] Started listening to Firebase limits',
    );
  }

  /// Stop syncing
  void stopSyncing() {
    _limitsSubscription?.cancel();
    _limitsSubscription = null;
    debugPrint('⏹️ [ChildLimitsSyncService] Stopped syncing');
  }

  /// Sync Firebase limits to local storage
  Future<void> _syncLimitsToLocalStorage(
    List<Map<String, dynamic>> limits,
  ) async {
    try {
      debugPrint(
        '🔄 [ChildLimitsSyncService] Syncing ${limits.length} app limits to local storage...',
      );

      // Get current local limits
      final localLimits = await _localStorage.getAppDailyLimits();

      // Create a map of Firebase limits
      final firebaseLimitsMap = <String, Map<String, dynamic>>{};
      for (final limit in limits) {
        final packageName = limit['packageName'] as String?;
        if (packageName != null && limit['isActive'] == true) {
          firebaseLimitsMap[packageName] = {
            'dailyLimitMinutes': limit['dailyLimitMinutes'] ?? 0,
            'usedMinutes':
                localLimits[packageName]?['usedMinutes'] ?? 0, // Preserve usage
            'lastReset':
                localLimits[packageName]?['lastReset'] ??
                DateTime.now().toIso8601String(),
          };
        }
      }

      // Update local storage with Firebase limits
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'app_daily_limits',
        _encodeJsonMap(firebaseLimitsMap),
      );

      debugPrint(
        '✅ [ChildLimitsSyncService] Synced ${firebaseLimitsMap.length} limits to local storage',
      );

      // Print first 5 limits for debugging
      if (firebaseLimitsMap.isNotEmpty) {
        debugPrint('📱 [ChildLimitsSyncService] Sample limits synced:');
        int count = 0;
        for (final entry in firebaseLimitsMap.entries) {
          if (count < 5) {
            debugPrint(
              '   - ${entry.key}: ${entry.value['dailyLimitMinutes']} min/day',
            );
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [ChildLimitsSyncService] Error syncing limits: $e');
    }
  }

  /// Encode map to JSON string
  String _encodeJsonMap(Map<String, dynamic> map) {
    try {
      return jsonEncode(map);
    } catch (e) {
      debugPrint('❌ [ChildLimitsSyncService] Error encoding map: $e');
      return '{}';
    }
  }

  /// Dispose resources
  void dispose() {
    stopSyncing();
    _childLimitsService.dispose();
    _childId = null;
    _parentId = null;
  }
}
