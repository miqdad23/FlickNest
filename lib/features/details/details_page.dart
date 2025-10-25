// lib/features/details/details_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tmdb/tmdb_service.dart';
import '../person/person_page.dart';
import '../home/section_listing_page.dart';
import '../search/genre_discover_page.dart';
import '../lists/models/snap_store.dart';
import '../lists/models/custom_list.dart';
import '../lists/models/default_index.dart';
import '../../app/navigation/route_observer.dart';
import '../../ui/glass_sheet.dart';

class DetailsPage extends StatefulWidget {
  final String mediaType; // 'movie' | 'tv'
  final int id;
  const DetailsPage({super.key, required this.mediaType, required this.id});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> with RouteAware {
  final api = TmdbService();
  late Future<Map<String, dynamic>> _future;

  // local states
  bool fav = false, watchlist = false, watched = false;
  double myRating = 0.0;
  final _commentCtrl = TextEditingController();
  bool _storyExpanded = false;

  // trailer key (external open only)
  String _ytVideoId = '';

  // TV seasons/episodes
  List<Map<String, dynamic>> _seasons = [];
  int? _selectedSeason;
  List<Map<String, dynamic>> _episodes = [];
  bool _loadingSeason = false;

  // recommendations (infinite)
  final _recCtrl = ScrollController();
  final List<Map<String, dynamic>> _recs = [];
  bool _loadingRecs = false;
  int _recPage = 1;

  // one-time init gate per content
  String _initKey = '';

  // baseKey helper for lists
  String get _baseKey => SnapStore.baseKeyFor(widget.mediaType, widget.id);

  // capture root handles once
  NavigatorState? _rootNav;
  ScaffoldMessengerState? _rootMsg;

  @override
  void initState() {
    super.initState();
    _future = _fetchDetails();
    _recCtrl.addListener(_onRecScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
    _rootNav ??= Navigator.of(context);
    _rootMsg ??= ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _recCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchDetails() => widget.mediaType == 'tv'
      ? api.tvDetails(widget.id)
      : api.movieDetails(widget.id);

  // ------------- helpers -------------
  Color _glassTint(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color.fromRGBO(255, 255, 255, 0.06)
      : const Color.fromRGBO(0, 0, 0, 0.06);

  BoxDecoration _glassBox(BuildContext c, {double r = 12}) => BoxDecoration(
        color: _glassTint(c),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: Theme.of(c).brightness == Brightness.dark
              ? const Color.fromRGBO(255, 255, 255, 0.12)
              : const Color.fromRGBO(0, 0, 0, 0.12),
        ),
      );

  Widget _chip(BuildContext c, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _glassBox(c, r: 24),
        child: Text(t),
      );

  Widget _tapChip(BuildContext c, String t, VoidCallback onTap) => InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: _chip(c, t),
      );

  Widget _genreChip(BuildContext c, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(c).brightness == Brightness.dark
                ? Colors.white24
                : Colors.black26,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(t),
      );

  Widget _genreTapChip(BuildContext c, String t, VoidCallback onTap) => InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: _genreChip(c, t),
      );

  Widget _actionBtn({
    required IconData iconOff,
    required IconData iconOn,
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 46,
          decoration: _glassBox(context, r: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  active ? iconOn : iconOff,
                  key: ValueKey(active),
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // prefs
  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    fav = p.getBool('fav_$_baseKey') ?? false;
    watchlist = p.getBool('watchlist_$_baseKey') ?? false;
    watched = p.getBool('watched_$_baseKey') ?? false;
    myRating = p.getDouble('rating_$_baseKey') ?? 0.0;
    _commentCtrl.text = p.getString('comment_$_baseKey') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _saveFlag(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('${k}_$_baseKey', v);
  }

  Future<void> _saveRating(double v) async {
    myRating = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('rating_$_baseKey', v);
    if (mounted) setState(() {});
  }

  Future<void> _saveComment() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('comment_$_baseKey', _commentCtrl.text.trim());
  }

  void _toast(String msg) => _rootMsg?.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
      );

  // recs infinite
  void _onRecScroll() {
    if (_loadingRecs) return;
    if (_recCtrl.position.extentAfter < 300) _loadMoreRecs();
  }

  Future<void> _loadMoreRecs() async {
    _loadingRecs = true;
    try {
      _recPage += 1;
      final more = await api.recommendations(
        widget.mediaType,
        widget.id,
        page: _recPage,
      );
      if (more.isNotEmpty) {
        _recs.addAll(
          more.map(
            (m) => {'id': m.id, 'title': m.title, 'poster_path': m.posterPath},
          ),
        );
        if (mounted) setState(() {});
      }
    } catch (_) {
    } finally {
      _loadingRecs = false;
    }
  }

  // tv seasons
  Future<void> _loadSeason(int seasonNo) async {
    setState(() {
      _loadingSeason = true;
      _episodes = [];
      _selectedSeason = seasonNo;
    });
    try {
      final s = await api.seasonDetails(widget.id, seasonNo);
      final eps = (s['episodes'] as List? ?? [])
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _episodes = eps;
    } catch (_) {
      _episodes = [];
    } finally {
      if (mounted) setState(() => _loadingSeason = false);
    }
  }

  // ---------- open listing helpers ----------
  void _openYearListing(String year) {
    final title = widget.mediaType == 'movie'
        ? 'Released in $year'
        : 'Aired in $year';
    _rootNav?.push(
      MaterialPageRoute(
        builder: (_) => SectionListingPage(
          title: title,
          fetch: (page) => widget.mediaType == 'movie'
              ? api.discoverMovies({'primary_release_year': year}, page: page)
              : api.discoverTv({'first_air_date_year': year}, page: page),
        ),
      ),
    );
  }

  void _openGenreListing(int id, String name) {
    _rootNav?.push(
      MaterialPageRoute(
        builder: (_) => GenreDiscoverPage(
          api: api,
          genreId: id,
          genreName: name,
          mediaType: widget.mediaType,
        ),
      ),
    );
  }

  void _openTopRated() {
    final title = widget.mediaType == 'movie'
        ? 'Top Rated Movies'
        : 'Top Rated TV';
    _rootNav?.push(
      MaterialPageRoute(
        builder: (_) => SectionListingPage(
          title: title,
          fetch: (page) => widget.mediaType == 'movie'
              ? api.topRatedMovies(page: page)
              : api.topRatedTv(page: page),
        ),
      ),
    );
  }

  void _openCertificationListing(String cert) {
    if (widget.mediaType != 'movie') {
      _toast('Certification filtering not supported for TV.');
      return;
    }
    final title = 'Certified $cert (US)';
    _rootNav?.push(
      MaterialPageRoute(
        builder: (_) => SectionListingPage(
          title: title,
          fetch: (page) => api.discoverMovies({
            'certification_country': 'US',
            'certification': cert,
          }, page: page),
        ),
      ),
    );
  }

  // ---------- Index helpers for default lists ----------
  Future<void> _indexUpdateFavorite(bool active) async {
    if (active) {
      await DefaultIndexStore.add(DefaultIndexStore.favIndex, _baseKey);
    } else {
      await DefaultIndexStore.remove(DefaultIndexStore.favIndex, _baseKey);
    }
  }

  Future<void> _indexUpdateWatchlist(bool active) async {
    if (active) {
      await DefaultIndexStore.add(DefaultIndexStore.watchlistIndex, _baseKey);
      await DefaultIndexStore.remove(DefaultIndexStore.watchedIndex, _baseKey);
    } else {
      await DefaultIndexStore.remove(
        DefaultIndexStore.watchlistIndex,
        _baseKey,
      );
    }
  }

  Future<void> _indexUpdateWatched(bool active) async {
    if (active) {
      await DefaultIndexStore.add(DefaultIndexStore.watchedIndex, _baseKey);
      await DefaultIndexStore.remove(
        DefaultIndexStore.watchlistIndex,
        _baseKey,
      );
    } else {
      await DefaultIndexStore.remove(DefaultIndexStore.watchedIndex, _baseKey);
    }
  }

  // ---------- Manage Lists Bottom Sheet (Glass) ----------
  Future<void> _openManageListsSheet() async {
    HapticFeedback.lightImpact();

    final allLists = await CustomListStore.loadAll();
    if (!mounted) return;

    final allowedLists =
        allLists
            .where((l) => l.type == 'both' || l.type == widget.mediaType)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final initiallySelected = allowedLists
        .where((l) => l.itemKeys.contains(_baseKey))
        .map((l) => l.id)
        .toSet();

    bool tmpFav = fav;
    bool tmpWatchlist = watchlist;
    bool tmpWatched = watched;
    final tmpCustom = Set<String>.from(initiallySelected);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.strong3D(cs);
        final sheetNav = Navigator.of(ctx);

        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx2, setSB) {
              void toggleDefault(String which) {
                setSB(() {
                  if (which == 'fav') tmpFav = !tmpFav;
                  if (which == 'watchlist') {
                    tmpWatchlist = !tmpWatchlist;
                    if (tmpWatchlist) tmpWatched = false;
                  }
                  if (which == 'watched') {
                    tmpWatched = !tmpWatched;
                    if (tmpWatched) tmpWatchlist = false;
                  }
                });
              }

              final List<Widget> customListWidgets = allowedLists.isEmpty
                  ? const [Text('No custom lists yet.')]
                  : allowedLists
                      .map(
                        (l) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.name),
                          subtitle: (l.description == null)
                              ? null
                              : Text(l.description!),
                          value: tmpCustom.contains(l.id),
                          onChanged: (v) {
                            setSB(() {
                              if (v == true) {
                                tmpCustom.add(l.id);
                              } else {
                                tmpCustom.remove(l.id);
                              }
                            });
                          },
                        ),
                      )
                      .toList();

              final bottomInset = MediaQuery.of(ctx2).viewInsets.bottom;

              return GlassSheet(
                style: style,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Manage Lists',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              selected: tmpFav,
                              label: const Text('Favorite'),
                              onSelected: (_) => toggleDefault('fav'),
                            ),
                            FilterChip(
                              selected: tmpWatchlist,
                              label: const Text('Watchlist'),
                              onSelected: (_) => toggleDefault('watchlist'),
                            ),
                            FilterChip(
                              selected: tmpWatched,
                              label: const Text('Watched'),
                              onSelected: (_) => toggleDefault('watched'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your Lists',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...customListWidgets,
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => sheetNav.pop(),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.lightImpact();

                                if (tmpFav != fav) {
                                  fav = tmpFav;
                                  await _saveFlag('fav', fav);
                                  await _indexUpdateFavorite(fav);
                                }
                                if (tmpWatchlist != watchlist ||
                                    tmpWatched != watched) {
                                  watchlist = tmpWatchlist;
                                  watched = tmpWatched;
                                  await _saveFlag('watchlist', watchlist);
                                  await _saveFlag('watched', watched);
                                  await _indexUpdateWatchlist(watchlist);
                                  await _indexUpdateWatched(watched);
                                }

                                final before = initiallySelected;
                                final addIds = tmpCustom.difference(before);
                                final removeIds = before.difference(tmpCustom);

                                if (addIds.isNotEmpty || removeIds.isNotEmpty) {
                                  final lists = await CustomListStore.loadAll();
                                  final byId = {for (final l in lists) l.id: l};

                                  for (final id in addIds) {
                                    final l = byId[id];
                                    if (l == null) continue;
                                    if (!l.itemKeys.contains(_baseKey)) {
                                      l.itemKeys.add(_baseKey);
                                      await CustomListStore.save(l);
                                    }
                                  }
                                  for (final id in removeIds) {
                                    final l = byId[id];
                                    if (l == null) continue;
                                    l.itemKeys.removeWhere(
                                      (k) => k == _baseKey,
                                    );
                                    await CustomListStore.save(l);
                                  }
                                }

                                if (!mounted) return;
                                if (!sheetNav.mounted) return;
                                sheetNav.pop();
                                _rootMsg?.showSnackBar(
                                  const SnackBar(
                                    content: Text('Lists updated'),
                                    duration: Duration(milliseconds: 900),
                                  ),
                                );
                                if (mounted) setState(() {});
                              },
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = MediaQuery.of(context).padding.top;
    const double expanded = 300;

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
                  const Text('Failed to load details.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => _future = _fetchDetails()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final d = snap.data!;
        final mt = widget.mediaType;
        final id = widget.id;

        final gate = '$mt:$id';
        if (_initKey != gate) {
          _initKey = gate;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _initAfterFetch(d),
          );
        }

        final title = (d['title'] ?? d['name'] ?? '').toString();
        final backdrop = d['backdrop_path'] as String?;
        final poster = d['poster_path'] as String?;
        final overview = (d['overview'] ?? '').toString();

        final vote = ((d['vote_average'] ?? 0) as num).toStringAsFixed(1);
        final year =
            (d['release_date'] ?? d['first_air_date'] ?? '')
                    .toString()
                    .split('-')
                    .firstOrNull ??
                '';
        final runtimeMin = _runtimeText(d, mt);
        final cert = _certification(d, mt, region: 'US');

        final genresRaw = (d['genres'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final castList =
            (d[(mt == 'tv') ? 'aggregate_credits' : 'credits']?['cast']
                        as List? ??
                    [])
                .take(20)
                .toList();

        return Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Hero with parallax + glass toolbar + safe title padding
              SliverAppBar(
                pinned: true,
                expandedHeight: expanded,
                backgroundColor: Colors.transparent,
                flexibleSpace: LayoutBuilder(
                  builder: (context, cons) {
                    final current = cons.biggest.height;
                    final toolbar = kToolbarHeight + status;
                    final t = ((expanded - current) / (expanded - toolbar))
                        .clamp(0.0, 1.0); // 0 → expanded, 1 → collapsed
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // backdrop
                        if (backdrop != null)
                          CachedNetworkImage(
                            imageUrl: TmdbService.imageOriginal(backdrop),
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 250),
                          )
                        else
                          Container(color: Colors.black12),
                        // gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        // Glass toolbar when collapsed
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 16 * t,
                                sigmaY: 16 * t,
                              ),
                              child: Container(
                                height: status + kToolbarHeight,
                                decoration: BoxDecoration(
                                  color:
                                      (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black)
                                          .withValues(alpha: 0.06 * t),
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.12 * t),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Expanded (overlay) title
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Opacity(
                            opacity: (1 - t),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Collapsed title
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 72, // space for back button
                              right: 16,
                              bottom: 12,
                            ),
                            child: Opacity(
                              opacity: t, // visible when collapsed
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Poster + meta chips + genres
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.35),
                              blurRadius: 14,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: poster == null
                              ? Container(color: Colors.white10, width: 110, height: 165)
                              : CachedNetworkImage(
                                  imageUrl: TmdbService.imageW500(poster),
                                  width: 110,
                                  height: 165,
                                  fit: BoxFit.cover,
                                  fadeInDuration:
                                      const Duration(milliseconds: 220),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (year.isNotEmpty)
                                  _tapChip(
                                    context,
                                    year,
                                    () => _openYearListing(year),
                                  ),
                                if (cert.isNotEmpty)
                                  _tapChip(
                                    context,
                                    cert,
                                    () => _openCertificationListing(cert),
                                  ),
                                if (runtimeMin.isNotEmpty)
                                  _chip(context, runtimeMin),
                                _tapChip(context, 'TMDB $vote', _openTopRated),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: genresRaw.map((g) {
                                final gid = g['id'] as int?;
                                final gname = (g['name'] ?? '').toString();
                                if (gid == null || gname.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return _genreTapChip(
                                  context,
                                  gname,
                                  () => _openGenreListing(gid, gname),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _actionBtn(
                        iconOff: Icons.favorite_border,
                        iconOn: Icons.favorite,
                        active: fav,
                        label: 'Favorite',
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          setState(() => fav = !fav);
                          await _saveFlag('fav', fav);
                          await _indexUpdateFavorite(fav);
                          _toast(fav ? 'Added to Favorites' : 'Removed');
                        },
                      ),
                      const SizedBox(width: 12),
                      _actionBtn(
                        iconOff: Icons.bookmark_border,
                        iconOn: Icons.bookmark,
                        active: watchlist,
                        label: 'Watchlist',
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final next = !watchlist;
                          setState(() {
                            watchlist = next;
                            if (next && watched) watched = false;
                          });
                          await _saveFlag('watchlist', watchlist);
                          await _saveFlag('watched', watched);
                          await _indexUpdateWatchlist(watchlist);
                          if (!watchlist) await _indexUpdateWatched(watched);
                          _toast(watchlist ? 'Added to Watchlist' : 'Removed');
                        },
                      ),
                      const SizedBox(width: 12),
                      _actionBtn(
                        iconOff: Icons.check_circle_outline,
                        iconOn: Icons.check_circle,
                        active: watched,
                        label: 'Watched',
                        onTap: () async {
                          // upcoming block
                          bool upcoming = false;
                          final iso =
                              (d['release_date'] ?? d['first_air_date'] ?? '')
                                  .toString();
                          if (iso.isNotEmpty) {
                            try {
                              final rel = DateTime.parse(iso);
                              final today = DateTime.now();
                              final relD = DateTime(rel.year, rel.month, rel.day);
                              final todayD =
                                  DateTime(today.year, today.month, today.day);
                              upcoming = relD.isAfter(todayD);
                            } catch (_) {}
                          }
                          if (upcoming) {
                            HapticFeedback.heavyImpact();
                            _toast("Can't mark as watched before release.");
                            return;
                          }

                          HapticFeedback.lightImpact();
                          final next = !watched;
                          setState(() {
                            watched = next;
                            if (next && watchlist) watchlist = false;
                          });
                          await _saveFlag('watched', watched);
                          await _saveFlag('watchlist', watchlist);
                          await _indexUpdateWatched(watched);
                          if (!watched) await _indexUpdateWatchlist(watchlist);
                          _toast(watched ? 'Marked as Watched' : 'Unmarked');
                        },
                      ),
                      const SizedBox(width: 12),
                      _actionBtn(
                        iconOff: Icons.playlist_add,
                        iconOn: Icons.playlist_add_check,
                        active: false,
                        label: 'Add to List',
                        onTap: _openManageListsSheet,
                      ),
                    ],
                  ),
                ),
              ),

              // NEW: External buttons row (YouTube + Google)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            final k = _ytVideoId;
                            if (k.isNotEmpty) {
                              _openTrailerExternally(k);
                            } else {
                              _openYoutubeSearch(title, year);
                            }
                          },
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text('Watch trailer'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openGoogleSearch(title, year),
                          icon: const Icon(Icons.search),
                          label: const Text('Google search'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Storyline
              if (overview.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Storyline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedCrossFade(
                          firstChild: Text(
                            overview,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondChild: Text(overview),
                          crossFadeState: _storyExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _storyExpanded = !_storyExpanded),
                          child: Text(
                            _storyExpanded ? 'Read Less' : 'Read More',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Gallery
              if (_imagesFrom(d).isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: _AutoSlideGallery(paths: _imagesFrom(d)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Part of this collection (movie only)
              if (widget.mediaType == 'movie')
                SliverToBoxAdapter(
                  child: _CollectionSection(id: id, api: api),
                ),

              // Cast & Crew
              if (castList.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cast & Crew',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 130,
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            itemCount: castList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final c = castList[i] as Map<String, dynamic>;
                              final name = (c['name'] ?? '').toString();
                              final role =
                                  (c['character'] ??
                                          (c['roles'] as List?)
                                              ?.firstWhereOrNull(
                                                (e) => true,
                                              )?['character'] ??
                                          '')
                                      .toString();
                              final photoPath = c['profile_path'] as String?;
                              final pid = c['id'] as int?;
                              return GestureDetector(
                                onTap: () {
                                  if (pid == null) return;
                                  HapticFeedback.lightImpact();
                                  _rootNav?.push(
                                    MaterialPageRoute(
                                      builder: (_) => PersonPage(personId: pid),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 90,
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 34,
                                        backgroundImage: photoPath == null
                                            ? null
                                            : NetworkImage(
                                                TmdbService.imageW500(
                                                  photoPath,
                                                ),
                                              ),
                                        backgroundColor: Colors.white10,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        role,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Seasons & Episodes (TV only)
              if (widget.mediaType == 'tv' && _seasons.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seasons & Episodes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Season:'),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _selectedSeason,
                              items: _seasons
                                  .map(
                                    (s) => DropdownMenuItem<int>(
                                      value: s['season_number'] as int,
                                      child: Text('S${s['season_number']}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                _loadSeason(v);
                              },
                            ),
                            const Spacer(),
                            Text(
                              _loadingSeason
                                  ? 'Loading...'
                                  : 'Contains ${_episodes.length} episode${_episodes.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _loadingSeason
                              ? const LinearProgressIndicator(minHeight: 2)
                              : Column(
                                  key: ValueKey(_selectedSeason),
                                  children: List.generate(_episodes.length, (i) {
                                    final e = _episodes[i];
                                    final epNo =
                                        e['episode_number']?.toString() ?? '';
                                    final epName = (e['name'] ?? '').toString();
                                    final epOverview =
                                        (e['overview'] ?? '').toString();
                                    final still = e['still_path'] as String?;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: SizedBox(
                                              width: 120,
                                              height: 68,
                                              child: still == null
                                                  ? Container(
                                                      color: Colors.white10,
                                                    )
                                                  : CachedNetworkImage(
                                                      imageUrl:
                                                          TmdbService.imageW500(
                                                        still,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'E$epNo • $epName',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  epOverview,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Your Experience
              if (watched)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Experience',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StarRating(
                          value: myRating,
                          onChanged: (v) async {
                            await _saveRating(v);
                            _toast('Rating saved: ${v.toStringAsFixed(1)}');
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Write your thoughts...',
                            filled: true,
                            fillColor: _glassTint(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _saveComment(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _saveComment,
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // More Like This (infinite)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'More Like This',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 240,
                        child: ListView.separated(
                          controller: _recCtrl,
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          itemCount: _recs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final r = _recs[i];
                            final rid = r['id'] as int;
                            final rtitle = (r['title'] ?? '').toString();
                            final rposter = r['poster_path'] as String?;
                            return GestureDetector(
                              onTap: () => _rootNav?.pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailsPage(mediaType: mt, id: rid),
                                ),
                              ),
                              child: SizedBox(
                                width: 128,
                                height: 240,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: rposter == null
                                          ? Container(
                                              color: Colors.white10,
                                              height: 190,
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: TmdbService.imageW500(
                                                rposter,
                                              ),
                                              height: 190,
                                              fit: BoxFit.cover,
                                              fadeInDuration: const Duration(
                                                milliseconds: 220),
                                            ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 40,
                                      child: Text(
                                        rtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loadingRecs)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _initAfterFetch(Map<String, dynamic> d) {
    _loadPrefs();

    // Save/refresh offline snapshot
    try {
      final snap = SnapStore.fromDetails(widget.mediaType, d);
      SnapStore.save(snap);
    } catch (_) {}

    // Pick trailer (YouTube) — for external open only
    final List<Map<String, dynamic>> all =
        ((d['videos']?['results']) as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => (m['site']?.toString() ?? '') == 'YouTube')
            .toList();

    final Map<String, dynamic>? trailer =
        all.firstWhereOrNull(
          (v) =>
              (v['official'] == true) &&
              ((v['type']?.toString().toLowerCase() ?? '') == 'trailer'),
        ) ??
        all.firstWhereOrNull(
          (v) => (v['type']?.toString().toLowerCase() ?? '') == 'trailer',
        ) ??
        all.firstWhereOrNull(
          (v) =>
              (v['official'] == true) &&
              ((v['type']?.toString().toLowerCase() ?? '') == 'teaser' ||
                  (v['type']?.toString().toLowerCase() ?? '') == 'clip'),
        ) ??
        all.firstWhereOrNull(
          (v) =>
              (v['type']?.toString().toLowerCase() ?? '') == 'teaser' ||
              (v['type']?.toString().toLowerCase() ?? '') == 'clip',
        ) ??
        (all.isNotEmpty ? all.first : null);

    _ytVideoId = trailer?['key']?.toString() ?? '';
    if (mounted) setState(() {});

    // tv seasons
    if (widget.mediaType == 'tv') {
      final seasons = (d['seasons'] as List? ?? [])
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _seasons = seasons.where((s) => (s['season_number'] ?? 0) > 0).toList();
      if (_seasons.isNotEmpty) {
        _selectedSeason = _seasons
            .map((s) => s['season_number'] as int)
            .reduce((a, b) => a > b ? a : b);
        _loadSeason(_selectedSeason!);
      }
    }

    // recs start
    final appendRecs = ((d['recommendations']?['results']) as List? ?? [])
        .cast<Map>();
    _recs
      ..clear()
      ..addAll(
        appendRecs.map(
          (r) => {
            'id': r['id'],
            'title': (r['title'] ?? r['name'] ?? '').toString(),
            'poster_path': r['poster_path'],
          },
        ),
      );
    _recPage = 1;
    _loadingRecs = false;
    if (mounted) setState(() {});
  }

  // external open
  Future<void> _openTrailerExternally(String key) async {
    try {
      final app = Uri.parse('vnd.youtube:$key');
      final web = Uri.parse('https://www.youtube.com/watch?v=$key');
      if (await canLaunchUrl(app)) {
        await launchUrl(app);
      } else {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _openYoutubeSearch(String title, String year) async {
    final q = '$title ${year.isNotEmpty ? '($year)' : ''} trailer';
    final url = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openGoogleSearch(String title, String year) async {
    final q = '$title ${year.isNotEmpty ? '($year)' : ''} movie';
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(q)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // helpers
  List<String> _imagesFrom(Map<String, dynamic> d) {
    final backdrops = ((d['images']?['backdrops']) as List? ?? [])
        .map((e) => e['file_path'] as String?)
        .whereType<String>()
        .toList();
    final posters = ((d['images']?['posters']) as List? ?? [])
        .map((e) => e['file_path'] as String?)
        .whereType<String>()
        .toList();
    return backdrops.isNotEmpty ? backdrops : posters;
  }

  String _runtimeText(Map<String, dynamic> d, String mt) {
    if (mt == 'movie') {
      final m = d['runtime'] as int?;
      if (m == null || m == 0) return '';
      final h = m ~/ 60, r = m % 60;
      return '${h}h ${r}m';
    } else {
      final ep = (d['episode_run_time'] as List?)?.firstOrNull as int?;
      if (ep == null || ep == 0) return '';
      return '${ep}m/ep';
    }
  }

  String _certification(
    Map<String, dynamic> d,
    String mt, {
    String region = 'US',
  }) {
    try {
      if (mt == 'movie') {
        final arr = (d['release_dates']?['results'] as List? ?? []);
        final x = arr.firstWhereOrNull((e) => (e['iso_3166_1'] == region));
        final rels = (x?['release_dates'] as List? ?? []);
        final c = rels
            .map((e) => (e['certification'] ?? '').toString())
            .firstWhereOrNull((s) => s.isNotEmpty);
        return c ?? '';
      } else {
        final arr = (d['content_ratings']?['results'] as List? ?? []);
        final x = arr.firstWhereOrNull((e) => (e['iso_3166_1'] == region));
        final rating = (x?['rating'] ?? '').toString();
        return rating;
      }
    } catch (_) {
      return '';
    }
  }
}

// Star rating (0.5 step)
class _StarRating extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _StarRating({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _update(d.localPosition.dx),
      onTapDown: (d) => _update(d.localPosition.dx),
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final full = (value >= i + 1);
            final half = (!full && value >= i + 0.5);
            return Icon(
              full ? Icons.star : (half ? Icons.star_half : Icons.star_border),
              color: Colors.amber,
              size: 28,
            );
          }),
        ),
      ),
    );
  }

  void _update(double dx) {
    const w = 160.0;
    double v = (dx / w) * 5.0;
    v = (v * 2).clamp(0, 10).round() / 2.0;
    onChanged(v);
  }
}

// auto-slide gallery (no dots)
class _AutoSlideGallery extends StatefulWidget {
  final List<String> paths;
  const _AutoSlideGallery({required this.paths});

  @override
  State<_AutoSlideGallery> createState() => _AutoSlideGalleryState();
}

class _AutoSlideGalleryState extends State<_AutoSlideGallery> {
  final PageController _pc = PageController();
  Timer? _timer;
  int _index = 0;
  static const Duration _interval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    if (widget.paths.isNotEmpty) {
      _timer = Timer.periodic(_interval, (_) {
        if (!mounted || !_pc.hasClients) return;
        _index = (_index + 1) % widget.paths.length;
        _pc.animateToPage(
          _index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PageView.builder(
        controller: _pc,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => _index = i,
        itemCount: widget.paths.length,
        itemBuilder: (_, i) {
          final url = TmdbService.imageW780(widget.paths[i]);
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.white10),
            errorWidget: (_, __, ___) => Container(color: Colors.white10),
          );
        },
      ),
    );
  }
}

// safe extensions
extension _ListSafe<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _IterableSafe<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

// collection sub widget
class _CollectionSection extends StatelessWidget {
  final int id;
  final TmdbService api;
  const _CollectionSection({required this.id, required this.api});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: api.movieDetails(id),
      builder: (context, snapD) {
        if (!snapD.hasData) return const SizedBox.shrink();
        final coll =
            snapD.data!['belongs_to_collection'] as Map<String, dynamic>?;
        final collId = coll?['id'] as int?;
        final collName = coll?['name']?.toString();
        if (collId == null || collName == null) return const SizedBox.shrink();

        return FutureBuilder<Map<String, dynamic>>(
          future: api.collectionDetails(collId),
          builder: (context, snapC) {
            if (snapC.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            if (!snapC.hasData) return const SizedBox.shrink();
            final parts = (snapC.data!['parts'] as List? ?? [])
                .cast<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            parts.sort((a, b) {
              final da = (a['release_date'] ?? '').toString();
              final db = (b['release_date'] ?? '').toString();
              return da.compareTo(db);
            });
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part of the $collName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: parts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final p = parts[i];
                        final pid = p['id'] as int;
                        final pposter = p['poster_path'] as String?;
                        final isCurrent = pid == id;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetailsPage(mediaType: 'movie', id: pid),
                            ),
                          ),
                          child: Container(
                            width: 128,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isCurrent
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: pposter == null
                                  ? Container(color: Colors.white10)
                                  : CachedNetworkImage(
                                      imageUrl: TmdbService.imageW500(pposter),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}