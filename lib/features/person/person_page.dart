import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/tmdb/tmdb_service.dart';
import '../details/details_page.dart';
import 'person_credits_page.dart';
import 'photo_viewer_page.dart';

class PersonPage extends StatefulWidget {
  final int personId;
  const PersonPage({super.key, required this.personId});

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  final api = TmdbService();
  late Future<Map<String, dynamic>> _future;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _future = api.personDetails(widget.personId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load person.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(
                      () => _future = api.personDetails(widget.personId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final d = snap.data!;
        final name = (d['name'] ?? '').toString();
        final profile = d['profile_path'] as String?;
        final department = (d['known_for_department'] ?? '').toString();
        final knownFor = _knownForText(d);
        final birthday = (d['birthday'] ?? '').toString();
        final place = (d['place_of_birth'] ?? '').toString();
        final bio = (d['biography'] ?? '').toString();

        final combined = (d['combined_credits'] ?? {}) as Map<String, dynamic>;
        final credits = _buildCreditItems(combined);
        final topCredits = credits.take(12).toList();
        final hasMoreCredits = credits.length > 8;

        final photos = ((d['images']?['profiles']) as List? ?? [])
            .map((e) => (e['file_path'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ),
              ),

              // Hero section — profile + info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _HeroInfo(
                    profilePath: profile,
                    name: name,
                    knownLine: knownFor.isNotEmpty ? knownFor : department,
                    birthday: birthday,
                    place: place,
                  ),
                ),
              ),

              // Biography
              if (bio.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Biography',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedCrossFade(
                          firstChild: Text(
                            bio,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondChild: Text(bio),
                          crossFadeState: _bioExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _bioExpanded = !_bioExpanded);
                          },
                          child: Text(_bioExpanded ? 'Read Less' : 'Read More'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Filmography (Known For)
              if (credits.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Known For',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (hasMoreCredits)
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PersonCreditsPage(
                                    personId: widget.personId,
                                    personName: name,
                                  ),
                                ),
                              );
                            },
                            child: const Text('See More >'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (credits.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: topCredits.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final c = topCredits[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => DetailsPage(
                                  mediaType: c.mediaType,
                                  id: c.id,
                                ),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                                transitionDuration: const Duration(
                                  milliseconds: 200,
                                ),
                              ),
                            );
                          },
                          child: SizedBox(
                            width: 128,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: c.poster == null
                                      ? Container(
                                          color: Colors.white10,
                                          height: 180,
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: TmdbService.imageW500(
                                            c.poster,
                                          ),
                                          height: 180,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _titleWithYear(c.title, c.year),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Photos
              if (photos.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (photos.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final path = photos[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PhotoViewerPage(
                                  filePaths: photos,
                                  initialIndex: i,
                                  title: name,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: TmdbService.imageW500(path),
                              width: 120,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  String _titleWithYear(String title, String? year) {
    if (year == null || year.isEmpty) return title;
    return '$title ($year)';
  }

  String _knownForText(Map<String, dynamic> d) {
    final dep = (d['known_for_department'] ?? '').toString();
    final known = <String>{};
    if (dep.isNotEmpty) known.add(_mapDept(dep));

    try {
      final crew = ((d['combined_credits']?['crew']) as List? ?? [])
          .map(
            (e) =>
                (e as Map)['job']?.toString() ??
                (e)['department']?.toString() ??
                '',
          )
          .where((s) => s.isNotEmpty)
          .take(10)
          .toList();
      for (final j in crew) {
        known.add(_mapJobOrDept(j));
        if (known.length >= 3) break;
      }
    } catch (_) {}
    return known.where((s) => s.isNotEmpty).join(', ');
  }

  String _mapDept(String s) {
    switch (s.toLowerCase()) {
      case 'acting':
        return 'Actor';
      case 'production':
        return 'Producer';
      case 'directing':
        return 'Director';
      case 'writing':
        return 'Writer';
      default:
        return s;
    }
  }

  String _mapJobOrDept(String s) {
    final low = s.toLowerCase();
    if (low.contains('director')) return 'Director';
    if (low.contains('producer')) return 'Producer';
    if (low.contains('writer')) return 'Writer';
    return s;
  }

  List<_CreditItem> _buildCreditItems(Map<String, dynamic> combined) {
    final cast = (combined['cast'] as List? ?? []);
    final crew = (combined['crew'] as List? ?? []);

    final all = <Map<String, dynamic>>[];
    all.addAll(cast.cast<Map<String, dynamic>>());
    all.addAll(crew.cast<Map<String, dynamic>>());

    final byKey = <String, Map<String, dynamic>>{};
    for (final j in all) {
      final mt =
          (j['media_type'] as String?) ??
          ((j['name'] != null && j['title'] == null) ? 'tv' : 'movie');
      final id = j['id'] as int?;
      if (id == null) continue;
      final key = '$mt-$id';
      if (!byKey.containsKey(key) || cast.contains(j)) {
        byKey[key] = j;
      }
    }

    final items = <_CreditItem>[];
    for (final j in byKey.values) {
      final mt =
          (j['media_type'] as String?) ??
          ((j['name'] != null && j['title'] == null) ? 'tv' : 'movie');
      final id = j['id'] as int?;
      if (id == null) continue;
      final title = (j['title'] ?? j['name'] ?? '').toString();
      final poster = j['poster_path'] as String?;
      final date = (j['release_date'] ?? j['first_air_date'] ?? '').toString();
      final year = date.isNotEmpty ? date.split('-').first : null;
      final pop = (j['popularity'] as num?)?.toDouble() ?? 0.0;
      items.add(
        _CreditItem(
          id: id,
          mediaType: mt,
          title: title,
          poster: poster,
          year: year,
          popularity: pop,
        ),
      );
    }

    items.sort((a, b) => b.popularity.compareTo(a.popularity));
    return items;
  }
}

class _HeroInfo extends StatelessWidget {
  final String? profilePath;
  final String name;
  final String knownLine;
  final String birthday;
  final String place;

  const _HeroInfo({
    required this.profilePath,
    required this.name,
    required this.knownLine,
    required this.birthday,
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = birthday.isNotEmpty
        ? 'Born on ${_formatDate(birthday)}'
        : '';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 20, end: 0),
      duration: const Duration(milliseconds: 260),
      builder: (_, v, child) => Opacity(
        opacity: 1.0 - (v / 20),
        child: Transform.translate(offset: Offset(0, v), child: child),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: profilePath == null
                ? Container(color: Colors.white10, width: 120, height: 120)
                : CachedNetworkImage(
                    imageUrl: TmdbService.imageW500(profilePath),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if (knownLine.isNotEmpty)
                  Text(
                    knownLine,
                    style: const TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 6),
                if (dateText.isNotEmpty)
                  Text(dateText, style: const TextStyle(color: Colors.white70)),
                if (place.isNotEmpty)
                  Text(place, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final p = iso.split('-');
      if (p.length < 3) return iso;
      final y = int.parse(p[0]), m = int.parse(p[1]), d = int.parse(p[2]);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final mm = (m >= 1 && m <= 12) ? months[m - 1] : p[1];
      return '$mm $d, $y';
    } catch (_) {
      return iso;
    }
  }
}

class _CreditItem {
  final int id;
  final String mediaType; // movie | tv
  final String title;
  final String? poster;
  final String? year;
  final double popularity;
  _CreditItem({
    required this.id,
    required this.mediaType,
    required this.title,
    this.poster,
    this.year,
    this.popularity = 0,
  });
}
