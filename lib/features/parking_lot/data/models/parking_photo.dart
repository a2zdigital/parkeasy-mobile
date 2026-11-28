import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_photo.freezed.dart';
part 'parking_photo.g.dart';

/// A photo of a facility. The url is signed and stops working after a few
/// minutes; reading the facility again gives fresh ones.
@freezed
abstract class ParkingPhoto with _$ParkingPhoto {
  const factory ParkingPhoto({required String id, required String url}) =
      _ParkingPhoto;

  factory ParkingPhoto.fromJson(Map<String, dynamic> json) =>
      _$ParkingPhotoFromJson(json);
}
