import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../config/app_config.dart';

class StorageService {
  static late Box _box;
  static late SharedPreferences _prefs;

  // Initialize storage services
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _box = await Hive.openBox('ash_storage');
  }

  // SharedPreferences methods
  static Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs.getString(key);
  }

  static Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs.getInt(key);
  }

  static Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  static Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  static Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  static Future<bool> clear() async {
    return await _prefs.clear();
  }

  // Hive methods for complex data
  static Future<void> put(String key, dynamic value) async {
    await _box.put(key, value);
  }

  static T? get<T>(String key) {
    return _box.get(key);
  }

  static Future<void> delete(String key) async {
    await _box.delete(key);
  }

  static Future<void> clearBox() async {
    await _box.clear();
  }

  // JSON storage helpers
  static Future<bool> setJson(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      return await setString(key, jsonString);
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic>? getJson(String key) {
    try {
      final jsonString = getString(key);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      // Handle JSON decode error
    }
    return null;
  }

  // User data storage
  static Future<bool> saveUserToken(String token) async {
    return await setString(AppConfig.userTokenKey, token);
  }

  static String? getUserToken() {
    return getString(AppConfig.userTokenKey);
  }

  static Future<bool> saveUserData(Map<String, dynamic> userData) async {
    return await setJson(AppConfig.userDataKey, userData);
  }

  static Map<String, dynamic>? getUserData() {
    return getJson(AppConfig.userDataKey);
  }

  static Future<bool> clearUserData() async {
    await remove(AppConfig.userTokenKey);
    await remove(AppConfig.userDataKey);
    return true;
  }

  // Settings storage
  static Future<bool> saveThemeMode(int themeMode) async {
    return await setInt(AppConfig.themeKey, themeMode);
  }

  static int? getThemeMode() {
    return getInt(AppConfig.themeKey);
  }

  static Future<bool> saveVoiceEnabled(bool enabled) async {
    return await setBool(AppConfig.voiceEnabledKey, enabled);
  }

  static bool? getVoiceEnabled() {
    return getBool(AppConfig.voiceEnabledKey);
  }

  static Future<bool> saveNotificationsEnabled(bool enabled) async {
    return await setBool(AppConfig.notificationsEnabledKey, enabled);
  }

  static bool? getNotificationsEnabled() {
    return getBool(AppConfig.notificationsEnabledKey);
  }

  // Chat history storage
  static Future<void> saveChatMessage(Map<String, dynamic> message) async {
    final messages = getChatHistory();
    messages.add(message);
    await put('chat_history', messages);
  }

  static List<Map<String, dynamic>> getChatHistory() {
    final messages = get<List<dynamic>>('chat_history') ?? [];
    return messages.cast<Map<String, dynamic>>();
  }

  static Future<void> clearChatHistory() async {
    await delete('chat_history');
  }

  // Event cache storage
  static Future<void> saveEvents(List<Map<String, dynamic>> events) async {
    await put('cached_events', events);
  }

  static List<Map<String, dynamic>>? getCachedEvents() {
    final events = get<List<dynamic>>('cached_events');
    return events?.cast<Map<String, dynamic>>();
  }

  static Future<void> clearEventCache() async {
    await delete('cached_events');
  }

  // Voice settings storage
  static Future<void> saveVoiceSettings(Map<String, dynamic> settings) async {
    await put('voice_settings', settings);
  }

  static Map<String, dynamic>? getVoiceSettings() {
    return get<Map<String, dynamic>>('voice_settings');
  }

  // App preferences storage
  static Future<void> saveAppPreferences(Map<String, dynamic> preferences) async {
    await put('app_preferences', preferences);
  }

  static Map<String, dynamic>? getAppPreferences() {
    return get<Map<String, dynamic>>('app_preferences');
  }

  // Clear all data
  static Future<void> clearAllData() async {
    await clear();
    await clearBox();
  }

  // Get storage size info
  static Future<Map<String, int>> getStorageInfo() async {
    final prefsSize = await _getSharedPreferencesSize();
    final hiveSize = _box.length;
    
    return {
      'preferences_size': prefsSize,
      'hive_entries': hiveSize,
    };
  }

  static Future<int> _getSharedPreferencesSize() async {
    final keys = _prefs.getKeys();
    int size = 0;
    
    for (final key in keys) {
      final value = _prefs.get(key);
      if (value is String) {
        size += value.length;
      } else if (value is List<String>) {
        size += value.join().length;
      }
    }
    
    return size;
  }
}

