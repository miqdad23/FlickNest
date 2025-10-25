// lib/features/lists/list_grid_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../ui/glass_sheet.dart'; // GlassSheet + GlassStyle
import '../../app/widgets/shimmers.dart';
import '../../core/assets/assets.dart';
import '../../core/tmdb/tmdb_models.dart';
import '../../core/tmdb/tmdb_service.dart';
import '../details/details_page.dart';
import 'models/custom_list.dart';
import 'models/snap_store.dart';
import 'models/default_index.dart';

enum _SortBy { original, alpha, releaseNew, releaseOld }

enum _TypeFilter { both, movie, tv }

class ListGridPage extends StatefulWidget {
  final String title;
  final String? defaultPrefix; // 'fav_' | 'watchlist_' | 'watched_'
  final CustomList? custom;

  const ListGridPage._({required this.title, this.defaultPrefix, this.custom});

  factory ListGridPage.defaultList({
    required String title,
    required String prefix,
  }) => ListGridPage._(title: title, defaultPrefix: prefix);

  factory ListGridPage.customList({required CustomList list}) =>
      ListGridPage._(title: list.name, custom: list);

  @override
  State<ListGridPage> createState() => _ListGridPageState();
}

class _ListGridPageState extends State<ListGridPage> {
  final _api = TmdbService();

  List<_ItemKey> _keysOrder = [];
  final Map<String, TmdbMovie> _byKey = {};
  final Map<String, List<String>> _genresByKey = {};

  final List<TmdbMovie> _all = [];
  final List<TmdbMovie> _filtered = [];

  bool _loading = true;
  String? _error;

  List<_ItemKey> _missing = [];
  bool _syncingMissing = false;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  _SortBy _sort = _SortBy.original;
  _TypeFilter _typeFilter = _TypeFilter.both;

  int? _yearFrom;
  int? _yearTo;
  final Set<String> _selectedGenres = <String>{};

  bool _selectMode = false;
  final Set<String> _selected = <String>{};
  String? _singleDeleteKey;

