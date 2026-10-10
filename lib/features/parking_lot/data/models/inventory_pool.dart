import 'package:app/features/parking_lot/data/models/allocation_mode.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/parking_lot/data/models/pool_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_pool.freezed.dart';
part 'inventory_pool.g.dart';

/// The spaces a facility offers for one vehicle type, and their rates.
@freezed
abstract class InventoryPool with _$InventoryPool {
  const factory InventoryPool({
    required String id,
    required CodeName vehicleType,
    @JsonKey(unknownEnumValue: AllocationMode.unknown)
    @Default(AllocationMode.pooled)
    AllocationMode allocationMode,
    required int capacity,
    @Default(true) bool isActive,
    @Default(<PoolRate>[]) List<PoolRate> rates,
  }) = _InventoryPool;

  factory InventoryPool.fromJson(Map<String, dynamic> json) =>
      _$InventoryPoolFromJson(json);
}
