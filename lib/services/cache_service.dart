import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static const String _routePrefix = 'route_';
  static const String _timestampPrefix = 'timestamp_';
  static const Duration _cacheExpiration = Duration(hours: 24);
  final SharedPreferences _prefs;

  CacheService(this._prefs);

  String _generateKey(LatLng start, LatLng end) {
    return '$_routePrefix${start.latitude},${start.longitude}_${end.latitude},${end.longitude}';
  }

  Future<void> cacheRoute(LatLng start, LatLng end, Map<String, dynamic> routeData) async {
    try {
      final key = _generateKey(start, end);
      final jsonData = json.encode(routeData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await Future.wait([
        _prefs.setString(key, jsonData),
        _prefs.setInt('$_timestampPrefix$key', timestamp),
      ]);
    } catch (e) {
      debugPrint('Cache error: $e');
      // Rethrow to handle in BLoC
      rethrow;
    }
  }

  Map<String, dynamic>? getCachedRoute(LatLng start, LatLng end) {
    try {
      final key = _generateKey(start, end);
      final timestamp = _prefs.getInt('$_timestampPrefix$key');
      
      if (timestamp == null) return null;
      
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _cacheExpiration.inMilliseconds) {
        // Clean up expired cache
        Future.wait([
          _prefs.remove(key),
          _prefs.remove('$_timestampPrefix$key'),
        ]);
        return null;
      }

      final data = _prefs.getString(key);
      return data != null ? json.decode(data) : null;
    } catch (e) {
      debugPrint('Cache retrieval error: $e');
      return null;
    }
  }
}
