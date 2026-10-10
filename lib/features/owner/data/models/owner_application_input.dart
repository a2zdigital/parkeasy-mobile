import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner_application_input.freezed.dart';
part 'owner_application_input.g.dart';

/// The body of an owner application.
@freezed
abstract class OwnerApplicationInput with _$OwnerApplicationInput {
  const factory OwnerApplicationInput({
    required String businessName,
    required String contactPhone,
  }) = _OwnerApplicationInput;

  factory OwnerApplicationInput.fromJson(Map<String, dynamic> json) =>
      _$OwnerApplicationInputFromJson(json);
}
