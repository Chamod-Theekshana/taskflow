import '../../../../core/network/api_client.dart';

/// `PUT /devices/{installationId}`: tells the server about this install and
/// its push token.
class DeviceRemoteDataSource {
  DeviceRemoteDataSource(this._api);

  final ApiClient _api;

  Future<void> register({
    required String installationId,
    required String platform,
    required String? pushToken,
    required String appVersion,
    required String timezone,
  }) async {
    await _api.put(
      '/devices/$installationId',
      body: {
        'platform': platform,
        'pushToken': pushToken,
        'appVersion': appVersion,
        'timezone': timezone,
        // The app schedules reminders and the digest locally; the server only
        // pushes what this device can't know about yet.
        'localReminders': true,
      },
    );
  }
}
