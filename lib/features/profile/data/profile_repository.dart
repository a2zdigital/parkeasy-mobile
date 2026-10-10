import 'package:app/core/api/api_client.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

class ProfileRepository {
  const ProfileRepository(this._api);

  final ApiClient _api;

  /// Changes the signed-in user's name and email. A null email is left
  /// as it is.
  Future<User> update({required String name, String? email}) async {
    final envelope = await _api.patch(
      '/me',
      body: {'name': name, if (email != null) 'email': email},
    );
    return User.fromJson(ApiClient.object(envelope));
  }
}
