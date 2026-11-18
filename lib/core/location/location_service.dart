import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Why the device's position could not be read.
enum LocationFailure {
  /// Location is switched off in the phone's settings.
  serviceOff,

  /// The user said no this time; asking again is allowed.
  denied,

  /// The user said "never"; only the app's settings page can change it.
  deniedForever,

  /// The phone could not get a fix in time, or reported an error.
  unavailable,
}

class LocationException implements Exception {
  const LocationException(this.failure);

  final LocationFailure failure;
}

/// Where the phone is, to search for parking nearby.
typedef DevicePosition = ({double latitude, double longitude});

/// The phone's location. Only read when the user asks for it, only while
/// the app is open, and never sent anywhere except as the search point.
abstract class LocationService {
  /// Asks for permission when needed. Throws [LocationException].
  Future<DevicePosition> current();

  /// Opens this app's page in the phone's settings.
  Future<void> openSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<DevicePosition> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(LocationFailure.denied);
      case LocationPermission.deniedForever:
        throw const LocationException(LocationFailure.deniedForever);
      case LocationPermission.whileInUse ||
          LocationPermission.always ||
          LocationPermission.unableToDetermine:
        break;
    }

    try {
      // Street-level accuracy is enough to find parking nearby.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on TimeoutException {
      throw const LocationException(LocationFailure.unavailable);
    } on Exception {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
