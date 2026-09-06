/// Centralized API routes and WebSocket endpoints for Let's Fly backend.
class ApiEndpoints {
  ApiEndpoints._();

  // Production remote server (same as Windows desktop client)
  static const String defaultHttpHost = 'https://letsfly.onrender.com';
  static const String defaultWsHost = 'wss://letsfly.onrender.com';
  static const String localHttpHost = 'https://letsfly.onrender.com';
  static const String localWsHost = 'wss://letsfly.onrender.com';

  // Auth Routes
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String me = '/api/auth/me';
  static const String changePassword = '/api/auth/change-password';
  static const String logout = '/api/auth/logout';

  // Room Routes
  static const String rooms = '/api/rooms';
  static const String createRoom = '/api/rooms';
  static String room(String roomId) => '/api/rooms/$roomId';
  static String joinRoom(String roomId) => '/api/rooms/$roomId/join';
  static String leaveRoom(String roomId) => '/api/rooms/$roomId/leave';
  static String startRoom(String roomId) => '/api/rooms/$roomId/start';
  static String stopRoom(String roomId) => '/api/rooms/$roomId/stop';
  static String roomAction(String roomId) => '/api/rooms/$roomId/game/action';
  static String addBot(String roomId) => '/api/rooms/$roomId/bot';
  static String removeBot(String roomId) => '/api/rooms/$roomId/bot';

  // Activity Routes
  static const String activityFeed = '/api/activity';
  static String clearActivity() => '/api/activity';

  // Social & Users Routes
  static const String users = '/api/users';
  static const String friends = '/api/friends';
  static const String friendRequests = '/api/friends/requests';
  static const String onlineUsers = '/api/users/online';
  static const String notifications = '/api/notifications';
  static const String messages = '/api/messages';
  static const String blockedUsers = '/api/users/blocked';
  static const String wallet = '/api/wallet';
  static const String feedback = '/api/feedback';
  static const String privacy = '/api/users/me/privacy';

  // WebSocket Channels
  static const String wsEvents = '/ws/events';
  static String wsRoom(String roomId) => '/ws/room/$roomId';
}
