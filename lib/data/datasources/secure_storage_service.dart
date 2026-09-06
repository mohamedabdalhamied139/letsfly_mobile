import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

/// Secure token and credentials storage abstraction.
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _kTokenKey = 'letsfly_access_token';
  static const String _kUserKey = 'letsfly_current_user';
  static const String _kLangKey = 'letsfly_selected_language';
  static const String _kAccountsKey = 'letsfly_saved_accounts';
  static const String _kActiveAccountKey = 'letsfly_active_account';

  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _kTokenKey, value: token);
    } catch (_) {
      _memoryFallback[_kTokenKey] = token;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _kTokenKey);
      return token ?? _memoryFallback[_kTokenKey];
    } catch (_) {
      return _memoryFallback[_kTokenKey];
    }
  }

  Future<void> deleteAccessToken() async {
    try {
      await _storage.delete(key: _kTokenKey);
    } catch (_) {}
    _memoryFallback.remove(_kTokenKey);
  }

  Future<void> saveUser(UserModel user) async {
    final raw = jsonEncode(user.toJson());
    try {
      await _storage.write(key: _kUserKey, value: raw);
    } catch (_) {
      _memoryFallback[_kUserKey] = raw;
    }
  }

  Future<UserModel?> getUser() async {
    try {
      final raw = await _storage.read(key: _kUserKey) ?? _memoryFallback[_kUserKey];
      if (raw != null && raw.isNotEmpty) {
        return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> deleteUser() async {
    try {
      await _storage.delete(key: _kUserKey);
    } catch (_) {}
    _memoryFallback.remove(_kUserKey);
  }

  Future<void> saveLanguage(String langCode) async {
    try {
      await _storage.write(key: _kLangKey, value: langCode);
    } catch (_) {
      _memoryFallback[_kLangKey] = langCode;
    }
  }

  Future<String?> getLanguage() async {
    try {
      return await _storage.read(key: _kLangKey) ?? _memoryFallback[_kLangKey];
    } catch (_) {
      return _memoryFallback[_kLangKey];
    }
  }
  Future<void> saveAccountProfile({required String username, required String password, required String displayName}) async {
    final accounts = await loadAccountProfiles();
    final normalized = username.trim().toLowerCase();
    final entry = {'username': normalized, 'password': password, 'display_name': displayName.trim().isEmpty ? normalized : displayName.trim()};
    final index = accounts.indexWhere((a) => '${a['username']}'.trim().toLowerCase() == normalized);
    if (index >= 0) { accounts[index] = entry; } else { accounts.add(entry); }
    await _writeAccounts(accounts);
    await _writeSecure(_kActiveAccountKey, normalized);
  }

  Future<List<Map<String,dynamic>>> loadAccountProfiles() async {
    try {
      final raw = await _storage.read(key: _kAccountsKey) ?? _memoryFallback[_kAccountsKey];
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>'${e['username'] ?? ''}'.trim().isNotEmpty).toList();
    } catch (_) { return []; }
  }

  Future<String?> activeAccountUsername() async => _readSecure(_kActiveAccountKey);

  Future<void> removeAccountProfile(String username) async {
    final normalized=username.trim().toLowerCase();
    final accounts=await loadAccountProfiles();
    accounts.removeWhere((a)=>'${a['username'] ?? ''}'.trim().toLowerCase()==normalized);
    await _writeAccounts(accounts);
    if ((await activeAccountUsername())?.toLowerCase()==normalized) {
      await _writeSecure(_kActiveAccountKey, accounts.isEmpty ? '' : '${accounts.first['username']}');
    }
  }

  Future<void> setActiveAccountProfile(String username) async {
    final normalized=username.trim().toLowerCase();
    final accounts=await loadAccountProfiles();
    if (accounts.any((a)=>'${a['username'] ?? ''}'.trim().toLowerCase()==normalized)) await _writeSecure(_kActiveAccountKey, normalized);
  }

  Future<void> _writeAccounts(List<Map<String,dynamic>> accounts) async => _writeSecure(_kAccountsKey, jsonEncode(accounts));
  Future<void> _writeSecure(String key, String value) async { try { await _storage.write(key:key,value:value); } catch (_) { _memoryFallback[key]=value; } }
  Future<String?> _readSecure(String key) async { try { return await _storage.read(key:key) ?? _memoryFallback[key]; } catch (_) { return _memoryFallback[key]; } }

}
