import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/db_provider.dart';

final dbProviderProvider = Provider<Database>((ref) => throw UnimplementedError());

final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());
