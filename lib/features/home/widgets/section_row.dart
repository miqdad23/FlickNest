import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/tmdb/tmdb_models.dart';
import '../../../core/tmdb/tmdb_service.dart';
import '../../../core/assets/assets.dart';

class SectionRow extends StatelessWidget {
  final String title;
  final VoidCallback onSeeMore;
  final List<TmdbMovie> items;
  final void Function(TmdbMovie)? onItemTap;
  final void Function(TmdbMovie)? onItemLongPress;

  const SectionRow({
    super.key,
    required this.title,
    required this.onSeeMore,
    required this.items,
    this.onItemTap,
    this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLarge,
                ),
              ),
              TextButton(onPressed: onSeeMore, child: const Text('See More')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 236,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PosterCard(
                key: ValueKey(
                  'poster_${title}_${items[i].mediaType}_${items[i].id}_$i',
                ),
                item: items[i],
                onTap: onItemTap,
                onLongPress: onItemLongPress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final TmdbMovie item;
  final void Function(TmdbMovie)? onTap;
  final void Function(TmdbMovie)? onLongPress;
  const _PosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final url = TmdbService.imageW500(item.posterPath ?? item.backdropPath);
    return GestureDetector(
      onTap: () => onTap?.call(item),
      onLongPress: () => onLongPress?.call(item),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.30),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: url.isEmpty
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
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
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
