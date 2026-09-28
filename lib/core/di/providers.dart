import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// The opened app database. Overridden in `main()` once it has been opened.
final dbProviderProvider = Provider<Database>(
  (ref) => throw UnimplementedError('dbProviderProvider must be overridden'),
);

/// SharedPreferences instance. Overridden in `main()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);
