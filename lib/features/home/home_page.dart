// lib/features/home/home_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/widgets/shimmers.dart';
import '../../app/widgets/gradient_text.dart';
import '../settings/settings_page.dart';
import '../details/details_page.dart';
import '../notifications/notifications_page.dart';
import '../../core/tmdb/tmdb_models.dart';
import '../../core/tmdb/tmdb_service.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/section_row.dart';
import 'section_listing_page.dart';
import 'widgets/quick_preview.dart';
import '../lists/my_lists_page.dart';
import '../search/search_page.dart';

class HomePage extends StatefulWidget {
  final ThemeController themeCtrl;
  const HomePage({super.key, required this.themeCtrl});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();
  int _tab = 0;

  // Keep pages alive across tab switches
  final GlobalKey<SearchPageState> _searchKey = GlobalKey<SearchPageState>();
  late final Widget _pageSearch = SearchPage(key: _searchKey);
  late final Widget _pageLists = const MyListsPage();
  late final Widget _pageSettings = SettingsPage(themeCtrl: widget.themeCtrl);

  final _api = TmdbService();
  List<TmdbMovie> _hero = [];
  final List<_SectionData> _sections = [];
  late final List<_SectionPlan> _plan = _buildPlan();
  int _planIndex = 0;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _error;

  // notifications
  bool _hasUnread = false;

  // How many sections to preload on first load
  static const int _initialSectionCount = 6;

  final Map<String, int> _pageByKey = {};
  int _nextPageFor(String key) {
    final next = (_pageByKey[key] ?? 0) + 1;
    _pageByKey[key] = next;
    return next;
  }

  // Predictive back (PopScope) helper
  bool get _canSystemPop {
    if (_tab != 0) return false; // অন্য ট্যাবে থাকলে আগে Home-এ যাক
    if (_scroll.hasClients && _scroll.position.pixels > 80) return false; // স্ক্রলে থাকলে আমরা হ্যান্ডেল করব
    return true; // টপে থাকলে সিস্টেমকে পপ করতে দাও (exit)
  }

  @override
  void initState() {
    super.initState();
    _initLoad();
    _loadNotifState();
    _scroll.addListener(_onScroll);
  }

