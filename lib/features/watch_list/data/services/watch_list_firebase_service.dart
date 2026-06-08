import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watch_list_contact_model.dart';
import 'package:flutter/foundation.dart';

class WatchListFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add contact to watch list
  Future<void> addContactToWatchList({
    required String parentId,
    required String childId,
    required String contactName,
    required String phoneNumber,
  }) async {
    try {
      // Normalize phone number (remove spaces, dashes, etc.)
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      
      // Check if contact already exists
      final existingContact = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('watchList')
          .where('phoneNumber', isEqualTo: normalizedNumber)
          .get();

      if (existingContact.docs.isNotEmpty) {
        throw Exception('Contact with this phone number already exists in Watch List');
      }

      // Add contact
      final docRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('watchList')
          .doc();

      final contact = WatchListContactModel(
        id: docRef.id,
        parentId: parentId,
        childId: childId,
        contactName: contactName,
        phoneNumber: normalizedNumber,
        createdAt: DateTime.now(),
      );

      await docRef.set(contact.toMap());
      debugPrint('✅ Contact added to watch list: $contactName ($normalizedNumber)');
    } catch (e) {
      debugPrint('❌ Error adding contact to watch list: $e');
      rethrow;
    }
  }

  /// Get all contacts in watch list for a child
  Future<List<WatchListContactModel>> getWatchListContacts({
    required String parentId,
    required String childId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('watchList')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WatchListContactModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting watch list contacts: $e');
      return [];
    }
  }

  /// Stream watch list contacts
  Stream<List<WatchListContactModel>> streamWatchListContacts({
    required String parentId,
    required String childId,
  }) {
    return _firestore
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .doc(childId)
        .collection('watchList')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WatchListContactModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Delete contact from watch list
  Future<void> deleteContactFromWatchList({
    required String parentId,
    required String childId,
    required String contactId,
  }) async {
    try {
      await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('watchList')
          .doc(contactId)
          .delete();
      debugPrint('✅ Contact removed from watch list: $contactId');
    } catch (e) {
      debugPrint('❌ Error deleting contact from watch list: $e');
      rethrow;
    }
  }

  /// Check if a phone number is in watch list
  Future<bool> isNumberInWatchList({
    required String parentId,
    required String childId,
    required String phoneNumber,
  }) async {
    try {
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      
      final snapshot = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('watchList')
          .where('phoneNumber', isEqualTo: normalizedNumber)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking watch list: $e');
      return false;
    }
  }

  /// Get watch list contact by phone number
  Future<WatchListContactModel?> getContactByPhoneNumber({
    required String parentId,
    required String childId,
    required String phoneNumber,
  }) async {
    try {
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      
      final snapshot = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('watchList')
          .where('phoneNumber', isEqualTo: normalizedNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return WatchListContactModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('❌ Error getting contact by phone number: $e');
      return null;
    }
  }

  /// Normalize phone number (remove spaces, dashes, parentheses, etc.)
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }
}

