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

  /// Changes the signed-in user's name and, when [includeEmail] is true,
  /// their email. A null included email clears it.
  Future<User> update({
    String? name,
    String? email,
    bool includeEmail = false,
  }) async {
    final envelope = await _api.patch(
      '/me',
      body: {if (name != null) 'name': name, if (includeEmail) 'email': email},
    );
    return User.fromJson(ApiClient.object(envelope));
  }
}
