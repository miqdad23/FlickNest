import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/tmdb/tmdb_service.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<String> filePaths;
  final int initialIndex;
  final String title;
  const PhotoViewerPage({
    super.key,
    required this.filePaths,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pc = PageController(
    initialPage: widget.initialIndex,
  );
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${widget.title} (${_index + 1}/${widget.filePaths.length})',
        ),
      ),
      body: PageView.builder(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: widget.filePaths.length,
        itemBuilder: (_, i) {
          final url = TmdbService.imageOriginal(widget.filePaths[i]);
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}