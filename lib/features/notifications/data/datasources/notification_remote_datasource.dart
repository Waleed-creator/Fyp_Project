import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'package:flutter/foundation.dart';

abstract class NotificationRemoteDataSource {
  Future<void> saveNotification(NotificationModel notification);
  Stream<List<NotificationModel>> streamNotifications(
    String parentId, {
    String? childId,
  });
  Future<List<NotificationModel>> getNotifications(
    String parentId, {
    String? childId,
    int? limit,
  });
  Future<void> markAsRead(
    String parentId,
    String childId,
    String notificationId,
  );
  Future<void> markAllAsRead(String parentId, {String? childId});
  Future<void> deleteNotification(
    String parentId,
    String childId,
    String notificationId,
  );
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore firestore;

  NotificationRemoteDataSourceImpl({required this.firestore});

  @override
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      // Save under child-specific collection: parents/{parentId}/children/{childId}/notifications
      await firestore
          .collection('parents')
          .doc(notification.parentId)
          .collection('children')
          .doc(notification.childId)
          .collection('notifications')
          .add(notification.toMap());
      debugPrint('✅ Notification saved for child: ${notification.childId}');
    } catch (e) {
      debugPrint('❌ Error saving notification: $e');
      rethrow;
    }
  }

  @override
  Stream<List<NotificationModel>> streamNotifications(
    String parentId, {
    String? childId,
  }) {
    try {
      if (childId != null) {
        // Stream notifications for specific child
        return firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .doc(childId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots()
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => NotificationModel.fromFirestore(doc))
                  .toList();
            });
      } else {
        // Stream notifications from all children (aggregate)
        // We need to listen to all children's notification collections
        return _streamAllChildrenNotifications(parentId);
      }
    } catch (e) {
      debugPrint('❌ Error streaming notifications: $e');
      return Stream.value([]);
    }
  }

  Stream<List<NotificationModel>> _streamAllChildrenNotifications(
    String parentId,
  ) {
    // Helper function to fetch all notifications
    Future<List<NotificationModel>> fetchAllNotifications() async {
      try {
        debugPrint(
          '📡 [NotificationStream] Fetching notifications for parent: $parentId',
        );
        final childrenSnapshot = await firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .get();

        debugPrint(
          '📡 [NotificationStream] Found ${childrenSnapshot.docs.length} children',
        );

        if (childrenSnapshot.docs.isEmpty) {
          debugPrint(
            '📡 [NotificationStream] No children found, returning empty list',
          );
          return <NotificationModel>[];
        }

        final List<NotificationModel> allNotifications = [];

        for (final childDoc in childrenSnapshot.docs) {
          try {
            debugPrint(
              '📡 [NotificationStream] Checking notifications for child: ${childDoc.id}',
            );
            final notificationsSnapshot = await firestore
                .collection('parents')
                .doc(parentId)
                .collection('children')
                .doc(childDoc.id)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .get();

            debugPrint(
              '📡 [NotificationStream] Found ${notificationsSnapshot.docs.length} notifications for child ${childDoc.id}',
            );

            allNotifications.addAll(
              notificationsSnapshot.docs.map((doc) {
                try {
                  return NotificationModel.fromFirestore(doc);
                } catch (e) {
                  debugPrint('❌ Error parsing notification doc ${doc.id}: $e');
                  return null;
                }
              }).whereType<NotificationModel>(),
            );
          } catch (e) {
            debugPrint(
              '❌ Error getting notifications for child ${childDoc.id}: $e',
            );
          }
        }

        // Sort by timestamp descending
        allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        debugPrint(
          '📡 [NotificationStream] Total notifications: ${allNotifications.length}',
        );
        return allNotifications;
      } catch (e) {
        debugPrint('❌ Error in _streamAllChildrenNotifications: $e');
        debugPrint('❌ Stack trace: ${StackTrace.current}');
        return <NotificationModel>[];
      }
    }

    // Load immediately, then periodically update
    return Stream.fromFuture(fetchAllNotifications()).asyncExpand((
      initialNotifications,
    ) async* {
      // Emit initial load immediately
      debugPrint(
        '📡 [NotificationStream] Emitting initial notifications: ${initialNotifications.length}',
      );
      yield initialNotifications;

      // Then emit periodic updates every 3 seconds
      await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
        final updated = await fetchAllNotifications();
        debugPrint(
          '📡 [NotificationStream] Emitting periodic update: ${updated.length}',
        );
        yield updated;
      }
    });
  }

  @override
  Future<List<NotificationModel>> getNotifications(
    String parentId, {
    String? childId,
    int? limit,
  }) async {
    try {
      if (childId != null) {
        // Get notifications for specific child
        Query query = firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .doc(childId)
            .collection('notifications')
            .orderBy('timestamp', descending: true);

        if (limit != null) {
          query = query.limit(limit);
        }

        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList();
      } else {
        // Get notifications from all children (aggregate)
        final childrenSnapshot = await firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .get();

        final List<NotificationModel> allNotifications = [];

        for (final childDoc in childrenSnapshot.docs) {
          Query query = firestore
              .collection('parents')
              .doc(parentId)
              .collection('children')
              .doc(childDoc.id)
              .collection('notifications')
              .orderBy('timestamp', descending: true);

          if (limit != null) {
            query = query.limit(limit);
          }

          final snapshot = await query.get();
          allNotifications.addAll(
            snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)),
          );
        }

        // Sort by timestamp descending
        allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Apply limit to final list if specified
        if (limit != null && allNotifications.length > limit) {
          return allNotifications.take(limit).toList();
        }

        return allNotifications;
      }
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      return [];
    }
  }

  @override
  Future<void> markAsRead(
    String parentId,
    String childId,
    String notificationId,
  ) async {
    try {
      await firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead(String parentId, {String? childId}) async {
    try {
      final batch = firestore.batch();

      if (childId != null) {
        // Mark all as read for specific child
        final snapshot = await firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .doc(childId)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .get();

        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Mark all as read for all children
        final childrenSnapshot = await firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .get();

        for (final childDoc in childrenSnapshot.docs) {
          final snapshot = await firestore
              .collection('parents')
              .doc(parentId)
              .collection('children')
              .doc(childDoc.id)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .get();

          for (var doc in snapshot.docs) {
            batch.update(doc.reference, {
              'isRead': true,
              'readAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteNotification(
    String parentId,
    String childId,
    String notificationId,
  ) async {
    try {
      await firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      rethrow;
    }
  }
}
