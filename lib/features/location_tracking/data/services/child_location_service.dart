import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/location_model.dart';
import '../datasources/location_remote_datasource.dart';
import 'package:flutter/foundation.dart';

class ChildLocationService {
  final LocationRemoteDataSource _locationDataSource;
  final FirebaseFirestore _firestore;
  
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<BatteryState>? _batteryStream;
  Timer? _locationTimer;
  Timer? _batteryTimer;
  String? _parentId;
  String? _childId;
  bool _isTracking = false;
  final Battery _battery = Battery();

  ChildLocationService({
    required LocationRemoteDataSource locationDataSource,
    FirebaseFirestore? firestore,
  }) : _locationDataSource = locationDataSource,
       _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialize location tracking for child
  Future<void> initializeLocationTracking() async {
    try {
      // Get parent and child IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _parentId = prefs.getString('parent_uid');
      _childId = prefs.getString('child_uid');

      if (_parentId == null || _childId == null) {
        debugPrint('Parent or child ID not found in SharedPreferences');
        return;
      }

      debugPrint('Initialized location tracking for child: $_childId');
    } catch (e) {
      debugPrint('Error initializing location tracking: $e');
    }
  }

  /// Start location tracking
  Future<void> startLocationTracking() async {
    if (_parentId == null || _childId == null) {
      await initializeLocationTracking();
      if (_parentId == null || _childId == null) {
        throw Exception('Parent or child ID not found');
      }
    }

    // Check if already tracking
    if (_isTracking) {
      debugPrint('Location tracking already active');
      return;
    }

    try {
      debugPrint('Starting location tracking...');
      _isTracking = true;

      // Request location permission
      debugPrint('📍 [ChildLocation] Checking location permission...');
      final permission = await Geolocator.checkPermission();
      debugPrint('📍 [ChildLocation] Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('📍 [ChildLocation] Permission denied, requesting...');
        final newPermission = await Geolocator.requestPermission();
        debugPrint('📍 [ChildLocation] Permission request result: $newPermission');
        if (newPermission == LocationPermission.denied || newPermission == LocationPermission.deniedForever) {
          debugPrint('❌ [ChildLocation] Location permission denied or denied forever');
          throw Exception('Location permission denied');
        }
      }
      
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ [ChildLocation] Location services are disabled');
        throw Exception('Location services are disabled. Please enable location in device settings.');
      }
      debugPrint('✅ [ChildLocation] Location services enabled');

      // Enable location services
      await _locationDataSource.enableLocationTracking(
        parentId: _parentId!,
        childId: _childId!,
        enabled: true,
      );

      // Start listening to location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) => _onLocationUpdate(position),
        onError: (error) => debugPrint('Location stream error: $error'),
      );

      // Start battery tracking
      _startBatteryTracking();

      debugPrint('Location tracking started for child: $_childId');
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      _isTracking = false;
      rethrow;
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    try {
      debugPrint('Stopping location tracking...');
      _isTracking = false;
      
      // Cancel position stream
      await _positionStream?.cancel();
      _positionStream = null;
      
      // Cancel timer
      _locationTimer?.cancel();
      _locationTimer = null;
      
      // Update Firebase that tracking is disabled
      if (_parentId != null && _childId != null) {
        await _locationDataSource.enableLocationTracking(
          parentId: _parentId!,
          childId: _childId!,
          enabled: false,
        );
      }

      debugPrint('Location tracking stopped successfully');
    } catch (e) {
      debugPrint('Error stopping location tracking: $e');
    }
  }

  /// Handle location updates
  Future<void> _onLocationUpdate(Position position) async {
    if (!_isTracking || _parentId == null || _childId == null) {
      return;
    }

    try {
      // Get address from coordinates
      String address = 'Location not available';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}';
          address = address.replaceAll(RegExp(r',\s*,'), ',').trim();
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      // Create location model
      final location = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
        isTrackingEnabled: true,
        status: 'online',
      );

      // Get battery level
      int batteryLevel = 0;
      try {
        batteryLevel = await _battery.batteryLevel;
        debugPrint('🔋 [ChildLocation] Battery level retrieved: $batteryLevel%');
      } catch (e) {
        debugPrint('⚠️ [ChildLocation] Error getting battery level: $e');
      }
      
      // Update location in Firebase (also includes battery)
      debugPrint('📍 [ChildLocation] Updating location to Firebase...');
      debugPrint('📍 [ChildLocation] ParentId: $_parentId, ChildId: $_childId');
      debugPrint('📍 [ChildLocation] Location: ${position.latitude}, ${position.longitude}');
      debugPrint('📍 [ChildLocation] Address: ${location.address}');
      
      await _locationDataSource.updateChildLocation(
        parentId: _parentId!,
        childId: _childId!,
        location: location,
      );
      
      debugPrint('✅ [ChildLocation] Location updated in Firebase');
      
      // Update battery level in child document
      try {
        await _firestore
            .collection('parents')
            .doc(_parentId!)
            .collection('children')
            .doc(_childId!)
            .update({
          'batteryLevel': batteryLevel,
          'batteryUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ [ChildLocation] Battery level updated: $batteryLevel%');
      } catch (e) {
        debugPrint('❌ [ChildLocation] Error updating battery level: $e');
      }

      debugPrint('✅ [ChildLocation] Location updated: ${position.latitude}, ${position.longitude}');
      debugPrint('🔋 [ChildLocation] Battery level: $batteryLevel%');
    } catch (e) {
      debugPrint('❌ [ChildLocation] Error updating location: $e');
      debugPrint('   Stack trace: ${e.toString()}');
    }
  }

  /// Check if location tracking is active
  bool get isTrackingActive => _isTracking;

  /// Start battery tracking
  Future<void> _startBatteryTracking() async {
    try {
      // Update battery immediately
      await _updateBatteryLevel();
      
      // Update battery every 30 seconds
      _batteryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _updateBatteryLevel();
      });
      
      // Also listen to battery state changes
      _batteryStream = _battery.onBatteryStateChanged.listen((BatteryState state) {
        _updateBatteryLevel();
      });
    } catch (e) {
      debugPrint('Error starting battery tracking: $e');
    }
  }

  /// Update battery level in Firebase
  Future<void> _updateBatteryLevel() async {
    if (_parentId == null || _childId == null) return;
    
    try {
      final batteryLevel = await _battery.batteryLevel;
      await _firestore
          .collection('parents')
          .doc(_parentId!)
          .collection('children')
          .doc(_childId!)
          .update({
        'batteryLevel': batteryLevel,
        'batteryUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔋 [ChildLocation] Battery level updated: $batteryLevel%');
    } catch (e) {
      debugPrint('Error updating battery level: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    debugPrint('Disposing ChildLocationService...');
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    _batteryStream?.cancel();
    _batteryStream = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _batteryTimer?.cancel();
    _batteryTimer = null;
    
    debugPrint('ChildLocationService disposed');
  }
}
