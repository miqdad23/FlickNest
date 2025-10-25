import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tmdb/tmdb_service.dart';
import 'genre_discover_page.dart';

class AllGenresPage extends StatefulWidget {
  final TmdbService api;
  const AllGenresPage({super.key, required this.api});

  @override
  State<AllGenresPage> createState() => _AllGenresPageState();
}

class _AllGenresPageState extends State<AllGenresPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 2,
    vsync: this,
  ); // Movies, TV
  List<_Genre> _movie = [];
  List<_Genre> _tv = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _movie.clear();
      _tv.clear();
    });
    try {
      final gm = await widget.api.genreListMovie();
      final gt = await widget.api.genreListTv();
      _movie =
          gm
              .map((e) => _Genre(e['id'] as int, (e['name'] ?? '').toString()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      _tv =
          gt
              .map((e) => _Genre(e['id'] as int, (e['name'] ?? '').toString()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          TabBar(
            controller: _tab,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Movies'),
              Tab(text: 'TV Shows'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _grid(context, _movie, mediaType: 'movie'),
                _grid(context, _tv, mediaType: 'tv'),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Genres')),
      body: body,
    );
  }

  Widget _grid(
    BuildContext context,
    List<_Genre> data, {
    required String mediaType,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.2,
      ),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final g = data[i];
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GenreDiscoverPage(
                  api: widget.api,
                  genreId: g.id,
                  genreName: g.name,
                  mediaType: mediaType,
                ),
              ),
            );
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              g.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _Genre {
  final int id;
  final String name;
  _Genre(this.id, this.name);
}
