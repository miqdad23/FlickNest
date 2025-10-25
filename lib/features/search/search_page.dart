// lib/features/search/search_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/glass_sheet.dart'; // GlassSheet + GlassStyle
import '../../core/tmdb/tmdb_service.dart';
import '../../core/tmdb/tmdb_models.dart';
import '../details/details_page.dart';
import '../person/person_page.dart';
import 'genre_discover_page.dart';
import 'all_genres_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final _api = TmdbService();

  // Controllers
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _resultCtrl = ScrollController();
  final ScrollController _peopleCtrl = ScrollController();

  // UI state
  bool _loadingInit = true;

  // Query
  Timer? _debounce;
  String _query = '';
  int _seq = 0; // search generation id (cancelation)

  // Data caches
  final Map<int, String> _movieGenres = {};
  final Map<int, String> _tvGenres = {};
  List<_Lang> _allLangs = [];
  List<_Country> _allCountries = [];
  List<String> _recent = [];

  // Initial sections
  List<TmdbMovie> _trendMovies = [];
  List<TmdbMovie> _trendTv = [];
  final List<TmdbMovie> _sugs = [];
  bool _loadingSug = false;
  int _sugPage = 1;

  // Results
  final List<TmdbMovie> _resMovie = [];
  final List<TmdbMovie> _resTv = [];
  final List<Map<String, dynamic>> _people = [];
  bool _loadingResults = false;
  bool _loadingMore = false;
  int _pageMovie = 1, _pageTv = 1;
  bool _hasMoreMovie = true, _hasMoreTv = true;

  // People pagination
  int _peoplePage = 1;
  bool _hasMorePeople = true;
  bool _loadingMorePeople = false;

  // Filters
  double? _minRating; // 5,6,7,8 (or null)
  final Set<String> _langs = {}; // multi-select (iso_639-1)
  final Set<String> _countries = {}; // multi-select (iso_3166-1, TV only)
  final Set<int> _selectedGenreIds = {};
  bool _genresExpanded = false;

  // Year range (slider)
  final int _minYear = 1960;
  final int _maxYear = DateTime.now().year;
  int? _yearFrom;
  int? _yearTo;

  // Tabs
  late final TabController _tabCtrl = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _resultCtrl.addListener(_onResultScroll);
    _peopleCtrl.addListener(_onPeopleScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _resultCtrl.dispose();
    _peopleCtrl.dispose();
    _searchCtrl.dispose();
    _focus.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // বাহির থেকে কল হবে (Home থেকে Search ট্যাব ছাড়লে)
  void resetToDefault() {
    _resetAll(clearKeyboard: true);
  }

  // ---------------- Initial load ----------------
  Future<void> _loadInitial() async {
    try {
      // recent
      final p = await SharedPreferences.getInstance();
      _recent = (p.getStringList('recent_queries') ?? []).reversed.toList();

      // parallel loads
      final gmF = _api.genreListMovie();
      final gtF = _api.genreListTv();
      final langsF = _api.allLanguages();
      final countriesF = _api.allCountries();
      final tmF = _api.trendingMovies(page: 1);
      final ttF = _api.trendingTv(page: 1);

      final results = await Future.wait([
        gmF,
        gtF,
        langsF,
        countriesF,
        tmF,
        ttF,
      ]);

      // genres
      for (final g in (results[0] as List<Map<String, dynamic>>)) {
        final id = g['id'] as int?;
        final name = (g['name'] ?? '').toString();
        if (id != null && name.isNotEmpty) _movieGenres[id] = name;
      }
      for (final g in (results[1] as List<Map<String, dynamic>>)) {
        final id = g['id'] as int?;
        final name = (g['name'] ?? '').toString();
        if (id != null && name.isNotEmpty) _tvGenres[id] = name;
      }

      // languages
      _allLangs =
          (results[2] as List<Map<String, dynamic>>)
              .map(
                (e) => _Lang(
                  code: (e['iso_639_1'] ?? '').toString(),
                  name: (e['english_name'] ?? e['name'] ?? '').toString(),
                ),
              )
              .where((l) => l.code.isNotEmpty && l.name.isNotEmpty)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      // countries
      _allCountries =
          (results[3] as List<Map<String, dynamic>>)
              .map(
                (e) => _Country(
                  code: (e['iso_3166_1'] ?? '').toString(),
                  name: (e['english_name'] ?? '').toString(),
                ),
              )
              .where((c) => c.code.isNotEmpty && c.name.isNotEmpty)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      // trends
      _trendMovies = (results[4] as List<TmdbMovie>).take(10).toList();
      _trendTv = (results[5] as List<TmdbMovie>).take(10).toList();

      // sugs
      _sugs.clear();
      _sugPage = 1;
      await _loadMoreSuggestions();
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _loadingInit = false);
    }
  }

  Future<void> _loadMoreSuggestions() async {
    if (_loadingSug) return;
    setState(() => _loadingSug = true);
    try {
      final more = await _api.trendingMovies(page: _sugPage);
      _sugs.addAll(more);
      _sugPage++;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSug = false);
    }
  }

  // ---------------- Query handling ----------------
  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _query = v.trim());
      if (_query.isEmpty) {
        _clearResults(); // keep filters, only clear results
        return;
      }
      await _startSearch();
    });
  }

  Future<void> _startSearch() async {
    final mySeq = ++_seq;
    setState(() {
      _loadingResults = true;
      _resMovie.clear();
      _resTv.clear();
      _people.clear();
      _pageMovie = 1;
      _pageTv = 1;
      _peoplePage = 1;
      _hasMoreMovie = true;
      _hasMoreTv = true;
      _hasMorePeople = true;
    });

    try {
      final futures = <Future>[];
      futures.add(
        _api.searchMovies(_query, page: 1).then((m) {
          if (mySeq == _seq) _resMovie.addAll(m);
        }),
      );
      futures.add(
        _api.searchTv(_query, page: 1).then((t) {
          if (mySeq == _seq) _resTv.addAll(t);
        }),
      );
      futures.add(
        _api.searchPerson(_query, page: 1).then((p) {
          if (mySeq == _seq) _people.addAll(p);
        }),
      );
      await Future.wait(futures);

      _hasMoreMovie = _resMovie.isNotEmpty;
      _hasMoreTv = _resTv.isNotEmpty;
      _hasMorePeople = _people.isNotEmpty;

      _applyFilters();
    } catch (_) {
    } finally {
      if (mounted && mySeq == _seq) {
        setState(() => _loadingResults = false);
      }
    }
  }

  void _onResultScroll() {
    if (_query.isEmpty || _loadingMore || _loadingResults) return;
    if (_resultCtrl.position.extentAfter < 600) {
      _loadMoreResults();
    }
  }

  void _onPeopleScroll() {
    if (_query.isEmpty || _loadingMorePeople || _loadingResults) return;
    if (_peopleCtrl.position.extentAfter < 600) {
      _loadMorePeople();
    }
  }

  Future<void> _loadMoreResults() async {
    if (_loadingMore) return;
    final mySeq = ++_seq;
    setState(() => _loadingMore = true);
    try {
      final calls = <Future<List<TmdbMovie>>>[];
      if (_hasMoreMovie) {
        calls.add(_api.searchMovies(_query, page: _pageMovie + 1));
      }
      if (_hasMoreTv) {
        calls.add(_api.searchTv(_query, page: _pageTv + 1));
      }
      if (calls.isEmpty) return;

      final res = await Future.wait(calls);
      int idx = 0;
      if (_hasMoreMovie) {
        final got = res[idx++];
        _hasMoreMovie = got.isNotEmpty;
        if (_hasMoreMovie) _pageMovie++;
        if (mySeq == _seq) _resMovie.addAll(got);
      }
      if (_hasMoreTv) {
        final got = res[idx++];
        _hasMoreTv = got.isNotEmpty;
        if (_hasMoreTv) _pageTv++;
        if (mySeq == _seq) _resTv.addAll(got);
      }

      _applyFilters();
    } catch (_) {
    } finally {
      if (mounted && mySeq == _seq) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMorePeople() async {
    if (_loadingMorePeople || !_hasMorePeople) return;
    final mySeq = ++_seq;
    setState(() => _loadingMorePeople = true);
    try {
      final next = await _api.searchPerson(_query, page: _peoplePage + 1);
      _hasMorePeople = next.isNotEmpty;
      if (_hasMorePeople) _peoplePage++;
      if (mySeq == _seq) _people.addAll(next);
    } catch (_) {
    } finally {
      if (mounted && mySeq == _seq) {
        setState(() => _loadingMorePeople = false);
      }
    }
  }

  // ---------------- Filters ----------------
  void _applyFilters() {
    // Normalize year bounds
    int? yf = _yearFrom, yt = _yearTo;
    if (yf != null && yt != null && yf > yt) {
      final t = yf;
      yf = yt;
      yt = t;
    }
    setState(() {}); // results filtered in builders with helpers below
  }

  void _clearResults() {
    _resMovie.clear();
    _resTv.clear();
    _people.clear();
    _pageMovie = 1;
    _pageTv = 1;
    _peoplePage = 1;
    _hasMoreMovie = true;
    _hasMoreTv = true;
    _hasMorePeople = true;
    _seq++;
    setState(() {});
  }

  void _resetAll({bool clearKeyboard = false}) {
    _searchCtrl.clear();
    _query = '';
    _clearResults();
    _minRating = null;
    _langs.clear();
    _countries.clear();
    _selectedGenreIds.clear();
    _genresExpanded = false;
    _yearFrom = null;
    _yearTo = null;
    _tabCtrl.index = 0; // scope reset to All
    if (clearKeyboard) _focus.unfocus();
  }

  Future<void> _addRecent(String q) async {
    if (q.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('recent_queries') ?? <String>[];
    list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.add(q);
    while (list.length > 10) {
      list.removeAt(0);
    }
    await p.setStringList('recent_queries', list);
    _recent = list.reversed.toList();
    if (mounted) setState(() {});
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final isTyping = _query.isNotEmpty;

    return NestedScrollView(
      controller: isTyping ? _resultCtrl : null,
      headerSliverBuilder: (ctx, inner) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent,
          toolbarHeight: 72,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: _GlassSearchBar(
              controller: _searchCtrl,
              focusNode: _focus,
              onChanged: _onQueryChanged,
              onSubmitted: (q) async {
                await _addRecent(q.trim());
              },
              onClear: () {
                HapticFeedback.lightImpact();
                _resetAll();
                _focus.requestFocus(); // keyboard stays
              },
              onFilter: () {
                HapticFeedback.lightImpact();
                _openFilterSheetGlass();
              },
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabCtrl,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildAllTab(),
          _buildMoviesTab(),
          _buildTvTab(),
          _buildPeopleTab(),
        ],
      ),
    );
  }

  // ------------- Tabs content -------------
  Widget _buildAllTab() {
    if (_loadingInit && _query.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_query.isEmpty) {
      final trendsCombined = <TmdbMovie>[
        ..._trendMovies,
        ..._trendTv,
      ].take(20).toList();
      return _InitialSections(
        recent: _recent,
        onTapRecent: (q) {
          HapticFeedback.lightImpact();
          _searchCtrl.text = q;
          _onQueryChanged(q);
          _focus.requestFocus();
        },
        onTapSeeAll: () {
          HapticFeedback.lightImpact();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => AllGenresPage(api: _api)));
        },
        popularGenres: _popularGenreChips(),
        trends: trendsCombined,
        sugs: _sugs,
        onOpenDetails: _openDetails,
        onLoadMoreSugs: () {
          if (!_loadingSug) _loadMoreSuggestions();
        },
        loadingSug: _loadingSug,
      );
    }

    if (_loadingResults && _resMovie.isEmpty && _resTv.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final allFiltered = _mergeFilteredResults();

    if (!_loadingResults && allFiltered.isEmpty) {
      return _EmptyWithSugs(
        sugs: _sugs,
        onOpen: _openDetails,
        onMore: () {
          if (!_loadingSug) _loadMoreSuggestions();
        },
        loadingMore: _loadingSug,
      );
    }

    return ListView.builder(
      controller: _resultCtrl,
      physics: const BouncingScrollPhysics(),
      itemCount: allFiltered.length + (_loadingMore ? 1 : 0),
      padding: const EdgeInsets.only(top: 6),
      itemBuilder: (_, i) {
        if (i >= allFiltered.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final m = allFiltered[i];
        return _ResultTile(
          movie: m,
          onOpen: _openDetails,
          genre: _firstGenreName(m),
        );
      },
    );
  }

  Widget _buildMoviesTab() {
    if (_query.isEmpty) {
      return _InitialSingleType(
        title: 'Top Searches (Movies)',
        items: _trendMovies,
        sugs: _sugs,
        onOpen: _openDetails,
        onMore: () {
          if (!_loadingSug) _loadMoreSuggestions();
        },
        loadingMore: _loadingSug,
      );
    }

    if (_loadingResults && _resMovie.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filterSpecific(_resMovie);
    if (!_loadingResults && filtered.isEmpty) {
      return _EmptyWithSugs(
        sugs: _sugs,
        onOpen: _openDetails,
        onMore: () {
          if (!_loadingSug) _loadMoreSuggestions();
        },
        loadingMore: _loadingSug,
      );
    }

    return ListView.builder(
      controller: _resultCtrl,
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length + (_loadingMore ? 1 : 0),
      padding: const EdgeInsets.only(top: 6),
      itemBuilder: (_, i) {
        if (i >= filtered.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final m = filtered[i];
        return _ResultTile(
          movie: m,
          onOpen: _openDetails,
          genre: _firstGenreName(m),
        );
      },
    );
  }

  Widget _buildTvTab() {
    if (_query.isEmpty) {
      return _InitialSingleType(
        title: 'Top Searches (TV)',
        items: _trendTv,
        sugs: _sugs,
        onOpen: _openDetails,
        onMore: () {
          if (!_loadingSug) _loadMoreSuggestions();
        },
        loadingMore: _loadingSug,
      );
    }

    if (_loadingResults && _resTv.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filterSpecific(_resTv);
    if (!_loadingResults && filtered.isEmpty) {
      return _EmptyWithSugs(
        sugs: _sugs,
        onOpen: _openDetails,
        onMore: () {
          if (!_loadingSug) _loadMoreSuggestions();
        },
        loadingMore: _loadingSug,
      );
    }

    return ListView.builder(
      controller: _resultCtrl,
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length + (_loadingMore ? 1 : 0),
      padding: const EdgeInsets.only(top: 6),
      itemBuilder: (_, i) {
        if (i >= filtered.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final m = filtered[i];
        return _ResultTile(
          movie: m,
          onOpen: _openDetails,
          genre: _firstGenreName(m),
        );
      },
    );
  }

  Widget _buildPeopleTab() {
    if (_query.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: Text('Start typing to search people...'),
        ),
      );
    }
    if (_loadingResults && _people.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      controller: _peopleCtrl,
      physics: const BouncingScrollPhysics(),
      itemCount: _people.length + (_loadingMorePeople ? 1 : 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        if (i >= _people.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = _people[i];
        final id = p['id'] as int?;
        final name = (p['name'] ?? '').toString();
        final profile = p['profile_path']?.toString();
        return InkWell(
          onTap: () {
            if (id == null) return;
            HapticFeedback.lightImpact();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PersonPage(personId: id)));
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: (profile == null)
                    ? null
                    : NetworkImage(TmdbService.imageW500(profile)),
                backgroundColor: Colors.white10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- Helpers ----------------
  List<TmdbMovie> _mergeFilteredResults() {
    final m = _filterSpecific(_resMovie);
    final t = _filterSpecific(_resTv);
    final all = <TmdbMovie>[...m, ...t];
    all.sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
    return all;
  }

  List<TmdbMovie> _filterSpecific(List<TmdbMovie> src) {
    // Normalize years
    int? yf = _yearFrom, yt = _yearTo;
    if (yf != null && yt != null && yf > yt) {
      final t = yf;
      yf = yt;
      yt = t;
    }
    bool acceptYear(String? iso) {
      if (iso == null || iso.isEmpty) return false;
      final y = int.tryParse(iso.split('-').first);
      if (y == null) return false;
      if (yf != null && y < yf) return false;
      if (yt != null && y > yt) return false;
      return true;
    }

    return src.where((m) {
      final okY = (_yearFrom == null && _yearTo == null)
          ? true
          : acceptYear(m.releaseDate);
      final okG = _selectedGenreIds.isEmpty
          ? true
          : (m.genreIds ?? const []).any(
              (id) => _selectedGenreIds.contains(id),
            );
      final okL = _langs.isEmpty
          ? true
          : _langs.contains((m.originalLanguage ?? '').toLowerCase());
      final okC = _countries.isEmpty
          ? true
          : (m.mediaType == 'tv'
                ? ((m.originCountries ?? const [])
                      .map((e) => e.toUpperCase())
                      .toSet()
                      .intersection(
                        _countries.map((e) => e.toUpperCase()).toSet(),
                      )
                      .isNotEmpty)
                : true);
      final okR = (_minRating == null)
          ? true
          : (m.voteAverage ?? 0) >= _minRating!;
      return okY && okG && okL && okC && okR;
    }).toList();
  }

  List<Widget> _popularGenreChips() {
    final ids = <int>[28, 35, 53, 18, 10749, 27, 16, 80, 12, 878, 9648, 10751];
    final chips = <Widget>[];
    final map = {..._movieGenres, ..._tvGenres};
    for (final id in ids) {
      final name = map[id];
      if (name == null) continue;
      chips.add(
        ActionChip(
          label: Text(name),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GenreDiscoverPage(
                  api: _api,
                  genreId: id,
                  genreName: name,
                  mediaType: 'movie',
                ),
              ),
            );
          },
        ),
      );
    }
    return chips;
  }

  void _openDetails(TmdbMovie m) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailsPage(mediaType: m.mediaType, id: m.id),
      ),
    );
  }

  String _firstGenreName(TmdbMovie m) {
    final ids = m.genreIds ?? const [];
    for (final id in ids) {
      final n = _movieGenres[id] ?? _tvGenres[id];
      if (n != null) return n;
    }
    return '';
  }

  // ---------------- Filter glass sheet (GlassSheet) ----------------
  Future<void> _openFilterSheetGlass() async {
    HapticFeedback.lightImpact();

    // temp state
    double? tmpMinRating = _minRating;
    int? tmpFrom = _yearFrom ?? _minYear;
    int? tmpTo = _yearTo ?? _maxYear;
    final tmpGenres = Set<int>.from(_selectedGenreIds);
    bool tmpGenresExpanded = _genresExpanded;
    int tmpScope = _tabCtrl.index; // 0:All,1:Movies,2:TV,3:People
    final tmpLangs = Set<String>.from(_langs);
    final tmpCountries = Set<String>.from(_countries);

    RangeValues tmpYears = RangeValues(
      (tmpFrom).toDouble(),
      (tmpTo).toDouble(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.editSheet(cs);

        Widget ratingChip(
          double? val,
          String label,
          void Function(void Function()) setSB,
        ) {
          final sel = tmpMinRating == val;
          return ChoiceChip(
            label: Text(label),
            selected: sel,
            onSelected: (_) => setSB(() => tmpMinRating = val),
          );
        }

        List<Widget> genreChips(
          bool expanded,
          void Function(void Function()) setSB,
        ) {
          final all = {..._movieGenres, ..._tvGenres}.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));
          final slice = expanded ? all : all.take(10);
          return slice.map((e) {
            final sel = tmpGenres.contains(e.key);
            return FilterChip(
              selected: sel,
              label: Text(e.value),
              onSelected: (_) => setSB(() {
                if (sel) {
                  tmpGenres.remove(e.key);
                } else {
                  tmpGenres.add(e.key);
                }
              }),
            );
          }).toList();
        }

        String labelForLangs(Set<String> codes) {
          if (codes.isEmpty) return 'Any';
          if (codes.length == 1) {
            final code = codes.first;
            final m = _allLangs.firstWhere(
              (l) => l.code == code,
              orElse: () => _Lang(code: code, name: code.toUpperCase()),
            );
            return m.name;
          }
          return '${codes.length} selected';
        }

        String labelForCountries(Set<String> codes) {
          if (codes.isEmpty) return 'Any';
          if (codes.length == 1) {
            final code = codes.first;
            final m = _allCountries.firstWhere(
              (c) => c.code == code,
              orElse: () => _Country(code: code, name: code.toUpperCase()),
            );
            return m.name;
          }
          return '${codes.length} selected';
        }

        return GlassSheet(
          style: style,
          child: StatefulBuilder(
            builder: (ctx2, setSB) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(ctx2).viewInsets.bottom + 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Scope
                      const Text(
                        'Scope',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _ScopeSegmented(
                        index: tmpScope,
                        onChanged: (i) => setSB(() => tmpScope = i),
                      ),

                      const SizedBox(height: 16),

                      // Rating
                      const Text(
                        'Rating',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ratingChip(null, 'Any', setSB),
                          ratingChip(5, '5+', setSB),
                          ratingChip(6, '6+', setSB),
                          ratingChip(7, '7+', setSB),
                          ratingChip(8, '8+', setSB),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Year range
                      const Text(
                        'Year range',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('$_minYear'), Text('$_maxYear')],
                      ),
                      RangeSlider(
                        min: _minYear.toDouble(),
                        max: _maxYear.toDouble(),
                        values: tmpYears,
                        divisions: (_maxYear - _minYear),
                        labels: RangeLabels(
                          tmpYears.start.round().toString(),
                          tmpYears.end.round().toString(),
                        ),
                        onChanged: (v) => setSB(() {
                          tmpYears = v;
                          tmpFrom = v.start.round();
                          tmpTo = v.end.round();
                        }),
                      ),

                      const SizedBox(height: 16),

                      // Languages
                      const Text(
                        'Languages',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(labelForLangs(tmpLangs)),
                        trailing: const Icon(Icons.keyboard_arrow_right),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        onTap: () async {
                          final picked = await _pickLanguagesMulti(
                            ctx2,
                            tmpLangs,
                          );
                          if (picked != null) {
                            setSB(() {
                              tmpLangs
                                ..clear()
                                ..addAll(picked);
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // Countries
                      const Text(
                        'Countries (TV)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(labelForCountries(tmpCountries)),
                        trailing: const Icon(Icons.keyboard_arrow_right),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        onTap: () async {
                          final picked = await _pickCountriesMulti(
                            ctx2,
                            tmpCountries,
                          );
                          if (picked != null) {
                            setSB(() {
                              tmpCountries
                                ..clear()
                                ..addAll(picked);
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Genres
                      Row(
                        children: [
                          const Text(
                            'Genres',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setSB(
                              () => tmpGenresExpanded = !tmpGenresExpanded,
                            ),
                            icon: Icon(
                              tmpGenresExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text(tmpGenresExpanded ? 'Less' : 'All'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: genreChips(tmpGenresExpanded, setSB),
                      ),

                      const SizedBox(height: 14),

                      // Reset / Apply
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              tmpMinRating = null;
                              tmpFrom = _minYear;
                              tmpTo = _maxYear;
                              tmpYears = RangeValues(
                                _minYear.toDouble(),
                                _maxYear.toDouble(),
                              );
                              tmpGenres.clear();
                              tmpGenresExpanded = false;
                              tmpScope = 0;
                              tmpLangs.clear();
                              tmpCountries.clear();
                              setSB(() {}); // refresh UI
                              HapticFeedback.lightImpact();
                            },
                            child: const Text('Reset'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _minRating = tmpMinRating;
                                _yearFrom = tmpFrom;
                                _yearTo = tmpTo;
                                _selectedGenreIds
                                  ..clear()
                                  ..addAll(tmpGenres);
                                _genresExpanded = tmpGenresExpanded;
                                _tabCtrl.animateTo(tmpScope);

                                _langs
                                  ..clear()
                                  ..addAll(tmpLangs);
                                _countries
                                  ..clear()
                                  ..addAll(tmpCountries);

                                _applyFilters();
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<Set<String>?> _pickLanguagesMulti(
    BuildContext ctx,
    Set<String> current,
  ) async {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final glass = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.08,
    );
    final temp = Set<String>.from(current);

    return showModalBottomSheet<Set<String>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: StatefulBuilder(
            builder: (c2, setSB) {
              return Container(
                color: glass,
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Select Languages',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _allLangs.length,
                        itemBuilder: (_, i) {
                          final l = _allLangs[i];
                          final sel = temp.contains(l.code);
                          return CheckboxListTile(
                            value: sel,
                            onChanged: (v) {
                              setSB(() {
                                if (v == true) {
                                  temp.add(l.code);
                                } else {
                                  temp.remove(l.code);
                                }
                              });
                            },
                            title: Text(l.name),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                temp.clear();
                                setSB(() {});
                              },
                              child: const Text('Clear'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop<Set<String>>(temp);
                              },
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<Set<String>?> _pickCountriesMulti(
    BuildContext ctx,
    Set<String> current,
  ) async {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final glass = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.08,
    );
    final temp = Set<String>.from(current);

    return showModalBottomSheet<Set<String>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: StatefulBuilder(
            builder: (c2, setSB) {
              return Container(
                color: glass,
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Select Countries (TV)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _allCountries.length,
                        itemBuilder: (_, i) {
                          final ctry = _allCountries[i];
                          final sel = temp.contains(ctry.code);
                          return CheckboxListTile(
                            value: sel,
                            onChanged: (v) {
                              setSB(() {
                                if (v == true) {
                                  temp.add(ctry.code);
                                } else {
                                  temp.remove(ctry.code);
                                }
                              });
                            },
                            title: Text(ctry.name),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                temp.clear();
                                setSB(() {});
                              },
                              child: const Text('Clear'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop<Set<String>>(temp);
                              },
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------- small widgets ----------------
class _GlassSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onFilter;

  const _GlassSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onFilter,
  });

  @override
  State<_GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<_GlassSearchBar> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
    final showClear = widget.controller.text.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: true,
                  onChanged: (v) {
                    setState(() {});
                    widget.onChanged(v);
                  },
                  onSubmitted: widget.onSubmitted,
                  decoration: const InputDecoration(
                    hintText: 'Search movies, TV, people...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_alt_outlined),
                onPressed: widget.onFilter,
                tooltip: 'Filters',
              ),
              if (showClear)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClear,
                  tooltip: 'Clear',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeSegmented extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _ScopeSegmented({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = const ['All', 'Movies', 'TV', 'People'];
    return LayoutBuilder(
      builder: (ctx, c) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: List.generate(labels.length, (i) {
              final sel = i == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? cs.primary
                            : cs.onSurface, // readable in light
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _InitialSections extends StatelessWidget {
  final List<String> recent;
  final void Function(String) onTapRecent;
  final VoidCallback onTapSeeAll;
  final List<Widget> popularGenres;
  final List<TmdbMovie> trends;
  final List<TmdbMovie> sugs;
  final void Function(TmdbMovie) onOpenDetails;
  final VoidCallback onLoadMoreSugs;
  final bool loadingSug;

  const _InitialSections({
    required this.recent,
    required this.onTapRecent,
    required this.onTapSeeAll,
    required this.popularGenres,
    required this.trends,
    required this.sugs,
    required this.onOpenDetails,
    required this.onLoadMoreSugs,
    required this.loadingSug,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Recent Searches',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recent
                        .map(
                          (q) => ActionChip(
                            label: Text(q),
                            onPressed: () => onTapRecent(q),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

        // Popular Genres (with See all)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Popular Genres',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onTapSeeAll,
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: popularGenres),
          ),
        ),

        // Top searches (Trending)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Top Searches',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: trends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final m = trends[i];
                final url = TmdbService.imageW500(
                  m.posterPath ?? m.backdropPath,
                );
                return _PosterSmall(
                  title: m.title,
                  imageUrl: url,
                  onTap: () => onOpenDetails(m),
                );
              },
            ),
          ),
        ),

        // Suggestions
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Suggestions for you',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                return false;
              },
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sugs.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = sugs[i];
                  final url = TmdbService.imageW500(
                    m.posterPath ?? m.backdropPath,
                  );
                  return _PosterSmall(
                    title: m.title,
                    imageUrl: url,
                    onTap: () => onOpenDetails(m),
                  );
                },
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _InitialSingleType extends StatelessWidget {
  final String title;
  final List<TmdbMovie> items;
  final List<TmdbMovie> sugs;
  final void Function(TmdbMovie) onOpen;
  final VoidCallback onMore;
  final bool loadingMore;

  const _InitialSingleType({
    required this.title,
    required this.items,
    required this.sugs,
    required this.onOpen,
    required this.onMore,
    required this.loadingMore,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final m = items[i];
                final url = TmdbService.imageW500(
                  m.posterPath ?? m.backdropPath,
                );
                return _PosterSmall(
                  title: m.title,
                  imageUrl: url,
                  onTap: () => onOpen(m),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Suggestions for you',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 &&
                    !loadingMore) {
                  onMore();
                }
                return false;
              },
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sugs.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = sugs[i];
                  final url = TmdbService.imageW500(
                    m.posterPath ?? m.backdropPath,
                  );
                  return _PosterSmall(
                    title: m.title,
                    imageUrl: url,
                    onTap: () => onOpen(m),
                  );
                },
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _EmptyWithSugs extends StatelessWidget {
  final List<TmdbMovie> sugs;
  final void Function(TmdbMovie) onOpen;
  final VoidCallback onMore;
  final bool loadingMore;

  const _EmptyWithSugs({
    required this.sugs,
    required this.onOpen,
    required this.onMore,
    required this.loadingMore,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Text(
              'Sorry, no results found.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Suggestions for you',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 &&
                    !loadingMore) {
                  onMore();
                }
                return false;
              },
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sugs.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = sugs[i];
                  final url = TmdbService.imageW500(
                    m.posterPath ?? m.backdropPath,
                  );
                  return _PosterSmall(
                    title: m.title,
                    imageUrl: url,
                    onTap: () => onOpen(m),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PosterSmall extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const _PosterSmall({
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isEmpty
                  ? Container(color: Colors.white10, height: 180)
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      fit: BoxFit.cover,
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
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final TmdbMovie movie;
  final void Function(TmdbMovie) onOpen;
  final String genre;
  const _ResultTile({
    required this.movie,
    required this.onOpen,
    required this.genre,
  });

  @override
  Widget build(BuildContext context) {
    final url = TmdbService.imageW500(movie.posterPath ?? movie.backdropPath);
    final year = (movie.releaseDate ?? '').split('-').first;
    return InkWell(
      onTap: () => onOpen(movie),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: url.isEmpty
                  ? Container(color: Colors.white10, width: 72, height: 108)
                  : CachedNetworkImage(
                      imageUrl: url,
                      width: 72,
                      height: 108,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [year, genre].where((s) => s.isNotEmpty).join(' • '),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if ((movie.voteAverage ?? 0) > 0)
                    Text(
                      'Rating ${movie.voteAverage!.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Models for inline chips
class _Lang {
  final String code;
  final String name;
  _Lang({required this.code, required this.name});
}

class _Country {
  final String code;
  final String name;
  _Country({required this.code, required this.name});
}
