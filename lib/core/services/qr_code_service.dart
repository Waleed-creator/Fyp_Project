import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

class QRCodeService {
  static Map<String, dynamic> generateUserProfileQRData({
    required String uid,
    required String name,
    required String email,
    required String userType,
  }) {
    return {
      'type': 'user_profile',
      'uid': uid,
      'name': name,
      'email': email,
      'userType': userType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Map<String, dynamic> generateFamilyInviteQRData({
    required String familyId,
    required String inviterName,
    required String inviterEmail,
  }) {
    return {
      'type': 'family_invite',
      'familyId': familyId,
      'inviterName': inviterName,
      'inviterEmail': inviterEmail,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Map<String, dynamic> generateDevicePairingQRData({
    required String deviceId,
    required String deviceName,
    required String ownerUid,
  }) {
    return {
      'type': 'device_pairing',
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ownerUid': ownerUid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Map<String, dynamic> generateChildLinkQRData({
    required String parentUid,
    required String firstName,
    required String lastName,
    required String childName,
    required int age,
    required String gender,
    required List<String> hobbies,
  }) {
    return {
      'type': 'child_link',
      'parentUid': parentUid,
      'childData': {
        'firstName': firstName,
        'lastName': lastName,
        'name': childName,
        'age': age,
        'gender': gender,
        'hobbies': hobbies,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static String dataToJson(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  static Map<String, dynamic>? jsonToData(String jsonString) {
    try {
      if (jsonString.trim().startsWith('{') || jsonString.trim().startsWith('[')) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } else {
        debugPrint('String does not look like JSON: $jsonString');
        return null;
      }
    } catch (e) {
      debugPrint('JSON parsing error: $e');
      return null;
    }
  }

  /// Generate QR code widget
  static Widget generateQRWidget({
    required String data,
    double size = 200.0,
    Color? foregroundColor,
    Color? backgroundColor,
    String? errorText,
  }) {
    final fgColor = foregroundColor ?? Colors.black;
    final bgColor = backgroundColor ?? Colors.white;

    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: bgColor,                        // still supported for background
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: fgColor,                                // ← replaces foregroundColor for eyes
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: fgColor,                                // ← replaces foregroundColor for dots
      ),
      errorStateBuilder: (context, error) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: size * 0.3),
                SizedBox(height: 8),
                Text(
                  errorText ?? 'QR Code Error',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget generateUserProfileQR({
    required Map<String, dynamic> userData,
    double size = 200.0,
    String? title,
  }) {
    final qrData = dataToJson(userData);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
          ],
          generateQRWidget(
            data: qrData,
            size: size,
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
          ),
          SizedBox(height: 12),
          Text(
            'Scan to add user',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  static Widget generateFamilyInviteQR({
    required Map<String, dynamic> inviteData,
    double size = 200.0,
  }) {
    final qrData = dataToJson(inviteData);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.family_restroom, color: Colors.blue[700], size: 32),
          SizedBox(height: 8),
          Text(
            'Family Invite',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(height: 12),
          generateQRWidget(
            data: qrData,
            size: size,
            foregroundColor: Colors.blue[800],
            backgroundColor: Colors.white,
          ),
          SizedBox(height: 12),
          Text(
            'Scan to join family',
            style: TextStyle(fontSize: 14, color: Colors.blue[600]),
          ),
        ],
      ),
    );
  }
}