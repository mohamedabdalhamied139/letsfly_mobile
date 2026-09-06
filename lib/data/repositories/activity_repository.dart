import 'dart:async';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// Canonical activity data source. REST provides history; the lobby WebSocket
/// feeds the same stream for live events, matching the Windows single-log model.
class ActivityRepository {
  final ApiClient client;
  final StreamController<Map<String,dynamic>> _liveController = StreamController<Map<String,dynamic>>.broadcast();
  ActivityRepository({required this.client});

  Stream<Map<String,dynamic>> get liveEvents => _liveController.stream;
  void publishLiveEvent(Map<String,dynamic> event) { if (!_liveController.isClosed) _liveController.add(Map<String,dynamic>.from(event)); }

  Future<List<Map<String, dynamic>>> feed({int limit = 100, int? beforeId, String? category}) async {
    final response = await client.get(ApiEndpoints.activityFeed, queryParameters: {
      'limit': limit,
      if (beforeId != null) 'before_id': beforeId,
      if (category != null && category.toUpperCase() != 'ALL') 'category': category.toUpperCase(),
    });
    final data = response.data;
    final rows = data is Map ? data['events'] ?? data['activity'] : data;
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> markRead({String? category, int? eventId}) async {
    await client.post(ApiEndpoints.activityFeed + '/read', data: {
      if (category != null) 'category': category,
      if (eventId != null) 'event_id': eventId,
    });
  }

  Future<void> clear() async { await client.delete(ApiEndpoints.clearActivity()); }
  Future<void> dispose() async { await _liveController.close(); }
}
