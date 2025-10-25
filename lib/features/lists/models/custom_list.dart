// lib/features/lists/models/custom_list.dart (Offline-only)
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomList {
  final String id; // cl_<timestamp>
  String name;
  final String type; // both | movie | tv (immutable)
  String? description;
  final int createdAt;
  int updatedAt;
  int color; // ARGB int (e.g. 0xFF3B82F6)
  int icon;  // Material icon codePoint
  List<String> itemKeys; // ['movie_123', 'tv_456']

  CustomList({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.color,
    required this.icon,
    required this.itemKeys,
  });

  factory CustomList.newList({
    required String name,
    required String type, // both/movie/tv
    String? description,
    required int color,
    required int icon,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return CustomList(
      id: 'cl_$now',
      name: name,
      type: type,
      description: description,
      createdAt: now,
      updatedAt: now,
      color: color,
      icon: icon,
      itemKeys: <String>[],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'description': description,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'color': color,
        'icon': icon,
        'itemKeys': itemKeys,
      };

  factory CustomList.fromMap(Map<String, dynamic> m) => CustomList(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        type: (m['type'] ?? 'both').toString(),
        description: (m['description'])?.toString(),
        createdAt: (m['createdAt'] as num).toInt(),
        updatedAt: (m['updatedAt'] as num).toInt(),
        color: (m['color'] is int) ? (m['color'] as int) : 0xFF3B82F6,
        icon: (m['icon'] is int) ? (m['icon'] as int) : 0xE2C7, // Icons.folder_rounded
        itemKeys: (m['itemKeys'] as List? ?? const []).cast<String>().toList(),
      );

  String toJson() => jsonEncode(toMap());
  factory CustomList.fromJson(String s) =>
      CustomList.fromMap(jsonDecode(s) as Map<String, dynamic>);
}

class CustomListStore {
  static const String idxKey = 'cl_index'; // StringList of list IDs
  static String listKey(String id) => 'cl_$id';

  // Load all lists (local only)
  static Future<List<CustomList>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final ids = p.getStringList(idxKey) ?? <String>[];
    final out = <CustomList>[];
    for (final id in ids) {
      final raw = p.getString(listKey(id));
      if (raw != null) {
        try {
          out.add(CustomList.fromJson(raw));
        } catch (_) {}
      }
    }
    // sort: updatedAt desc, name asc
    out.sort((a, b) {
      if (a.updatedAt != b.updatedAt) return b.updatedAt.compareTo(a.updatedAt);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  static Future<void> save(CustomList list) async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    list.updatedAt = now;

    final ids = p.getStringList(idxKey) ?? <String>[];
    if (!ids.contains(list.id)) {
      ids.add(list.id);
      await p.setStringList(idxKey, ids);
    }
    await p.setString(listKey(list.id), list.toJson());
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final ids = p.getStringList(idxKey) ?? <String>[];
    ids.remove(id);
    await p.setStringList(idxKey, ids);
    await p.remove(listKey(id));
  }

  static Future<void> rename(String id, String newName, String? newDesc,
      [int? newColor, int? newIcon]) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(listKey(id));
    if (raw == null) return;
    final list = CustomList.fromJson(raw);
    list.name = newName;
    list.description = newDesc;
    if (newColor != null) list.color = newColor;
    if (newIcon != null) list.icon = newIcon;
    await save(list);
  }

  static Future<int> countItems(String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(listKey(id));
    if (raw == null) return 0;
    final list = CustomList.fromJson(raw);
    return list.itemKeys.length;
  }

  static Future<void> addItem(String listId, String baseKey) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(listKey(listId));
    if (raw == null) return;
    final list = CustomList.fromJson(raw);
    if (!list.itemKeys.contains(baseKey)) list.itemKeys.add(baseKey);
    await save(list);
  }

  static Future<void> addItems(String listId, List<String> baseKeys) async {
    if (baseKeys.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(listKey(listId));
    if (raw == null) return;
    final list = CustomList.fromJson(raw);
    for (final k in baseKeys) {
      if (!list.itemKeys.contains(k)) list.itemKeys.add(k);
    }
    await save(list);
  }

  static Future<void> removeItem(String listId, String baseKey) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(listKey(listId));
    if (raw == null) return;
    final list = CustomList.fromJson(raw);
    list.itemKeys.remove(baseKey);
    await save(list);
  }

  static Future<void> removeItems(String listId, List<String> baseKeys) async {
    if (baseKeys.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(listKey(listId));
    if (raw == null) return;
    final list = CustomList.fromJson(raw);
    list.itemKeys.removeWhere((k) => baseKeys.contains(k));
    await save(list);
  }
}