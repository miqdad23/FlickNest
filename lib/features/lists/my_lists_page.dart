// lib/features/lists/my_lists_page.dart
// Offline-only, GlassSheet + Glass Cards, light/dark readable text,
// custom list row shows items/type + 1-line description (ellipsis)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/navigation/route_observer.dart';
import '../../ui/glass_sheet.dart'; // GlassSheet + GlassStyle
import 'list_grid_page.dart';
import 'models/custom_list.dart';
import 'models/default_index.dart';

class MyListsPage extends StatefulWidget {
  const MyListsPage({super.key});

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> with RouteAware {
  int _favCount = 0, _watchlistCount = 0, _watchedCount = 0;
  List<CustomList> _custom = [];
  String? _showActionsFor;
  bool _loading = true;
  String? _error;

  // Folder color palette (for create/edit sheet)
  static const List<Color> _folderSwatches = [
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF9333EA),
    Color(0xFFDB2777),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFFFBBF24),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFF14B8A6),
    Color(0xFF0EA5E9),
    Color(0xFF64748B),
  ];

  static const List<IconData> _iconOptions = [
    Icons.folder_rounded,
    Icons.movie_creation_rounded,
    Icons.tv_rounded,
    Icons.favorite_rounded,
    Icons.bookmark_rounded,
    Icons.play_circle_rounded,
    Icons.star_rounded,
    Icons.collections_bookmark_rounded,
    Icons.theaters_rounded,
    Icons.live_tv_rounded,
    Icons.video_library_rounded,
    Icons.library_music_rounded,
  ];

  int _colorToInt(Color c) {
    final a = ((c.a * 255.0).round() & 0xff);
    final r = ((c.r * 255.0).round() & 0xff);
    final g = ((c.g * 255.0).round() & 0xff);
    final b = ((c.b * 255.0).round() & 0xff);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  // About-style helpers (glassy card)
  Color _glass(BuildContext ctx, [double a = 0.08]) =>
      (Theme.of(ctx).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: a);
  Color _border(BuildContext ctx, [double a = 0.12]) =>
      (Theme.of(ctx).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: a);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadAll();
    super.didPopNext();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final counts = await _loadCountsSafe();
      final lists = await _loadCustomListsSafe();
      if (!mounted) return;
      setState(() {
        _favCount = counts.fav;
        _watchlistCount = counts.wl;
        _watchedCount = counts.wd;
        _custom = lists;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load lists. Please try again.\n$e';
        _custom = const [];
        _favCount = _watchlistCount = _watchedCount = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_Counts> _loadCountsSafe() async {
    try {
      final favIdx = await DefaultIndexStore.all(
        DefaultIndexStore.favIndex,
      ).timeout(const Duration(seconds: 2), onTimeout: () => <String>[]);
      final wlIdx = await DefaultIndexStore.all(
        DefaultIndexStore.watchlistIndex,
      ).timeout(const Duration(seconds: 2), onTimeout: () => <String>[]);
      final wdIdx = await DefaultIndexStore.all(
        DefaultIndexStore.watchedIndex,
      ).timeout(const Duration(seconds: 2), onTimeout: () => <String>[]);
      var fav = favIdx.length;
      var wl = wlIdx.length;
      var wd = wdIdx.length;

      if (fav + wl + wd == 0) {
        final p = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 2),
        );
        final keys = p.getKeys();
        for (final k in keys) {
          if (k.endsWith('_index')) continue;
          final v = p.get(k);
          if (v is bool && v == true && k.startsWith('fav_')) fav++;
          if (v is bool && v == true && k.startsWith('watchlist_')) wl++;
          if (v is bool && v == true && k.startsWith('watched_')) wd++;
        }
      }
      return _Counts(fav, wl, wd);
    } catch (_) {
      return const _Counts(0, 0, 0);
    }
  }

  Future<List<CustomList>> _loadCustomListsSafe() async {
    try {
      final lists = await CustomListStore.loadAll().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <CustomList>[],
      );
      return lists;
    } catch (_) {
      return <CustomList>[];
    }
  }

  // ---------------- Create (GlassSheet) ----------------
  Future<void> _openCreateSheet() async {
    HapticFeedback.lightImpact();

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'both';
    int selectedColor = _colorToInt(Theme.of(context).colorScheme.primary);
    int selectedIcon = _iconOptions.first.codePoint;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.strong3D(cs);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: StatefulBuilder(
            builder: (ctx2, setSB) {
              return GlassSheet(
                style: style,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      const Text(
                        'Create New List',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'List Name',
                        ),
                      ),
                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue:
                            type, // FIX: deprec. 'value' → 'initialValue'
                        decoration: const InputDecoration(
                          labelText: 'List Type',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'both', child: Text('Both')),
                          DropdownMenuItem(
                            value: 'movie',
                            child: Text('Movie only'),
                          ),
                          DropdownMenuItem(value: 'tv', child: Text('TV only')),
                        ],
                        onChanged: (v) => setSB(() => type = v ?? 'both'),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Folder Color',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _ColorPickerRow(
                        colors: _folderSwatches,
                        selected: selectedColor,
                        onPick: (c) => setSB(() => selectedColor = c),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Folder Icon',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _IconPickerGrid(
                        options: _iconOptions,
                        selectedCode: selectedIcon,
                        onPick: (code) => setSB(() => selectedIcon = code),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;

                              final list = CustomList.newList(
                                name: name,
                                type: type,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                color: selectedColor,
                                icon: selectedIcon,
                              );

                              await CustomListStore.save(list);

                              // Close the sheet safely (use sheet ctx)
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              // Refresh the page state
                              await _loadAll();

                              // Show snackbar using State.context, guarded by State.mounted
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('List created')),
                              );
                            },
                            child: const Text('Create'),
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

  // ---------------- Edit (GlassSheet) ----------------
  Future<void> _openEditSheet(CustomList list) async {
    HapticFeedback.lightImpact();

    final nameCtrl = TextEditingController(text: list.name);
    final descCtrl = TextEditingController(text: list.description ?? '');
    int tmpColor = list.color;
    int tmpIcon = list.icon;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final style = GlassStyle.strong3D(cs);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: StatefulBuilder(
            builder: (ctx2, setSB) {
              return GlassSheet(
                style: style,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      const Text(
                        'Edit List',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'List Name',
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Text('Type: '),
                          const SizedBox(width: 6),
                          Chip(label: Text(list.type.toUpperCase())),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              '(Type cannot be changed)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Folder Color',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _ColorPickerRow(
                        colors: _folderSwatches,
                        selected: tmpColor,
                        onPick: (c) => setSB(() => tmpColor = c),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Folder Icon',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _IconPickerGrid(
                        options: _iconOptions,
                        selectedCode: tmpIcon,
                        onPick: (code) => setSB(() => tmpIcon = code),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;

                              list.name = name;
                              list.description = descCtrl.text.trim().isEmpty
                                  ? null
                                  : descCtrl.text.trim();
                              list.color = tmpColor;
                              list.icon = tmpIcon;

                              await CustomListStore.save(list);

                              // Close the sheet safely
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              // Refresh
                              await _loadAll();

                              // Snackbar guarded by State.mounted
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('List updated')),
                              );
                            },
                            child: const Text('Save'),
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

  Future<void> _confirmDelete(CustomList list) async {
    HapticFeedback.heavyImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text(
          'Are you sure you want to delete "${list.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CustomListStore.delete(list.id);
      await _loadAll();
      if (!mounted) return;
      _showActionsFor = null;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('List deleted')));
    }
  }

  Route _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        final offset = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved);
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<void> _openDefault(String title, String prefix) async {
    HapticFeedback.lightImpact();
    await Navigator.of(
      context,
    ).push(_slideRoute(ListGridPage.defaultList(title: title, prefix: prefix)));
    if (mounted) await _loadAll();
  }

  Future<void> _openCustom(CustomList list) async {
    HapticFeedback.lightImpact();
    await Navigator.of(
      context,
    ).push(_slideRoute(ListGridPage.customList(list: list)));
    if (mounted) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Lists',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ), // bigger + bold
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Lists',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: _showActionsFor == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showActionsFor != null) {
          setState(() => _showActionsFor = null);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Lists',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_showActionsFor != null) {
              setState(() => _showActionsFor = null);
            }
          },
          child: RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await _loadAll();
            },
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ---------- Default lists in a glassy card ----------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 0,
                    color: _glass(context, 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _border(context, 0.12)),
                    ),
                    child: Column(
                      children: [
                        _Tile(
                          icon: Icons.favorite,
                          color: Colors.pinkAccent,
                          title: 'Favorites',
                          subtitle: '$_favCount Items',
                          onTap: () => _openDefault('Favorites', 'fav_'),
                        ),
                        const Divider(height: 1),
                        _Tile(
                          icon: Icons.bookmark,
                          color: Colors.amber,
                          title: 'Watchlist',
                          subtitle: '$_watchlistCount Items',
                          onTap: () => _openDefault('Watchlist', 'watchlist_'),
                        ),
                        const Divider(height: 1),
                        _Tile(
                          icon: Icons.check_circle,
                          color: Colors.greenAccent,
                          title: 'Watched',
                          subtitle: '$_watchedCount Items',
                          onTap: () => _openDefault('Watched', 'watched_'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ---------- Your Lists header ----------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Your Lists', style: t.titleMedium),
                ),
                const SizedBox(height: 6),

                // ---------- Your Lists glassy card ----------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 0,
                    color: _glass(context, 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _border(context, 0.12)),
                    ),
                    child: _custom.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Text(
                              'No custom lists yet. Tap + to create one.',
                            ),
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < _custom.length; i++) ...[
                                _CustomListRow(
                                  list: _custom[i],
                                  actionsVisible:
                                      _showActionsFor == _custom[i].id,
                                  onTap: () {
                                    final actionsVisible =
                                        _showActionsFor == _custom[i].id;
                                    if (actionsVisible) {
                                      setState(() => _showActionsFor = null);
                                      return;
                                    }
                                    _openCustom(_custom[i]);
                                  },
                                  onLongPress: () => setState(
                                    () => _showActionsFor =
                                        (_showActionsFor == _custom[i].id)
                                        ? null
                                        : _custom[i].id,
                                  ),
                                  onEdit: () => _openEditSheet(_custom[i]),
                                  onDelete: () => _confirmDelete(_custom[i]),
                                ),
                                if (i != _custom.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 48, right: 36),
          child: FloatingActionButton(
            heroTag: 'fab_my_lists',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: _openCreateSheet,
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }
}

// ---------- Custom row inside glass card ----------
class _CustomListRow extends StatelessWidget {
  final CustomList list;
  final bool actionsVisible;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomListRow({
    required this.list,
    required this.actionsVisible,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  // Map saved codePoint -> a constant IconData from the allowed options
  IconData _iconFromCode(int code) {
    // use the constant list from state; no IconData constructor call here
    for (final ic in _MyListsPageState._iconOptions) {
      if (ic.codePoint == code && ic.fontFamily == 'MaterialIcons') {
        return ic;
      }
    }
    return Icons.folder_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(list.color);
    final cs = Theme.of(context).colorScheme;
    final sub = cs.onSurface.withValues(alpha: 0.72);
    final descColor = cs.onSurface.withValues(alpha: 0.65);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.55)),
              ),
              alignment: Alignment.center,
              child: Icon(
                _iconFromCode(list.icon), // FIX: no dynamic IconData()
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${list.itemKeys.length} Items • ${list.type.toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                  if ((list.description?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      list.description!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: descColor),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: actionsVisible
                  ? Row(
                      key: ValueKey('on_${list.id}'),
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(key: ValueKey('off'), width: 0, height: 0),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Small widgets ----------
class _ColorPickerRow extends StatefulWidget {
  final List<Color> colors;
  final int selected;
  final ValueChanged<int> onPick;
  const _ColorPickerRow({
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  State<_ColorPickerRow> createState() => _ColorPickerRowState();
}

class _ColorPickerRowState extends State<_ColorPickerRow> {
  late int _sel = widget.selected;

  int _intOf(Color c) {
    final a = ((c.a * 255.0).round() & 0xff);
    final r = ((c.r * 255.0).round() & 0xff);
    final g = ((c.g * 255.0).round() & 0xff);
    final b = ((c.b * 255.0).round() & 0xff);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: widget.colors.map((c) {
        final ci = _intOf(c);
        final sel = _sel == ci;
        return GestureDetector(
          onTap: () {
            setState(() => _sel = ci);
            widget.onPick(ci);
            HapticFeedback.selectionClick();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (sel) const Icon(Icons.check, color: Colors.white, size: 18),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _IconPickerGrid extends StatefulWidget {
  final List<IconData> options;
  final int selectedCode;
  final ValueChanged<int> onPick;
  const _IconPickerGrid({
    required this.options,
    required this.selectedCode,
    required this.onPick,
  });

  @override
  State<_IconPickerGrid> createState() => _IconPickerGridState();
}

class _IconPickerGridState extends State<_IconPickerGrid> {
  late int _sel = widget.selectedCode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgSel = cs.primary.withValues(alpha: 0.18);
    final borderSel = cs.primary;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: widget.options.map((ic) {
        final code = ic.codePoint;
        final sel = _sel == code;
        final bg = sel ? bgSel : Colors.transparent;
        final br = sel ? borderSel : Colors.white24;
        return GestureDetector(
          onTap: () {
            setState(() => _sel = code);
            widget.onPick(code);
            HapticFeedback.selectionClick();
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: br),
            ),
            child: Icon(ic),
          ),
        );
      }).toList(),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}

class _Counts {
  final int fav, wl, wd;
  const _Counts(this.fav, this.wl, this.wd);
}
