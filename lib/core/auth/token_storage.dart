import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  // EncryptedSharedPreferences avoids the RSA keystore error (-1000).
  // resetOnError clears corrupted backup-restored data instead of hanging.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );
  static const _keyToken = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUser = 'cached_user';

  static Future<void> save({required String token, required String refreshToken}) async {
    try {
      await Future.wait([
        _storage.write(key: _keyToken, value: token),
        _storage.write(key: _keyRefresh, value: refreshToken),
      ]);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      await _recoverStorage();
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefresh);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      await _storage.write(key: _keyUser, value: jsonEncode(user));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final s = await _storage.read(key: _keyUser);
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyToken),
        _storage.delete(key: _keyRefresh),
        _storage.delete(key: _keyUser),
      ]);
    } catch (_) {
      await _recoverStorage();
    }
  }

  /// Wipes all secure storage when the keystore is corrupted.
  /// Forces a fresh login rather than hanging forever.
  static Future<void> _recoverStorage() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
