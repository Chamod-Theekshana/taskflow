import '../../../../core/network/api_client.dart';

typedef PushResponse = ({
  Map<String, String> statusById,
  String? settingsStatus,
});

typedef PullPage = ({
  List<Map<String, dynamic>> tasks,
  Map<String, dynamic>? settings,
  int cursor,
  bool hasMore,
});

/// `POST /sync/push` and `GET /sync/pull`.
class SyncRemoteDataSource {
  SyncRemoteDataSource(this._api);

  final ApiClient _api;

  Future<PushResponse> push({
    required List<Map<String, dynamic>> changes,
    Map<String, dynamic>? settings,
  }) async {
    final body = await _api.post(
      '/sync/push',
      body: {'changes': changes, 'settings': ?settings},
    );
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (
      statusById: {
        for (final r in (data['results'] as List? ?? const []))
          if (r is Map) '${r['id']}': '${r['status']}',
      },
      settingsStatus: data['settings'] as String?,
    );
  }

  Future<PullPage> pull(int cursor, {int limit = 500}) async {
    final body = await _api.get(
      '/sync/pull',
      query: {'cursor': cursor, 'limit': limit},
    );
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (
      tasks: [
        for (final t in (data['tasks'] as List? ?? const []))
          if (t is Map<String, dynamic>) t,
      ],
      settings: data['settings'] as Map<String, dynamic>?,
      cursor: (data['cursor'] as num?)?.toInt() ?? cursor,
      hasMore: data['hasMore'] == true,
    );
  }
}
