// lib/features/lists/models/default_index.dart (Offline-only)
import 'package:shared_preferences/shared_preferences.dart';

class DefaultIndexStore {
  static const String favIndex = 'fav_index';
  static const String watchlistIndex = 'watchlist_index';
  static const String watchedIndex = 'watched_index';

  static String indexKeyForPrefix(String prefix) {
    switch (prefix) {
      case 'fav_':
        return favIndex;
      case 'watchlist_':
        return watchlistIndex;
      case 'watched_':
        return watchedIndex;
      default:
        return favIndex;
    }
  }

  static Future<List<String>> all(String indexKey) async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(indexKey) ?? <String>[];
  }

  static Future<List<String>> allByPrefix(String prefix) async {
    return all(indexKeyForPrefix(prefix));
  }

  static Future<void> add(String indexKey, String baseKey) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(indexKey) ?? <String>[];
    list.remove(baseKey);
    list.add(baseKey); // newest at end
    await p.setStringList(indexKey, list);
  }

  static Future<void> addMany(String indexKey, List<String> baseKeys) async {
    if (baseKeys.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(indexKey) ?? <String>[];
    for (final k in baseKeys) {
      list.remove(k);
      list.add(k);
    }
    await p.setStringList(indexKey, list);
  }

  static Future<void> remove(String indexKey, String baseKey) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(indexKey) ?? <String>[];
    list.remove(baseKey);
    await p.setStringList(indexKey, list);
  }

  static Future<void> removeMany(String indexKey, List<String> baseKeys) async {
    if (baseKeys.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(indexKey) ?? <String>[];
    list.removeWhere((k) => baseKeys.contains(k));
    await p.setStringList(indexKey, list);
  }

  static Future<void> moveByPrefix(
    String fromPrefix,
    String toPrefix,
    String baseKey,
  ) async {
    final fromKey = indexKeyForPrefix(fromPrefix);
    final toKey = indexKeyForPrefix(toPrefix);

    final p = await SharedPreferences.getInstance();
    final from = p.getStringList(fromKey) ?? <String>[];
    final to = p.getStringList(toKey) ?? <String>[];
    from.remove(baseKey);
    to.remove(baseKey);
    to.add(baseKey);
    await p.setStringList(fromKey, from);
    await p.setStringList(toKey, to);
  }
}
