import 'package:freezed_annotation/freezed_annotation.dart';

part 'parking_space.freezed.dart';
part 'parking_space.g.dart';

/// One numbered bay in a pool, such as "B1-07".
@freezed
abstract class ParkingSpace with _$ParkingSpace {
  const factory ParkingSpace({
    required String id,
    required String label,
    @Default(<String>[]) List<String> features,
    @Default(true) bool isActive,
  }) = _ParkingSpace;

  factory ParkingSpace.fromJson(Map<String, dynamic> json) =>
      _$ParkingSpaceFromJson(json);
}
