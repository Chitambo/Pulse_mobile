import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_constants.dart';
import '../core/auth/token_storage.dart';
import '../core/database/cache_store.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _error;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get error => _error;
  bool get isLoading => _status == AuthStatus.unknown;

  AuthProvider() {
    _api.onLogout = _handleLogout;
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Restore cached user immediately — no network wait.
      try {
        final cachedUser = await TokenStorage.getUser();
        if (cachedUser != null) {
          _user = AuthUser.fromJson(cachedUser);
          _status = AuthStatus.authenticated;
          notifyListeners();
          _refreshUserSilently(); // verify in background
          return;
        }
      } catch (_) {
        // Corrupted cache — fall through to network fetch.
      }

      // No cached user — fetch from network once.
      try {
        final res = await _api.dio.get(ApiConstants.me);
        _user = AuthUser.fromJson(res.data);
        await TokenStorage.saveUser(res.data as Map<String, dynamic>);
        _status = AuthStatus.authenticated;
      } catch (_) {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    } catch (_) {
      // Secure storage unavailable (keystore issue) — show login.
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _refreshUserSilently() async {
    try {
      final res = await _api.dio.get(ApiConstants.me);
      _user = AuthUser.fromJson(res.data);
      await TokenStorage.saveUser(res.data as Map<String, dynamic>);
      notifyListeners();
    } on DioException catch (e) {
      // Only force logout on explicit 401 — network errors keep the cached session.
      if (e.response?.statusCode == 401) _handleLogout();
    } catch (_) {
      // Ignore parse/storage errors — keep showing cached user.
    }
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    try {
      final res = await _api.dio.post(ApiConstants.login, data: {
        'username': username,
        'password': password,
      });
      await TokenStorage.save(
        token: res.data['token'],
        refreshToken: res.data['refreshToken'],
      );
      await TokenStorage.saveUser(res.data['user'] as Map<String, dynamic>);
      _user = AuthUser.fromJson(res.data['user']);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      await _api.dio.put(ApiConstants.changePassword, data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      if (_user != null) {
        _user = AuthUser(
          id: _user!.id,
          username: _user!.username,
          email: _user!.email,
          role: _user!.role,
          employee: _user!.employee,
          mustChangePassword: false,
        );
      }
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Failed to change password';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await _api.dio.post(ApiConstants.logout, data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    _handleLogout();
  }

  void _handleLogout() {
    TokenStorage.clear();
    CacheStore().clearAll();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> registerFcmToken(String fcmToken, String platform) async {
    try {
      await _api.dio.post(ApiConstants.deviceToken, data: {
        'fcmToken': fcmToken,
        'platform': platform,
      });
    } catch (_) {}
  }

  Future<void> refreshUser() async {
    try {
      final res = await _api.dio.get(ApiConstants.me);
      _user = AuthUser.fromJson(res.data);
      notifyListeners();
    } catch (_) {}
  }
}
