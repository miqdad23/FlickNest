import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/widgets/shimmers.dart';
import '../../../core/tmdb/tmdb_models.dart';
import '../../../core/tmdb/tmdb_service.dart';
import '../../../core/assets/assets.dart';

class HeroCarousel extends StatefulWidget {
  final double height;
  final List<TmdbMovie> items;
  final void Function(TmdbMovie)? onItemTap;
  const HeroCarousel({
    super.key,
    this.height = 220,
    required this.items,
    this.onItemTap,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final PageController _ctrl = PageController(viewportFraction: 0.88);

  int _visibleIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || widget.items.isEmpty) return;
        final next = (_visibleIndex + 1) % widget.items.length;
        _ctrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.items.length;
    if (len == 0) return _placeholder(height: widget.height);

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: len,
            onPageChanged: (i) => setState(() => _visibleIndex = i),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, i) {
              final m = widget.items[i];
              final url = TmdbService.imageW780(m.backdropPath ?? m.posterPath);
              return GestureDetector(
                onTap: () => widget.onItemTap?.call(m),
                child: _HeroCard(
                  key: ValueKey('hero_${m.mediaType}_${m.id}_$i'),
                  title: m.title,
                  imageUrl: url,
                ),
              );
            },
          ),
          Positioned(
            bottom: 8,
            child: Row(
              children: List.generate(len, (i) {
                final active = i == _visibleIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: active ? 16 : 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder({double height = 220}) {
    return SizedBox(height: height, child: const ShimmerRect(borderRadius: 16));
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  const _HeroCard({super.key, required this.title, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.35),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 250),
                        placeholder: (_, __) => Image.asset(
                          AppAssets.posterPlaceholder,
                          fit: BoxFit.cover,
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          AppAssets.posterPlaceholder,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        AppAssets.posterPlaceholder,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
      ),
    );
  }
}