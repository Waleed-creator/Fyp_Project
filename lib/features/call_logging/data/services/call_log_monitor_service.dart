import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../datasources/call_log_remote_datasource.dart';
import 'suspicious_call_detector_service.dart';
import 'package:flutter/foundation.dart';

/// Simple call log monitoring service
/// No background listeners - only foreground scanning
class CallLogMonitorService {
  final CallLogRemoteDataSourceImpl dataSource;
  Timer? _timer;
  bool _isPeriodicScanActive = false;

  CallLogMonitorService({required this.dataSource});

  /// Simple scan: Fetch call logs and check for suspicious calls
  /// No background timer - just scan when called
  Future<void> scanCallLogs() async {
    debugPrint('🔍 [CallLogMonitor] Starting call log scan...');
    await _monitorCallLogs();
  }

  /// Optional: Periodic scan (foreground only - stops when app goes to background)
  /// [frequencySeconds] - how often to scan (default: 30 seconds)
  /// ⚠️ IMPORTANT: Call stopPeriodicScan() when app goes to background
  Future<void> startPeriodicScan({int frequencySeconds = 30}) async {
    if (_isPeriodicScanActive) {
      debugPrint('⚙️ [CallLogMonitor] Periodic scan already active');
      return;
    }

    debugPrint(
      '🚀 [CallLogMonitor] Starting periodic scan (every $frequencySeconds seconds)',
    );
    debugPrint('   ⚠️ Note: This runs only when app is in foreground');
    debugPrint(
      '   ⚠️ IMPORTANT: Call stopPeriodicScan() when app goes to background',
    );

    _isPeriodicScanActive = true;
    await _monitorCallLogs();

    _timer = Timer.periodic(Duration(seconds: frequencySeconds), (timer) {
      if (!_isPeriodicScanActive) {
        timer.cancel();
        return;
      }
      _monitorCallLogs();
    });

    debugPrint('✅ [CallLogMonitor] Periodic scan started');
  }

  /// Stop periodic scan (call when app goes to background)
  void stopPeriodicScan() {
    if (!_isPeriodicScanActive) {
      return;
    }

    debugPrint(
      '🛑 [CallLogMonitor] Stopping periodic scan (app going to background)',
    );
    _timer?.cancel();
    _timer = null;
    _isPeriodicScanActive = false;
    debugPrint('✅ [CallLogMonitor] Periodic scan stopped');
  }

  Future<void> _monitorCallLogs() async {
    try {
      debugPrint('🔔 [CallLogMonitor] Starting call log monitoring cycle');
      final prefs = await SharedPreferences.getInstance();
      String? parentId = prefs.getString('parent_uid');
      String? childId = prefs.getString('child_uid');

      debugPrint(
        '🔍 [CallLogMonitor] parent_uid: $parentId, child_uid: $childId',
      );

      if (parentId == null || childId == null) {
        debugPrint(
          '❌ [CallLogMonitor] parent_uid or child_uid missing - skipping call log monitoring',
        );
        return;
      }

      final isLinked = await dataSource.firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .get()
          .then((doc) => doc.exists);

      debugPrint('🔗 [CallLogMonitor] Child linked to parent: $isLinked');

      if (!isLinked) {
        debugPrint(
          '⚠️ [CallLogMonitor] Child not linked to parent yet - skipping call log monitoring',
        );
        return;
      }

      await Future.delayed(
        Duration(milliseconds: 500),
      ); // Delay to prevent permission conflicts

      // ✅ Run suspicious call detector (analyzes unknown contacts, odd hours, etc.)
      // Simple approach: Scan last 24 hours and apply rules
      debugPrint('🚀 [CallLogMonitor] Starting suspicious call detection...');
      final detector = SuspiciousCallDetectorService(
        firestore: dataSource.firestore,
        childId: childId,
        parentId: parentId,
      );
      await detector.scanCallLogs(); // Simple scan - no background listener
      debugPrint('✅ [CallLogMonitor] Suspicious call detection completed');

      // Also upload call logs to Firebase (for call history screen)
      debugPrint('🚀 [CallLogMonitor] Uploading call logs to Firebase...');
      await dataSource.monitorChildCallLogs(
        parentId: parentId,
        childId: childId,
      );
      debugPrint('✅ [CallLogMonitor] Call log monitoring cycle completed');
    } catch (e, st) {
      debugPrint('❌ [CallLogMonitor] Call log monitoring error: $e\n$st');
      if (e.toString().contains('Reply already submitted')) {
        debugPrint(
          '⚠️ [CallLogMonitor] Permission handling conflict - will retry next cycle',
        );
      }
    }
  }

  /// Stop all monitoring (cleanup)
  Future<void> stop() async {
    stopPeriodicScan();
    debugPrint('🛑 [CallLogMonitor] Call log monitoring stopped');
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicScan();
  }
}
