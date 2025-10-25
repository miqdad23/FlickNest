import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TmdbSnap {
  final String baseKey; // e.g. movie_123
  final int id;
  final String mediaType; // movie | tv
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? date; // release_date / first_air_date
  final double? voteAverage;
  final List<String> genres; // names
  final int updatedAt; // epoch millis

  TmdbSnap({
    required this.baseKey,
    required this.id,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.date,
    this.voteAverage,
    this.genres = const [],
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'baseKey': baseKey,
    'id': id,
    'mediaType': mediaType,
    'title': title,
    'posterPath': posterPath,
    'backdropPath': backdropPath,
    'date': date,
    'voteAverage': voteAverage,
    'genres': genres,
    'updatedAt': updatedAt,
  };

  String toJson() => jsonEncode(toMap());

  factory TmdbSnap.fromMap(Map<String, dynamic> m) => TmdbSnap(
    baseKey: (m['baseKey'] ?? '').toString(),
    id: (m['id'] as num).toInt(),
    mediaType: (m['mediaType'] ?? 'movie').toString(),
    title: (m['title'] ?? '').toString(),
    posterPath: m['posterPath']?.toString(),
    backdropPath: m['backdropPath']?.toString(),
    date: m['date']?.toString(),
    voteAverage: (m['voteAverage'] == null)
        ? null
        : (m['voteAverage'] as num).toDouble(),
    genres: (m['genres'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    updatedAt: (m['updatedAt'] as num).toInt(),
  );

  factory TmdbSnap.fromJson(String s) =>
      TmdbSnap.fromMap(jsonDecode(s) as Map<String, dynamic>);
}

class SnapStore {
  static const String _idxKey = 'snap_index'; // StringList of baseKeys
  static String _keyFor(String baseKey) => 'snap_$baseKey';

  static String baseKeyFor(String mediaType, int id) => '${mediaType}_$id';

  static Future<void> save(TmdbSnap snap, {int maxKeep = 1000}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyFor(snap.baseKey), snap.toJson());
    final idx = p.getStringList(_idxKey) ?? <String>[];
    idx.remove(snap.baseKey);
    idx.add(snap.baseKey);
    // eviction: oldest first
    while (idx.length > maxKeep) {
      final victim = idx.removeAt(0);
      await p.remove(_keyFor(victim));
    }
    await p.setStringList(_idxKey, idx);
  }

  static Future<TmdbSnap?> loadOne(String baseKey) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyFor(baseKey));
    if (raw == null) return null;
    try {
      return TmdbSnap.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, TmdbSnap>> loadMany(List<String> baseKeys) async {
    final p = await SharedPreferences.getInstance();
    final out = <String, TmdbSnap>{};
    for (final bk in baseKeys) {
      final raw = p.getString(_keyFor(bk));
      if (raw == null) continue;
      try {
        out[bk] = TmdbSnap.fromJson(raw);
      } catch (_) {}
    }
    return out;
  }

  static TmdbSnap fromDetails(String mediaType, Map<String, dynamic> d) {
    final id = (d['id'] as num?)?.toInt() ?? 0;
    final title = (d['title'] ?? d['name'] ?? '').toString();
    final poster = d['poster_path']?.toString();
    final backdrop = d['backdrop_path']?.toString();
    final date = (d['release_date'] ?? d['first_air_date'])?.toString();
    final vote = (d['vote_average'] is num)
        ? (d['vote_average'] as num).toDouble()
        : null;
    final genres = ((d['genres'] as List?) ?? const [])
        .map((e) => (e as Map)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return TmdbSnap(
      baseKey: baseKeyFor(mediaType, id),
      id: id,
      mediaType: mediaType,
      title: title,
      posterPath: poster,
      backdropPath: backdrop,
      date: date,
      voteAverage: vote,
      genres: genres,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
