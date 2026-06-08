// lib/features/messages/services/child_message_monitor_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../datasources/message_remote_datasource.dart';
import 'package:flutter/foundation.dart';

/// Simple message monitoring service without background tasks
class ChildMessageMonitorService {
  final MessageRemoteDataSourceImpl dataSource;
  Timer? _timer;

  ChildMessageMonitorService({required this.dataSource});

  /// Start periodic message monitoring
  Future<void> initialize({int frequencySeconds = 5}) async {
    debugPrint(
      '🚀 [ChildMonitor] Starting message monitoring (every $frequencySeconds seconds)',
    );

    // Start monitoring immediately
    await _monitorMessages();

    // Set up periodic monitoring
    _timer = Timer.periodic(Duration(seconds: frequencySeconds), (timer) {
      _monitorMessages();
    });

    debugPrint('✅ [ChildMonitor] Message monitoring started');
  }

  /// Monitor messages for the current user
  Future<void> _monitorMessages() async {
    try {
      debugPrint('🔔 [ChildMonitor] Starting message monitoring cycle');

      // Read saved IDs
      final prefs = await SharedPreferences.getInstance();
      String? parentId = prefs.getString('parent_uid');
      String? childId = prefs.getString('child_uid');

      debugPrint(
        '🔍 [ChildMonitor] parent_uid: $parentId, child_uid: $childId',
      );

      if (parentId == null || childId == null) {
        debugPrint(
          '❌ [ChildMonitor] parent_uid or child_uid missing - using test values',
        );
        debugPrint('❌ [ChildMonitor] Available keys: ${prefs.getKeys()}');
        debugPrint(
          '🧪 [ChildMonitor] Using test parent and child IDs for message monitoring',
        );

        // Use test values for monitoring
        parentId = 'test_parent_id';
        childId = 'test_child_id';
      }

      // At this point, both parentId and childId are guaranteed to be non-null
      // Assign to non-nullable variables for type safety
      final String nonNullParentId = parentId;
      final String nonNullChildId = childId;

      // Check if child is linked before monitoring
      final isLinked = await dataSource.isChildLinkedToParent(
        parentId: nonNullParentId,
        childId: nonNullChildId,
      );

      debugPrint('🔗 [ChildMonitor] Child linked to parent: $isLinked');

      if (!isLinked) {
        debugPrint(
          '⚠️ [ChildMonitor] Child not linked to parent yet - skipping monitoring',
        );
        return;
      }

      // Add small delay to prevent permission conflicts
      await Future.delayed(Duration(milliseconds: 500));

      debugPrint('🚀 [ChildMonitor] Calling monitorChildMessages...');

      // Call monitor
      await dataSource.monitorChildMessages(
        parentId: nonNullParentId,
        childId: nonNullChildId,
      );

      debugPrint('✅ [ChildMonitor] Message monitoring cycle completed');
    } catch (e, st) {
      debugPrint('❌ [ChildMonitor] Message monitoring error: $e\n$st');
      // Don't crash the app, just log the error
      if (e.toString().contains('Reply already submitted')) {
        debugPrint(
          '⚠️ [ChildMonitor] Permission handling conflict - will retry next cycle',
        );
      }
    }
  }

  /// Stop monitoring
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 [ChildMonitor] Message monitoring stopped');
  }
}
