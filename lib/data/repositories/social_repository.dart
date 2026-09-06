import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// Complete mobile social facade matching the authoritative Windows/server API.
class SocialRepository {
  final ApiClient client;
  SocialRepository({required this.client});

  Future<Map<String, dynamic>> friends() async => _map(await client.get(ApiEndpoints.friends));
  Future<Map<String, dynamic>> onlineUsers() async => _map(await client.get(ApiEndpoints.onlineUsers));
  Future<Map<String, dynamic>> notifications({int limit = 100}) async => _map(await client.get(ApiEndpoints.notifications, queryParameters: {'limit': limit}));
  Future<Map<String, dynamic>> messages({int limit = 100}) async => _map(await client.get(ApiEndpoints.messages, queryParameters: {'limit': limit}));
  Future<Map<String, dynamic>> search(String q) async => _map(await client.get('/api/users/search', queryParameters: {'q': q}));
  Future<Map<String, dynamic>> profile(int id) async => _map(await client.get('/api/users/$id/profile'));
  Future<Map<String, dynamic>> updateProfile({String? displayName, String? gender, String? bio}) async => _map(await client.put('/api/users/me/profile', data: {'display_name': displayName, 'gender': gender, 'bio': bio}));
  Future<void> deleteAccount() async { await client.delete('/api/users/me'); }

  Future<void> sendFriendRequest(int id) async { await client.post('/api/friends/requests/$id'); }
  Future<void> acceptFriendRequest(int id) async { await client.post('/api/friends/requests/$id/accept'); }
  Future<void> rejectFriendRequest(int id) async { await client.post('/api/friends/requests/$id/reject'); }
  Future<void> cancelFriendRequest(int id) async { await client.delete('/api/friends/requests/$id'); }
  Future<void> unfriend(int id) async { await client.delete('/api/friends/$id'); }
  Future<void> block(int id) async { await client.post('/api/users/$id/block'); }
  Future<void> unblock(int id) async { await client.delete('/api/users/$id/block'); }
  Future<Map<String, dynamic>> blocked() async => _map(await client.get(ApiEndpoints.blockedUsers));
  Future<Map<String, dynamic>> headToHead(int id) async => _map(await client.get('/api/users/$id/head-to-head'));
  Future<void> message(int id, String text) async { await client.post('/api/users/$id/messages', data: {'message': text}); }
  Future<void> gift(int id, int amount) async { await client.post('/api/users/$id/gift', data: {'amount': amount}); }
  Future<Map<String, dynamic>> challenge(int id, String game) async => _map(await client.post('/api/users/$id/challenge', data: {'game': game}));
  Future<void> inviteToRoom(int userId, String roomId) async { await client.post('/api/rooms/$roomId/invite/$userId'); }
  Future<Map<String, dynamic>> acceptInvitation(int id) async => _map(await client.post('/api/invitations/$id/accept'));
  Future<void> rejectInvitation(int id) async { await client.post('/api/invitations/$id/reject'); }
  Future<Map<String, dynamic>> wallet() async => _map(await client.get(ApiEndpoints.wallet));
  Future<void> feedback(String message) async { await client.post(ApiEndpoints.feedback, data: {'message': message}); }
  Future<void> privacy({String? pmPolicy, String? invitePolicy, String? joinPolicy}) async {
    await client.put(ApiEndpoints.privacy, data: {
      if (pmPolicy != null) 'pm_policy': pmPolicy,
      if (invitePolicy != null) 'invite_policy': invitePolicy,
      if (joinPolicy != null) 'join_policy': joinPolicy,
    });
  }
  Future<Map<String, dynamic>> getMutes(int userId) async => _map(await client.get('/api/users/$userId/mutes'));
  Future<void> setMutes(int userId, Map<String, dynamic> flags) async { await client.put('/api/users/$userId/mutes', data: flags); }

  Map<String, dynamic> _map(dynamic response) {
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}
