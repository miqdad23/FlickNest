// lib/features/person/person_credits_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/assets/assets.dart';
import '../../core/tmdb/tmdb_service.dart';
import '../../core/tmdb/tmdb_models.dart';
import '../details/details_page.dart';

class PersonCreditsPage extends StatefulWidget {
  final int personId;
  final String personName;
  const PersonCreditsPage({
    super.key,
    required this.personId,
    required this.personName,
  });

  @override
  State<PersonCreditsPage> createState() => _PersonCreditsPageState();
}

class _PersonCreditsPageState extends State<PersonCreditsPage> {
  final api = TmdbService();
  bool _loading = true;
  String? _error;
  List<TmdbMovie> _all = [];
  String _type = 'all'; // all|movie|tv

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _all.clear();
    });
    try {
      final d = await api.personDetails(widget.personId);
      final cc = (d['combined_credits'] ?? {}) as Map<String, dynamic>;
      _all = _mapCredits(cc);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TmdbMovie> _mapCredits(Map<String, dynamic> cc) {
    final list = <Map<String, dynamic>>[];
    list.addAll(((cc['cast']) as List? ?? []).cast<Map<String, dynamic>>());
    list.addAll(((cc['crew']) as List? ?? []).cast<Map<String, dynamic>>());
    final castList = ((cc['cast']) as List? ?? []);

    // Dedup by (mediaType-id), prefer cast over crew
    final byKey = <String, Map<String, dynamic>>{};
    for (final j in list) {
      final mt =
          (j['media_type'] as String?) ??
          ((j['name'] != null && j['title'] == null) ? 'tv' : 'movie');
      final id = j['id'] as int?;
      if (id == null) continue;
      final key = '$mt-$id';
      if (!byKey.containsKey(key) || castList.contains(j)) {
        byKey[key] = j;
      }
    }

    final items = byKey.values.map((j) {
      final mt =
          (j['media_type'] as String?) ??
          ((j['name'] != null && j['title'] == null) ? 'tv' : 'movie');
      return TmdbMovie.fromJson(j, forcedMediaType: mt);
    }).toList();

    // Sort by year desc
    items.sort((a, b) {
      final ya = (a.releaseDate ?? '').split('-').first;
      final yb = (b.releaseDate ?? '').split('-').first;
      final yaI = int.tryParse(ya) ?? -1;
      final ybI = int.tryParse(yb) ?? -1;
      return ybI.compareTo(yaI);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const _GridSkeleton();
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else {
      final items = _type == 'all'
          ? _all
          : _all.where((m) => m.mediaType == _type).toList();

      body = GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2 / 3,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final m = items[i];
          final url = TmdbService.imageW500(m.posterPath ?? m.backdropPath);
          final year = (m.releaseDate ?? '').split('-').first;
          final title = year.isEmpty ? m.title : '${m.title} ($year)';

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailsPage(mediaType: m.mediaType, id: m.id),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: url.isEmpty
                        ? Image.asset(
                            AppAssets.posterPlaceholder,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Image.asset(
                              AppAssets.posterPlaceholder,
                              fit: BoxFit.cover,
                            ),
                            errorWidget: (_, __, ___) => Image.asset(
                              AppAssets.posterPlaceholder,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _type = v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'movie', child: Text('Movies')),
              PopupMenuItem(value: 'tv', child: Text('TV Shows')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2 / 3,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(color: Colors.white10),
      ),
    );
  }
}