  final List<TmdbMovie> _sugs = [];
  bool _loadingSug = false;
  int _sugPage = 1;
  late final String _sugMedia = _decideSuggestionMedia();
  final ScrollController _sugCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _sugCtrl.addListener(_onSugScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _sugCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _byKey.clear();
      _all.clear();
      _filtered.clear();
      _genresByKey.clear();
      _selectedGenres.clear();
      _selected.clear();
      _singleDeleteKey = null;
      _selectMode = false;
      _missing = [];
      _syncingMissing = false;
    });
    try {
      _keysOrder = await _collectItemKeys();

      final baseKeys = _keysOrder.map((k) => '${k.mediaType}_${k.id}').toList();
      final snaps = await SnapStore.loadMany(baseKeys);

      for (final k in _keysOrder) {
        final bk = '${k.mediaType}_${k.id}';
        final s = snaps[bk];
        if (s != null) {
          _byKey[bk] = _movieFromSnap(s);
          _genresByKey[bk] = List<String>.from(s.genres);
        } else {
          _missing.add(k);
        }
      }

      _rebuildAllFromMap();
      _applyFiltersSort();

      setState(() {
        _loading = false;
        _syncingMissing = _missing.isNotEmpty;
      });

      if (_missing.isNotEmpty) {
        unawaited(_fetchMissingInBackground());
      }

      _sugs.clear();
      _sugPage = 1;
      await _loadMoreSuggestions();
    } catch (e) {
      _error = e.toString();
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMissingInBackground() async {
    const chunk = 6;
    for (int i = 0; i < _missing.length; i += chunk) {
      final slice = _missing.sublist(
        i,
        (i + chunk > _missing.length) ? _missing.length : i + chunk,
      );
      final futures = slice.map((k) async {
        try {
          final d = (k.mediaType == 'tv')
              ? await _api.tvDetails(k.id)
              : await _api.movieDetails(k.id);

          try {
            final snap = SnapStore.fromDetails(k.mediaType, d);
            await SnapStore.save(snap);
            _genresByKey['${k.mediaType}_${k.id}'] = snap.genres;
            return _movieFromSnap(snap);
          } catch (_) {
            final title = (d['title'] ?? d['name'] ?? '').toString();
            final poster = d['poster_path']?.toString();
            final back = d['backdrop_path']?.toString();
            final date = (d['release_date'] ?? d['first_air_date'])?.toString();
            final vote = (d['vote_average'] is num)
                ? (d['vote_average'] as num).toDouble()
                : null;
            final gens = ((d['genres'] as List?) ?? [])
                .map((e) => (e as Map)['name']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
            _genresByKey['${k.mediaType}_${k.id}'] = gens;
            return TmdbMovie(
              id: k.id,
              title: title,
              posterPath: poster,
              backdropPath: back,
              releaseDate: date,
              mediaType: k.mediaType,
              voteAverage: vote,
            );
          }
        } catch (_) {
          return null;
        }
      }).toList();

      final got = await Future.wait(futures);
      int idx = 0;
      for (final k in slice) {
        final mv = got[idx++];
        if (mv != null) {
          final bk = '${k.mediaType}_${k.id}';
          _byKey[bk] = mv;
        }
      }
      _rebuildAllFromMap();
      _applyFiltersSort();
      if (mounted) setState(() {});
    }

    _syncingMissing = false;
    if (mounted) setState(() {});
  }

  void _rebuildAllFromMap() {
    _all
      ..clear()
      ..addAll(
        _keysOrder
            .map((k) => _byKey['${k.mediaType}_${k.id}'])
            .whereType<TmdbMovie>(),
      );
  }

  Future<List<_ItemKey>> _collectItemKeys() async {
    if (widget.custom != null) {
      return widget.custom!.itemKeys
          .map(_ItemKey.fromBaseKey)
          .whereType<_ItemKey>()
          .toList();
    }
    final prefix = widget.defaultPrefix!;
    final idx = await DefaultIndexStore.allByPrefix(prefix);
    return idx.map(_ItemKey.fromBaseKey).whereType<_ItemKey>().toList();
  }

  TmdbMovie _movieFromSnap(TmdbSnap s) => TmdbMovie(
    id: s.id,
    title: s.title,
    posterPath: s.posterPath,
    backdropPath: s.backdropPath,
    releaseDate: s.date,
    mediaType: s.mediaType,
    voteAverage: s.voteAverage,
  );

  // ---------------- suggestions ----------------
  String _decideSuggestionMedia() {
    if (widget.custom != null) {
      final t = widget.custom!.type;
      if (t == 'movie') return 'movie';
      if (t == 'tv') return 'tv';
    }
    return 'movie';
  }

  void _onSugScroll() {
    if (_loadingSug) return;
    if (_sugCtrl.position.extentAfter < 300) _loadMoreSuggestions();
  }

  Future<void> _loadMoreSuggestions() async {
    _loadingSug = true;
    try {
      final more = (_sugMedia == 'tv')
          ? await _api.trendingTv(page: _sugPage)
          : await _api.trendingMovies(page: _sugPage);
      final ids = _all.map((e) => '${e.mediaType}_${e.id}').toSet();
      more.removeWhere((m) => ids.contains('${m.mediaType}_${m.id}'));
      _sugs.addAll(more);
      _sugPage++;
      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      _loadingSug = false;
    }
  }

  // ---------------- search/filter/sort ----------------
  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyFiltersSort);
    setState(() {});
  }

  void _applyFiltersSort() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<TmdbMovie> cur = List.of(_all);

    if (_typeFilter != _TypeFilter.both) {
      final t = (_typeFilter == _TypeFilter.movie) ? 'movie' : 'tv';
      cur = cur.where((m) => m.mediaType == t).toList();
    }

    int? yf = _yearFrom, yt = _yearTo;
    if (yf != null && yt != null && yf > yt) {
      final tmp = yf;
      yf = yt;
      yt = tmp;
    }
    if (yf != null || yt != null) {
      cur = cur.where((m) {
        final y = _yearOf(m);
        if (y == null) return false;
        if (yf != null && y < yf) return false;
        if (yt != null && y > yt) return false;
        return true;
      }).toList();
    }

    if (_selectedGenres.isNotEmpty) {
      cur = cur.where((m) {
        final g = _genresByKey['${m.mediaType}_${m.id}'] ?? const [];
        return g.any((name) => _selectedGenres.contains(name));
      }).toList();
    }

    if (q.isNotEmpty) {
      cur = cur.where((m) => m.title.toLowerCase().contains(q)).toList();
    }

    switch (_sort) {
      case _SortBy.original:
        break;
      case _SortBy.alpha:
        cur.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case _SortBy.releaseNew:
        cur.sort(
          (a, b) => (_yearOf(b) ?? -9999).compareTo(_yearOf(a) ?? -9999),
        );
        break;
      case _SortBy.releaseOld:
        cur.sort((a, b) => (_yearOf(a) ?? 9999).compareTo(_yearOf(b) ?? 9999));
        break;
    }

    _filtered
      ..clear()
      ..addAll(cur);
    if (mounted) setState(() {});
  }

  int? _yearOf(TmdbMovie m) {
    final d = m.releaseDate;
    if (d == null || d.isEmpty) return null;
    return int.tryParse(d.split('-').first);
  }

  List<String> _availableGenres() {
    final set = <String>{};
    for (final m in _all) {
      final base = '${m.mediaType}_${m.id}';
      final g = _genresByKey[base] ?? const [];
      set.addAll(g);
    }
    final list = set.toList()..sort();
    return list;
  }

  // ---------------- selection logic ----------------
  String _baseKeyOf(TmdbMovie m) => '${m.mediaType}_${m.id}';

  void _handleLongPress(TmdbMovie m) {
    final k = _baseKeyOf(m);
    if (_selectMode) {
      _toggleSelect(k);
      return;
    }
    if (_singleDeleteKey == null) {
      _singleDeleteKey = k;
      HapticFeedback.mediumImpact();
      setState(() {});
      return;
    }
    _selectMode = true;
    _selected
      ..clear()
      ..add(_singleDeleteKey!)
      ..add(k);
    _singleDeleteKey = null;
    HapticFeedback.heavyImpact();
    setState(() {});
  }

  void _toggleSelect(String k) {
    if (_selected.contains(k)) {
      _selected.remove(k);
      if (_selected.isEmpty) _selectMode = false;
    } else {
      _selected.add(k);
    }
    HapticFeedback.selectionClick();
    setState(() {});
  }

  Future<void> _removeOne(TmdbMovie m) async {
    HapticFeedback.heavyImpact();
    final base = _baseKeyOf(m);
    if (widget.custom != null) {
      final list = widget.custom!;
      await CustomListStore.removeItem(list.id, base);
    } else {
      final prefix = widget.defaultPrefix!;
      final idxKey = DefaultIndexStore.indexKeyForPrefix(prefix);
      await DefaultIndexStore.remove(idxKey, base);
    }

    _byKey.remove(base);
    _keysOrder.removeWhere((k) => '${k.mediaType}_${k.id}' == base);
    _rebuildAllFromMap();
    _applyFiltersSort();
    _singleDeleteKey = null;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from list')));
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    HapticFeedback.heavyImpact();

    if (widget.custom != null) {
      final list = widget.custom!;
      await CustomListStore.removeItems(list.id, _selected.toList());
    } else {
      final prefix = widget.defaultPrefix!;
      final idxKey = DefaultIndexStore.indexKeyForPrefix(prefix);
      await DefaultIndexStore.removeMany(idxKey, _selected.toList());
    }

    for (final k in _selected) {
      _byKey.remove(k);
    }
    _keysOrder.removeWhere((k) => _selected.contains('${k.mediaType}_${k.id}'));
    _rebuildAllFromMap();
    _applyFiltersSort();
    _selected.clear();
    _selectMode = false;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from list')));
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _singleDeleteKey == null && !_selectMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_singleDeleteKey != null || _selectMode) {
          setState(() {
            _singleDeleteKey = null;
            _selectMode = false;
            _selected.clear();
          });
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: _selectMode ? _buildSelectAppBar() : _buildNormalAppBar(),
        body: _buildBody(),
      ),
    );
  }

  // Title + optional 2-line description (for custom lists) + search row
  PreferredSizeWidget _buildNormalAppBar() {
    final cs = Theme.of(context).colorScheme;
    final showClear = _searchCtrl.text.isNotEmpty;

    final descMaybe = widget.custom?.description?.trim() ?? '';
    final hasDesc = descMaybe.isNotEmpty;

    const double baseH = 64; // search row
    final double extraH = hasDesc ? 40 : 0; // space for 2-line desc
    final double totalH = baseH + extraH;

    return AppBar(
      title: Text(widget.title),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(totalH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDesc)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    descMaybe, // no '!' needed
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).cardColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onQueryChanged,
                        decoration: InputDecoration(
                          hintText: 'Search in this list...',
                          border: InputBorder.none,
                          icon: const Icon(Icons.search),
                          suffixIcon: showClear
                              ? IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onQueryChanged('');
                                  },
                                  icon: const Icon(Icons.close),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Filter',
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.filter_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Sort',
                    onPressed: _showSortSheet,
                    icon: const Icon(Icons.sort),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectAppBar() {
    return AppBar(
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Delete selected',
          onPressed: _deleteSelected,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const _GridSkeletonSliverWrapper();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final content = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (_filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
              child: Text(
                _all.isEmpty && _syncingMissing
                    ? 'Loading your items...'
                    : (_all.isEmpty
                          ? 'This list is empty.'
                          : 'No items match your search/filters.'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomSafe),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, i) {
              if (i >= _filtered.length) return const SizedBox.shrink();
              final m = _filtered[i];
              final base = _baseKeyOf(m);
              final selected = _selected.contains(base);
              final showInlineDelete =
                  (_singleDeleteKey == base) && !_selectMode;
              return GestureDetector(
                onTap: () {
                  if (_singleDeleteKey != null) {
                    setState(() => _singleDeleteKey = null);
                    return;
                  }
                  if (_selectMode) {
                    _toggleSelect(base);
                  } else {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      _zoomRoute(DetailsPage(mediaType: m.mediaType, id: m.id)),
                    );
                  }
                },
                onLongPress: () => _handleLongPress(m),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PosterTile(movie: m),
                    if (selected)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: const Color.fromRGBO(0, 0, 0, 0.25),
                        ),
                      ),
                    if (selected)
                      const Positioned(
                        top: 6,
                        left: 6,
                        child: Icon(Icons.check_circle, color: Colors.white),
                      ),
                    if (showInlineDelete)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: FloatingActionButton.small(
                          heroTag: 'del_$base',
                          backgroundColor: Colors.redAccent,
                          onPressed: () => _removeOne(m),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }, childCount: _filtered.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2 / 3,
            ),
          ),
        ),

        if (_sugs.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Text(
                'Suggestions for you',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        if (_sugs.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: ListView.separated(
                controller: _sugCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _sugs.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = _sugs[i];
                  final url = TmdbService.imageW500(
                    m.posterPath ?? m.backdropPath,
                  );
                  return GestureDetector(
                    onTap: () {
                      if (_singleDeleteKey != null) {
                        setState(() => _singleDeleteKey = null);
                        return;
                      }
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        _zoomRoute(
                          DetailsPage(mediaType: m.mediaType, id: m.id),
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
                            child: url.isEmpty
                                ? Image.asset(
                                    AppAssets.posterPlaceholder,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: url,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Image.asset(
                                      AppAssets.posterPlaceholder,
                                      height: 180,
                                      fit: BoxFit.cover,
                                    ),
                                    errorWidget: (_, __, ___) => Image.asset(
                                      AppAssets.posterPlaceholder,
                                      height: 180,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        if (_loadingSug || _syncingMissing)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    return NotificationListener<ScrollStartNotification>(
      onNotification: (_) {
        if (_singleDeleteKey != null) setState(() => _singleDeleteKey = null);
        return false;
      },
      child: content,
    );
  }

  Route _zoomRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ---------------- Filter & Sort Sheets (GlassSheet) ----------------

  void _showFilterSheet() {
    HapticFeedback.lightImpact();

    final genres = _availableGenres();
    _TypeFilter tmpType = _typeFilter;
    final tmpGenres = Set<String>.from(_selectedGenres);
    final yearFromCtrl = TextEditingController(
      text: _yearFrom?.toString() ?? '',
    );
    final yearToCtrl = TextEditingController(text: _yearTo?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.editSheet(cs);
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: GlassSheet(
            style: style,
            child: StatefulBuilder(
              builder: (ctx2, setSB) {
                Widget typeChip(_TypeFilter type, String label) {
                  final sel = tmpType == type;
                  return ChoiceChip(
                    selected: sel,
                    label: Text(label),
                    onSelected: (_) => setSB(() => tmpType = type),
                  );
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Type',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          typeChip(_TypeFilter.both, 'Both'),
                          typeChip(_TypeFilter.movie, 'Movies'),
                          typeChip(_TypeFilter.tv, 'TV'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Year',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: yearFromCtrl,
                              decoration: const InputDecoration(
                                labelText: 'From',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: yearToCtrl,
                              decoration: const InputDecoration(
                                labelText: 'To',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (genres.isNotEmpty) ...[
                        const Text(
                          'Genres',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: genres.map((g) {
                            final sel = tmpGenres.contains(g);
                            return FilterChip(
                              selected: sel,
                              label: Text(g),
                              onSelected: (_) => setSB(() {
                                if (sel) {
                                  tmpGenres.remove(g);
                                } else {
                                  tmpGenres.add(g);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setSB(() {
                                tmpType = _TypeFilter.both;
                                yearFromCtrl.clear();
                                yearToCtrl.clear();
                                tmpGenres.clear();
                              });
                            },
                            child: const Text('Reset'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              final yf = int.tryParse(yearFromCtrl.text.trim());
                              final yt = int.tryParse(yearToCtrl.text.trim());
                              setState(() {
                                _typeFilter = tmpType;
                                _yearFrom = yf;
                                _yearTo = yt;
                                _selectedGenres
                                  ..clear()
                                  ..addAll(tmpGenres);
                              });
                              _applyFiltersSort();
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSortSheet() {
    HapticFeedback.lightImpact();

    _SortBy tmp = _sort;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.editSheet(cs);

        Widget sortRow(_SortBy v, String title, String sub) {
          final sel = tmp == v;
          final icon = sel
              ? Icons.radio_button_checked
              : Icons.radio_button_off;
          final color = sel ? cs.primary : cs.onSurface.withValues(alpha: 0.80);
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(title),
            subtitle: Text(sub),
            onTap: () {
              setState(() {}); // keep semantics
              tmp = v;
              HapticFeedback.selectionClick();
            },
          );
        }

        return GlassSheet(
          style: style,
          child: StatefulBuilder(
            builder: (ctx2, setSB) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sort',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Options (no RadioListTile → no deprecation)
                    InkWell(
                      onTap: () {
                        setSB(() => tmp = _SortBy.original);
                        HapticFeedback.selectionClick();
                      },
                      child: sortRow(
                        _SortBy.original,
                        'Original order',
                        'As you added them',
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setSB(() => tmp = _SortBy.alpha);
                        HapticFeedback.selectionClick();
                      },
                      child: sortRow(
                        _SortBy.alpha,
                        'A → Z',
                        'Sort by title (A–Z)',
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setSB(() => tmp = _SortBy.releaseNew);
                        HapticFeedback.selectionClick();
                      },
                      child: sortRow(
                        _SortBy.releaseNew,
                        'Release: New to Old',
                        'Latest first',
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setSB(() => tmp = _SortBy.releaseOld);
                        HapticFeedback.selectionClick();
                      },
                      child: sortRow(
                        _SortBy.releaseOld,
                        'Release: Old to New',
                        'Oldest first',
                      ),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSB(() => tmp = _SortBy.original);
                          },
                          child: const Text('Default'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _sort = tmp);
                            _applyFiltersSort();
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PosterTile extends StatelessWidget {
  final TmdbMovie movie;
  const _PosterTile({required this.movie});

  @override
  Widget build(BuildContext context) {
    final url = TmdbService.imageW500(movie.posterPath ?? movie.backdropPath);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: url.isEmpty
              ? Image.asset(AppAssets.posterPlaceholder, fit: BoxFit.cover)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 220),
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
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GridSkeletonSliverWrapper extends StatelessWidget {
  const _GridSkeletonSliverWrapper();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: Divider(height: 1)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const ShimmerRect(borderRadius: 12),
              childCount: 12,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2 / 3,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemKey {
  final String mediaType; // movie | tv
  final int id;
  const _ItemKey(this.mediaType, this.id);

  static _ItemKey? fromBaseKey(String base) {
    final parts = base.split('_');
    if (parts.length != 2) return null;
    final mt = parts[0];
    final id = int.tryParse(parts[1]);
    if (id == null) return null;
    if (mt != 'movie' && mt != 'tv') return null;
    return _ItemKey(mt, id);
  }
}
