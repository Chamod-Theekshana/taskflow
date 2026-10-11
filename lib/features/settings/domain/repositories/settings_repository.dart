import '../settings.dart';

/// Where the preferences are kept, and what the sync engine needs to
/// replicate them.
abstract class SettingsRepository {
  AppSettings load();

  /// Saves a change made on this device (it will be uploaded).
  Future<void> save(AppSettings settings);

  /// Local edits not uploaded yet, or null when there are none.
  ({AppSettings settings, DateTime updatedAt})? pendingUpload();

  /// Called after an upload; keeps the flag if the settings changed since.
  Future<void> markUploaded(DateTime updatedAt);

  /// Settings from the server. Ignored when a newer local edit is waiting.
  /// Returns whether anything was applied.
  Future<bool> applyRemote(AppSettings settings, DateTime updatedAt);

  /// Called when [userId] starts syncing on this device. If another account
  /// used it before, that account's unsent edits are not uploaded to this
  /// one. Returns true when the owner changed (the caller then re-pulls this
  /// account's settings).
  Future<bool> claimForUser(String userId);
}
