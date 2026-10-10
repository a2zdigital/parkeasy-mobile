import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The access token and when it stops working.
class StoredToken {
  const StoredToken({required this.value, required this.expiresAt});

  final String value;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}

/// Where the access token lives. Only `core/auth` and the API client
/// touch this; nothing else may read the token.
abstract interface class TokenStore {
  Future<StoredToken?> read();
  Future<void> write(StoredToken token);
  Future<void> clear();
}

/// Keeps the token in the Keychain (iOS) or the Keystore-backed
/// encrypted storage (Android). Never in preferences, a file or a log.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Not copied to a new device or to iCloud backups, and only
            // readable after the device has been unlocked once.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _tokenKey = 'auth.token';
  static const _expiryKey = 'auth.token_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredToken?> read() async {
    final value = await _storage.read(key: _tokenKey);
    final expiry = DateTime.tryParse(
      await _storage.read(key: _expiryKey) ?? '',
    );
    if (value == null || value.isEmpty || expiry == null) {
      return null;
    }
    return StoredToken(value: value, expiresAt: expiry.toUtc());
  }

  @override
  Future<void> write(StoredToken token) async {
    await _storage.write(key: _tokenKey, value: token.value);
    await _storage.write(
      key: _expiryKey,
      value: token.expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiryKey);
  }
}