  Future<void> _loadNotifState() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hasUnread = p.getBool('has_unread_notifications') ?? false);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  List<_SectionPlan> _buildPlan() => [
        _SectionPlan(
          'Top Rated Movies',
          'top_rated_movies',
          (p) => _api.topRatedMovies(page: p),
        ),
        _SectionPlan(
          'Trending TV Today',
          'trending_tv',
          (p) => _api.trendingTv(page: p),
        ),
        _SectionPlan('Popular in Action', 'popular_action', (p) {
          return _api.discoverMovies({
            'with_genres': '28',
            'sort_by': 'popularity.desc',
          }, page: p);
        }),
        _SectionPlan(
          'Upcoming Movies',
          'upcoming_movies_strict',
          (p) => _api.upcomingStrictMovies(page: p),
        ),
        _SectionPlan('Upcoming TV', 'upcoming_tv', (p) => _api.upcomingTv(page: p)),
        _SectionPlan(
          'Trending Movies',
          'trending_movies',
          (p) => _api.trendingMovies(page: p),
        ),
        _SectionPlan(
          'Popular Movies',
          'popular_movies',
          (p) => _api.popularMovies(page: p),
        ),
        _SectionPlan(
          'Hollywood Now',
          'us_origin',
          (p) => _api.discoverMovies({'with_origin_country': 'US'}, page: p),
        ),
        _SectionPlan('Korean Thrillers', 'kr_thriller', (p) {
          return _api.discoverMovies({
            'with_original_language': 'ko',
            'with_genres': '53',
          }, page: p);
        }),
        _SectionPlan('Bangla Drama', 'bn_drama', (p) {
          return _api.discoverMovies({
            'with_original_language': 'bn',
            'with_genres': '18',
          }, page: p);
        }),
        _SectionPlan('Hindi Popular', 'hi_popular', (p) {
          return _api.discoverMovies({
            'with_original_language': 'hi',
            'sort_by': 'popularity.desc',
          }, page: p);
        }),
        _SectionPlan('Sci‑Fi Trending', 'scifi_trending', (p) {
          return _api.discoverMovies({
            'with_genres': '878',
            'sort_by': 'popularity.desc',
          }, page: p);
        }),
      ];

  Future<void> _initLoad() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
      _hero = [];
      _sections.clear();
      _planIndex = 0;
      _pageByKey.clear();
    });
    try {
      _hero = await _api.trendingMovies(page: 1);
      // Preload more sections up-front so user sees content without scrolling
      await _loadMoreSections(count: _initialSectionCount);
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  void _onScroll() {
    if (_loadingMore || _loadingInitial) return;
    if (_scroll.position.extentAfter < 800) _loadMoreSections(count: 2);
  }

  Future<void> _loadMoreSections({int count = 1}) async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      for (int k = 0; k < count; k++) {
        final plan = _plan[_planIndex % _plan.length];
        _planIndex++;
        final page = _nextPageFor(plan.key);
        final items = await plan.fetch(page);
        if (items.isNotEmpty) {
          _sections.add(_SectionData(plan.title, items, plan.fetch));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _scrollTopAndRefresh() async {
    HapticFeedback.lightImpact();
    await _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    await _initLoad();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshed'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _showQuickPreview(TmdbMovie m) async {
    await showQuickPreview(context: context, api: _api, item: m);
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

  SliverAppBar _glassAppBar() {
    // Dynamic gradient from current brand (redesigned)
    final grad = AppTheme.titleGradientFrom(widget.themeCtrl.brandPrimary);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return SliverAppBar(
      systemOverlayStyle: overlay,
      floating: true,
      snap: true,
      pinned: false,
      toolbarHeight: 60,
      titleSpacing: 8,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: const Color.fromRGBO(255, 255, 255, 0.06)),
        ),
      ),
      title: GestureDetector(
        onTap: _scrollTopAndRefresh,
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: GradientText(
            'FlickNest',
            gradient: grad,
            style: GoogleFonts.quicksand(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () async {
                HapticFeedback.lightImpact();
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
                if (changed == true) {
                  final p = await SharedPreferences.getInstance();
                  await p.setBool('has_unread_notifications', false);
                  if (mounted) setState(() => _hasUnread = false);
                }
              },
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if (_hasUnread)
              Positioned(
                right: 10,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildHomeScroll() {
    final heroItems = _hero.take(7).toList();

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        _glassAppBar(),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: HeroCarousel(
              height: 220,
              items: heroItems,
              onItemTap: (m) {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  _zoomRoute(DetailsPage(mediaType: m.mediaType, id: m.id)),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        if (_error != null)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initLoad,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: _sections.length,
          itemBuilder: (_, i) {
            final s = _sections[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionRow(
                key: ValueKey('section_${s.title}_$i'),
                title: s.title,
                onSeeMore: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SectionListingPage(title: s.title, fetch: s.fetch),
                    ),
                  );
                },
                items: s.items,
                onItemTap: (m) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    _zoomRoute(DetailsPage(mediaType: m.mediaType, id: m.id)),
                  );
                },
                onItemLongPress: (m) => _showQuickPreview(m),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _homeTab(BuildContext context) {
    if (_loadingInitial) return const _InitialSkeleton();

    // Pull-to-refresh → Material RefreshIndicator (My Lists-এর মতো)
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: Theme.of(context).cardColor,
      strokeWidth: 2.6,
      onRefresh: _initLoad,
      child: _buildHomeScroll(),
    );
  }

  Future<bool> handleBack() async {
    // If not on Home tab, go back to Home
    if (_tab != 0) {
      setState(() => _tab = 0);
      return false;
    }
    // On Home: if scrolled down, refresh; otherwise exit app
    if (_scroll.hasClients && _scroll.position.pixels > 80) {
      await _scrollTopAndRefresh();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // আরও floating গ্যাপ: Safe area bottom-এর উপর ভিত্তি করে ডাইনামিক
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navFloat = 20.0 + (bottomInset > 0 ? bottomInset * 0.45 : 0.0);

    final pages = <Widget>[
      _homeTab(context),
      _pageSearch,
      _pageLists,
      _pageSettings,
    ];

    return PopScope(
      canPop: _canSystemPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // system already popped
        if (_tab != 0) {
          setState(() => _tab = 0);
          return;
        }
        if (_scroll.hasClients && _scroll.position.pixels > 80) {
          await _scrollTopAndRefresh();
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, navFloat),
          child: _GlassCustomNavBar(
            currentIndex: _tab,
            onTap: (i) {
              HapticFeedback.lightImpact();
              if (i == _tab) {
                if (i == 0) _scrollTopAndRefresh();
              } else {
                final prev = _tab;
                setState(() => _tab = i);
                // Search ট্যাব থেকে অন্য ট্যাবে গেলে Search রিসেট
                if (prev == 1 && i != 1) {
                  _searchKey.currentState?.resetToDefault();
                }
              }
            },
          ),
        ),
      ),
    );
  }
}

// ---------- bottom glass nav (thinner) ----------
class _GlassCustomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _GlassCustomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.06)
        : const Color.fromRGBO(0, 0, 0, 0.06);
    final border = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.12)
        : const Color.fromRGBO(0, 0, 0, 0.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 76, // thinner
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
                spreadRadius: 1.5,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                selected: currentIndex == 0,
                onTap: onTap,
                iconSel: cs.primary,
                iconUnsel: isDark ? Colors.white70 : Colors.black87,
              ),
              _NavItem(
                index: 1,
                label: 'Search',
                icon: Icons.search_outlined,
                selectedIcon: Icons.search,
                selected: currentIndex == 1,
                onTap: onTap,
                iconSel: cs.primary,
                iconUnsel: isDark ? Colors.white70 : Colors.black87,
              ),
              _NavItem(
                index: 2,
                label: 'My Lists',
                icon: Icons.collections_bookmark_outlined,
                selectedIcon: Icons.collections_bookmark,
                selected: currentIndex == 2,
                onTap: onTap,
                iconSel: cs.primary,
                iconUnsel: isDark ? Colors.white70 : Colors.black87,
              ),
              _NavItem(
                index: 3,
                label: 'Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                selected: currentIndex == 3,
                onTap: onTap,
                iconSel: cs.primary,
                iconUnsel: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final ValueChanged<int> onTap;
  final Color iconSel;
  final Color iconUnsel;

  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    required this.iconSel,
    required this.iconUnsel,
  });

  @override
  Widget build(BuildContext context) {
    final selBg = iconSel.withValues(alpha: 0.20);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70, // narrower
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 40, // smaller
              height: 40,
              decoration: BoxDecoration(
                color: selected ? selBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? iconSel : iconUnsel,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? iconSel : iconUnsel,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10, // smaller label
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- skeletons ----------
class _SectionData {
  final String title;
  final List<TmdbMovie> items;
  final Future<List<TmdbMovie>> Function(int page) fetch;
  _SectionData(this.title, this.items, this.fetch);
}

class _SectionPlan {
  final String title;
  final String key;
  final Future<List<TmdbMovie>> Function(int page) fetch;
  _SectionPlan(this.title, this.key, this.fetch);
}

class _InitialSkeleton extends StatelessWidget {
  const _InitialSkeleton();
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: const [
        SliverToBoxAdapter(child: SizedBox(height: 60)),
        SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _HeroSkeleton(),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 18)),
        SliverToBoxAdapter(child: _SectionSkeleton()),
        SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: _SectionSkeleton()),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return const ShimmerRect(height: 220, borderRadius: 16);
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLine(width: 160, height: 20, borderRadius: 6),
          const SizedBox(height: 8),
          SizedBox(
            height: 236,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => const AspectRatio(
                aspectRatio: 2 / 3,
                child: ShimmerRect(borderRadius: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}