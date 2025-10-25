// lib/features/search/genre_discover_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../app/widgets/shimmers.dart';
import '../../core/assets/assets.dart';
import '../../core/tmdb/tmdb_service.dart';
import '../../core/tmdb/tmdb_models.dart';
import '../details/details_page.dart';

class GenreDiscoverPage extends StatefulWidget {
  final TmdbService api;
  final int? genreId;
  final String? genreName;
  final String mediaType; // 'movie' | 'tv'
  const GenreDiscoverPage({
    super.key,
    required this.api,
    this.genreId,
    this.genreName,
    this.mediaType = 'movie',
  });

  @override
  State<GenreDiscoverPage> createState() => _GenreDiscoverPageState();
}

class _GenreDiscoverPageState extends State<GenreDiscoverPage> {
  final _items = <TmdbMovie>[];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  final _scroll = ScrollController();

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
      final data = await _discover(page: _page);
      _items.addAll(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<TmdbMovie>> _discover({required int page}) {
    final params = {'with_genres': widget.genreId?.toString() ?? ''};
    if (widget.mediaType == 'tv') {
      return widget.api.discoverTv(params, page: page);
    }
    return widget.api.discoverMovies(params, page: page);
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_scroll.position.extentAfter < 400) _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = await _discover(page: ++_page);
      if (next.isNotEmpty) _items.addAll(next);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        physics: const BouncingScrollPhysics(),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailsPage(mediaType: m.mediaType, id: m.id),
                ),
              );
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
      appBar: AppBar(title: Text(widget.genreName ?? 'Discover by Genre')),
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
