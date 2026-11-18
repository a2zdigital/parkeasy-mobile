import 'package:freezed_annotation/freezed_annotation.dart';

part 'bay_option.freezed.dart';
part 'bay_option.g.dart';

/// A numbered bay the customer may choose, and whether it is free for the
/// window asked about. An estimate until the booking is made.
@freezed
abstract class BayOption with _$BayOption {
  const factory BayOption({
    required String id,
    required String label,
    @Default(<String>[]) List<String> features,
    required bool available,
  }) = _BayOption;

  factory BayOption.fromJson(Map<String, dynamic> json) =>
      _$BayOptionFromJson(json);
}

/// What a bay offers, as the API names it.
abstract final class BayFeatures {
  static const String accessible = 'accessible';
  static const String ev = 'ev';
  static const String covered = 'covered';

  static const List<String> all = [accessible, ev, covered];
}
