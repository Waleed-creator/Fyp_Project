import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/notification_model.dart';
import '../../domain/entities/alert_type.dart';

/// Global instance for background message handler
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialize local notifications
/// This ensures notifications appear in system tray (phone's notification area)
Future<void> initializeLocalNotifications() async {
  // Request notification permission for Android 13+ (API 33+)
  if (!kIsWeb && Platform.isAndroid) {
    debugPrint('🔔 Checking notification permission...');
    final androidInfo = await Permission.notification.status;

    if (androidInfo.isDenied || androidInfo.isPermanentlyDenied) {
      debugPrint('🔔 Requesting notification permission...');
      final status = await Permission.notification.request();
      if (status.isGranted) {
        debugPrint(
          '✅ Notification permission granted - notifications will show in system tray',
        );
      } else if (status.isPermanentlyDenied) {
        debugPrint(
          '❌ Notification permission permanently denied - user needs to enable in settings',
        );
        // Optionally open app settings
        // await openAppSettings();
      } else {
        debugPrint('❌ Notification permission denied');
      }
    } else if (androidInfo.isGranted) {
      debugPrint(
        '✅ Notification permission already granted - system tray notifications enabled',
      );
    }
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap
      debugPrint('📱 Notification tapped: ${response.payload}');
    },
  );

  // Create notification channel for Android with MAXIMUM importance
  // This ensures notifications appear in system tray even when app is closed
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // name
    description: 'This channel is used for important notifications.',
    importance:
        Importance.max, // Changed from high to max for system tray visibility
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(channel);
    debugPrint('✅ Notification channel created with MAX importance');
  }
}

/// Background message handler (must be top-level function)
/// Note: Firebase should be initialized before calling this function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');

  // Initialize local notifications if not already initialized
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel for Android with MAXIMUM importance
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max, // MAX importance for system tray visibility
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      debugPrint(
        '✅ Background notification channel created with MAX importance',
      );
    }
  } catch (e) {
    debugPrint('⚠️ Local notifications already initialized or error: $e');
  }

  // Show system notification (this will appear in phone's notification tray)
  await _showLocalNotification(message);

  // Save notification to Firestore
  await _saveNotificationToFirestore(message);
}

/// Save notification to Firestore
Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
  try {
    final data = message.data;
    final parentId = data['parentId'] as String?;
    final childId = data['childId'] as String?;

    if (parentId == null || childId == null) {
      debugPrint('⚠️ Missing parentId or childId in notification data');
      return;
    }

    final notification = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      parentId: parentId,
      childId: childId,
      alertType: AlertTypeExtension.fromString(data['alertType'] ?? 'general'),
      title: message.notification?.title ?? data['title'] ?? 'Notification',
      body: message.notification?.body ?? data['body'] ?? '',
      data: data,
      timestamp: message.sentTime ?? DateTime.now(),
      isRead: false,
      actionUrl: data['actionUrl'] as String?,
    );

    // Save to child's notifications collection
    await FirebaseFirestore.instance
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .doc(childId)
        .collection('notifications')
        .add(notification.toMap());

    debugPrint('✅ Notification saved to Firestore for child: $childId');
  } catch (e) {
    debugPrint('❌ Error saving notification to Firestore: $e');
  }
}

/// Handle foreground messages
Future<void> handleForegroundMessage(RemoteMessage message) async {
  debugPrint('🔔 Foreground message received: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');

  // Show local notification
  await _showLocalNotification(message);

  // Save to Firestore
  await _saveNotificationToFirestore(message);
}

/// Show local notification
/// This ensures notification appears in system tray (phone's notification area)
Future<void> _showLocalNotification(RemoteMessage message) async {
  // Get title and body from notification payload OR data payload
  // This ensures notifications show even when sent with data-only payload
  final String title =
      message.notification?.title ??
      message.data['title']?.toString() ??
      'SafeNest Alert';
  final String body =
      message.notification?.body ??
      message.data['body']?.toString() ??
      message.data['message']?.toString() ??
      'You have a new notification';

  debugPrint('📱 Showing local notification:');
  debugPrint('   Title: $title');
  debugPrint('   Body: $body');

  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max, // MAX importance - shows in system tray
        priority:
            Priority.max, // MAX priority - shows at top of notification tray
        showWhen: true,
        playSound: true,
        enableVibration: true,
        enableLights: true, // Enable LED light
        color: const Color(0xFF007AFF), // Notification color (blue)
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ), // Big text style for better visibility
        fullScreenIntent: false, // Don't show full screen (just system tray)
        ongoing: false, // Not ongoing - can be dismissed
        autoCancel: true, // Auto cancel when tapped
        ticker: 'New notification', // Ticker text for status bar
      );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    platformChannelSpecifics,
    payload: message.data.toString(),
  );

  debugPrint('✅ Local notification shown in system tray');
}
