import 'dart:async';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/secure_storage_service.dart';
import '../models/user_model.dart';
import '../../core/settings/settings_store.dart';

abstract class AuthRepository {
  Stream<UserModel?> get userStream;
  UserModel? get currentUser;
  Future<bool> isAuthenticated();
  Future<UserModel> login(String username, String password);
  Future<UserModel> register(String username, String displayName, String password);
  Future<void> logout();
  Future<UserModel?> checkAuth();
  Future<String?> getAccessToken();
  Future<List<Map<String,dynamic>>> savedAccounts();
  Future<void> switchSavedAccount(String username);
  Future<void> removeSavedAccount(String username);
  Future<void> changePassword({required String currentPassword, required String newPassword});
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;
  final SettingsStore? _settings;
  final StreamController<UserModel?> _userController = StreamController<UserModel?>.broadcast();
  UserModel? _cachedUser;
  String? _sessionToken;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService storageService,
    SettingsStore? settings,
  })  : _remoteDataSource = remoteDataSource,
        _storageService = storageService,
        _settings = settings;

  @override
  Stream<UserModel?> get userStream => _userController.stream;

  @override
  UserModel? get currentUser => _cachedUser;

  @override
  Future<bool> isAuthenticated() async {
    final token = await _storageService.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getAccessToken() async => _sessionToken ?? await _storageService.getAccessToken();

  @override
  Future<UserModel> login(String username, String password) async {
    final res = await _remoteDataSource.login(username, password);
    _sessionToken = res.accessToken;
    if (_settings?.keepCredentials != false) {
      await _storageService.saveAccessToken(res.accessToken);
      await _storageService.saveUser(res.user);
    } else {
      await _storageService.deleteAccessToken();
      await _storageService.deleteUser();
    }
    if (_settings?.keepCredentials != false) await _storageService.saveAccountProfile(username: username, password: password, displayName: res.user.displayName);
    _cachedUser = res.user;
    _userController.add(_cachedUser);
    return res.user;
  }

  @override
  Future<UserModel> register(String username, String displayName, String password) async {
    final res = await _remoteDataSource.register(
      username: username,
      displayName: displayName,
      password: password,
    );
    _sessionToken = res.accessToken;
    if (_settings?.keepCredentials != false) {
      await _storageService.saveAccessToken(res.accessToken);
      await _storageService.saveUser(res.user);
    } else {
      await _storageService.deleteAccessToken();
      await _storageService.deleteUser();
    }
    if (_settings?.keepCredentials != false) await _storageService.saveAccountProfile(username: username, password: password, displayName: res.user.displayName);
    _cachedUser = res.user;
    _userController.add(_cachedUser);
    return res.user;
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.logout();
    _sessionToken = null;
    await _storageService.deleteAccessToken();
    await _storageService.deleteUser();
    _cachedUser = null;
    _userController.add(null);
  }

  @override
  Future<UserModel?> checkAuth() async {
    final token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      _cachedUser = null;
      _userController.add(null);
      return null;
    }

    try {
      final user = await _remoteDataSource.getMe();
      await _storageService.saveUser(user);
      _cachedUser = user;
      _userController.add(_cachedUser);
      return user;
    } catch (_) {
      // Never treat a locally cached profile as authenticated after the
      // server rejects the bearer token. Windows follows the same rule.
      await _storageService.deleteAccessToken();
      _cachedUser = null;
      _userController.add(null);
      return null;
    }
  }
  @override Future<List<Map<String,dynamic>>> savedAccounts() => _storageService.loadAccountProfiles();
  @override Future<void> switchSavedAccount(String username) async {
    final accounts=await _storageService.loadAccountProfiles();
    final normalized=username.trim().toLowerCase();
    Map<String,dynamic>? a;
    for(final x in accounts){ if('${x['username'] ?? ''}'.trim().toLowerCase()==normalized){ a=x; break; } }
    if(a==null) return;
    await _storageService.setActiveAccountProfile(normalized);
    final user=await login('${a['username']}', '${a['password']}');
    _cachedUser=user;
  }
  @override Future<void> removeSavedAccount(String username) => _storageService.removeAccountProfile(username);
  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _remoteDataSource.changePassword(currentPassword: currentPassword, newPassword: newPassword);

}
