// lib/features/home/widgets/quick_preview.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ui/glass_sheet.dart'; // GlassSheet + GlassStyle
import '../../../core/tmdb/tmdb_models.dart';
import '../../../core/tmdb/tmdb_service.dart';
import '../../../core/assets/assets.dart';
import '../../details/details_page.dart';
import '../../lists/models/custom_list.dart';
import '../../lists/models/snap_store.dart';
import '../../lists/models/default_index.dart';

Future<void> showQuickPreview({
  required BuildContext context,
  required TmdbService api,
  required TmdbMovie item,
}) async {
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _QuickPreviewDialog(api: api, item: item),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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

class _QuickPreviewDialog extends StatefulWidget {
  final TmdbService api;
  final TmdbMovie item;
  const _QuickPreviewDialog({required this.api, required this.item});

  @override
  State<_QuickPreviewDialog> createState() => _QuickPreviewDialogState();
}

class _QuickPreviewDialogState extends State<_QuickPreviewDialog> {
  bool _loading = true;
  String _title = '';
  String _overview = '';
  String? _backdrop;
  String? _poster;
  String _year = '';
  String _vote = '';

  bool _fav = false, _watchlist = false, _watched = false;

  String get _baseKey =>
      SnapStore.baseKeyFor(widget.item.mediaType, widget.item.id);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadPrefs();
    if (!mounted) return;
    await _loadDetails();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fav = p.getBool('fav_$_baseKey') ?? false;
      _watchlist = p.getBool('watchlist_$_baseKey') ?? false;
      _watched = p.getBool('watched_$_baseKey') ?? false;
    });
  }

  Future<void> _saveFlag(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('${k}_$_baseKey', v);
  }

  Future<void> _loadDetails() async {
    try {
      final d = (widget.item.mediaType == 'tv')
          ? await widget.api.tvDetails(widget.item.id)
          : await widget.api.movieDetails(widget.item.id);

      if (!mounted) return;

      final t = (d['title'] ?? d['name'] ?? '').toString();
      final o = (d['overview'] ?? '').toString();
      final bd = d['backdrop_path'] as String?;
      final po = d['poster_path'] as String?;
      final y = (d['release_date'] ?? d['first_air_date'] ?? '')
          .toString()
          .split('-')
          .first;
      final v = ((d['vote_average'] ?? 0) as num).toStringAsFixed(1);

      try {
        final snap = SnapStore.fromDetails(widget.item.mediaType, d);
        await SnapStore.save(snap);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _title = t.isNotEmpty ? t : widget.item.title;
        _overview = o;
        _backdrop = bd ?? widget.item.backdropPath;
        _poster = po ?? widget.item.posterPath;
        _year = y;
        _vote = v;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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

  // Index helpers
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Poster target size: ~80% of screen height, 2:3 aspect ratio
    final targetH = size.height * 0.8;
    final maxW = size.width * 0.9;
    final calcW = (2 / 3) * targetH;
    final posterW = math.min(maxW, calcW);
    final posterH = posterW * 3 / 2;

    final img = TmdbService.imageW780(_poster ?? _backdrop);

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color glassBg([double a = 0.12]) =>
        (isDark ? Colors.white : Colors.black).withValues(alpha: a);
    Color borderTint([double a = 0.18]) =>
        (isDark ? Colors.white : Colors.black).withValues(alpha: a);
    Color selBg([double a = 0.18]) => cs.primary.withValues(alpha: a);

    // Capture navigator once for this build scope
    final rootNav = Navigator.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Background blur + dim — বাইরে ট্যাপ করলে ক্লোজ
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => rootNav.pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withValues(alpha: 0.20)),
              ),
            ),
          ),

          // Centered rounded poster with in-card overlay + actions
          Center(
            child: Container(
              width: posterW,
              height: posterH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.45),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // image
                    Builder(
                      builder: (_) {
                        if (img.isEmpty) {
                          return Image.asset(
                            AppAssets.posterPlaceholder,
                            fit: BoxFit.cover,
                          );
                        }
                        return CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Image.asset(
                            AppAssets.posterPlaceholder,
                            fit: BoxFit.cover,
                          ),
                          errorWidget: (_, __, ___) => Image.asset(
                            AppAssets.posterPlaceholder,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),

                    // Bottom gradient overlay inside the poster
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              _title.isNotEmpty ? _title : widget.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Chips + Open Details (right)
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (_year.isNotEmpty) _chip(_year),
                                      _chip(
                                        widget.item.mediaType.toUpperCase(),
                                      ),
                                      _chip('TMDB $_vote'),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    rootNav.pop(); // close preview
                                    Future.microtask(() {
                                      rootNav.push(
                                        _zoomRoute(
                                          DetailsPage(
                                            mediaType: widget.item.mediaType,
                                            id: widget.item.id,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                  child: const Text('Open Details'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 2-line overview
                            if (!_loading)
                              Text(
                                _overview.isNotEmpty
                                    ? _overview
                                    : 'No overview available.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              )
                            else
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: glassBg(0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            const SizedBox(height: 8),

                            // Action buttons row (inside poster, theme-tinted)
                            Container(
                              decoration: BoxDecoration(
                                color: glassBg(0.12),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.30),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: borderTint(0.18)),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  _MiniAction(
                                    active: _fav,
                                    label: 'Favorite',
                                    iconOff: Icons.favorite_border,
                                    iconOn: Icons.favorite,
                                    cs: cs,
                                    glassBg: glassBg,
                                    selBg: selBg,
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      setState(() => _fav = !_fav);
                                      await _saveFlag('fav', _fav);
                                      await _indexUpdateFavorite(_fav);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _MiniAction(
                                    active: _watchlist,
                                    label: 'Watch',
                                    iconOff: Icons.bookmark_border,
                                    iconOn: Icons.bookmark,
                                    cs: cs,
                                    glassBg: glassBg,
                                    selBg: selBg,
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      final next = !_watchlist;
                                      setState(() {
                                        _watchlist = next;
                                        if (next && _watched) _watched = false;
                                      });
                                      await _saveFlag('watchlist', _watchlist);
                                      await _saveFlag('watched', _watched);
                                      await _indexUpdateWatchlist(_watchlist);
                                      if (!_watchlist) {
                                        await _indexUpdateWatched(_watched);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _MiniAction(
                                    active: _watched,
                                    label: 'Watched',
                                    iconOff: Icons.check_circle_outline,
                                    iconOn: Icons.check_circle,
                                    cs: cs,
                                    glassBg: glassBg,
                                    selBg: selBg,
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      final next = !_watched;
                                      setState(() {
                                        _watched = next;
                                        if (next && _watchlist) {
                                          _watchlist = false;
                                        }
                                      });
                                      await _saveFlag('watched', _watched);
                                      await _saveFlag('watchlist', _watchlist);
                                      await _indexUpdateWatched(_watched);
                                      if (!_watched) {
                                        await _indexUpdateWatchlist(_watchlist);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _PillButton(
                                      icon: Icons.playlist_add,
                                      label: 'Add',
                                      cs: cs,
                                      glassBg: glassBg,
                                      borderTint: borderTint,
                                      onTap: _openManageListsSheet,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Text(t, style: const TextStyle(color: Colors.white)),
      );

  Future<void> _openManageListsSheet() async {
    HapticFeedback.lightImpact();

    final allLists = await CustomListStore.loadAll();
    final allowedLists =
        allLists
            .where((l) => l.type == 'both' || l.type == widget.item.mediaType)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final initiallySelected = allowedLists
        .where((l) => l.itemKeys.contains(_baseKey))
        .map((l) => l.id)
        .toSet();

    bool tmpFav = _fav;
    bool tmpWatchlist = _watchlist;
    bool tmpWatched = _watched;
    final tmpCustom = Set<String>.from(initiallySelected);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.editSheet(cs);
        final sheetNav = Navigator.of(ctx);
        final rootMsg = ScaffoldMessenger.maybeOf(
          ctx,
        ); // capture here (sheet ctx)

        return GlassSheet(
          style: style,
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
                  ? const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No custom lists yet.'),
                      ),
                    ]
                  : allowedLists.map((l) {
                      final hasDesc =
                          (l.description != null &&
                              l.description!.trim().isNotEmpty);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.name),
                        subtitle: hasDesc
                            ? Text(
                                l.description!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
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
                      );
                    }).toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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

                    const SizedBox(height: 14),
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

                            // Apply defaults (prefs + index)
                            if (tmpFav != _fav) {
                              _fav = tmpFav;
                              await _saveFlag('fav', _fav);
                              await _indexUpdateFavorite(_fav);
                            }
                            if (tmpWatchlist != _watchlist ||
                                tmpWatched != _watched) {
                              _watchlist = tmpWatchlist;
                              _watched = tmpWatched;
                              await _saveFlag('watchlist', _watchlist);
                              await _saveFlag('watched', _watched);
                              await _indexUpdateWatchlist(_watchlist);
                              await _indexUpdateWatched(_watched);
                            }

                            // Apply custom lists
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
                                l.itemKeys.removeWhere((k) => k == _baseKey);
                                await CustomListStore.save(l);
                              }
                            }

                            if (!sheetNav.mounted) return;
                            sheetNav.pop();

                            // Use sheet's messenger (captured pre-await)
                            rootMsg?.showSnackBar(
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
              );
            },
          ),
        );
      },
    );
  }
}

class _MiniAction extends StatelessWidget {
  final bool active;
  final String label;
  final IconData iconOff;
  final IconData iconOn;
  final ColorScheme cs;
  final Color Function([double]) glassBg;
  final Color Function([double]) selBg;
  final VoidCallback onTap;

  const _MiniAction({
    required this.active,
    required this.label,
    required this.iconOff,
    required this.iconOn,
    required this.cs,
    required this.glassBg,
    required this.selBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? selBg(0.20) : glassBg(0.12);
    final iconColor = active ? cs.primary : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? cs.primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? iconOn : iconOff, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color Function([double]) glassBg;
  final Color Function([double]) borderTint;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.cs,
    required this.glassBg,
    required this.borderTint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        height: 40,
        decoration: BoxDecoration(
          color: glassBg(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderTint(0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}