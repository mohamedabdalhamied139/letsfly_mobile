import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthResponse {
  final String accessToken;
  final UserModel user;

  const AuthResponse({required this.accessToken, required this.user});
}

class AuthRemoteDataSource {
  final ApiClient _client;

  AuthRemoteDataSource({required ApiClient client}) : _client = client;

  Future<AuthResponse> login(String username, String password) async {
    final res = await _client.post(
      ApiEndpoints.login,
      data: {
        'username': username.trim(),
        'password': password,
      },
    );

    final data = res.data as Map<String, dynamic>;
    final token = data['access_token'] as String? ?? '';
    final userMap = data['user'] as Map<String, dynamic>? ?? {};

    return AuthResponse(
      accessToken: token,
      user: UserModel.fromJson(userMap),
    );
  }

  Future<AuthResponse> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final res = await _client.post(
      ApiEndpoints.register,
      data: {
        'username': username.trim(),
        'display_name': displayName.trim(),
        'password': password,
      },
    );

    final data = res.data as Map<String, dynamic>;
    final token = data['access_token'] as String? ?? '';
    final userMap = data['user'] as Map<String, dynamic>? ?? {};

    return AuthResponse(
      accessToken: token,
      user: UserModel.fromJson(userMap),
    );
  }

  Future<UserModel> getMe() async {
    final res = await _client.get(ApiEndpoints.me);
    final data = res.data as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiEndpoints.logout);
    } catch (_) {}
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      ApiEndpoints.changePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }
}
