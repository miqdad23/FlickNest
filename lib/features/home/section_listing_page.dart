import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../app/widgets/shimmers.dart';
import '../../core/tmdb/tmdb_models.dart';
import '../../core/tmdb/tmdb_service.dart';
import '../../core/assets/assets.dart';
import '../details/details_page.dart';

class SectionListingPage extends StatefulWidget {
  final String title;
  final Future<List<TmdbMovie>> Function(int page) fetch;
  const SectionListingPage({
    super.key,
    required this.title,
    required this.fetch,
  });

  @override
  State<SectionListingPage> createState() => _SectionListingPageState();
}

class _SectionListingPageState extends State<SectionListingPage> {
  final _scroll = ScrollController();
  final _items = <TmdbMovie>[];
  bool _loading = true, _loadingMore = false;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _page = 1;
    });
    try {
      final data = await widget.fetch(_page);
      _items.addAll(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_scroll.position.extentAfter < 400) _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = await widget.fetch(++_page);
      if (next.isNotEmpty) _items.addAll(next);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
              ElevatedButton(
                onPressed: _loadInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = GridView.builder(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2 / 3,
        ),
        itemCount: _items.length + (_loadingMore ? 3 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) return const _TileSkeleton();
          final m = _items[i];
          final url = TmdbService.imageW500(m.posterPath ?? m.backdropPath);
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(
                context,
              ).push(_zoomRoute(DetailsPage(mediaType: m.mediaType, id: m.id)));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isEmpty
                      ? Image.asset(
                          AppAssets.posterPlaceholder,
                          fit: BoxFit.cover,
                        )
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
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Text(
                      m.title,
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
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          RepaintBoundary(child: body),
          if (_loadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2 / 3,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => const _TileSkeleton(),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ShimmerRect(borderRadius: 12);
  }
}
