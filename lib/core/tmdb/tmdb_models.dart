class TmdbMovie {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final String mediaType; // 'movie' | 'tv'

  // New optional fields (for search/filter/sort)
  final double? voteAverage;
  final double? popularity;
  final List<int>? genreIds; // search results: genre_ids
  final String? originalLanguage; // original_language
  final List<String>? originCountries; // tv only: origin_country

  TmdbMovie({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.mediaType = 'movie',
    this.voteAverage,
    this.popularity,
    this.genreIds,
    this.originalLanguage,
    this.originCountries,
  });

  factory TmdbMovie.fromJson(
    Map<String, dynamic> j, {
    String? forcedMediaType,
  }) {
    final mt = forcedMediaType ?? (j['media_type'] as String?) ?? 'movie';
    final title = (j['title'] ?? j['name'] ?? '').toString();

    // genre_ids could be List<dynamic> of numbers
    List<int>? gids;
    final gi = j['genre_ids'];
    if (gi is List) {
      gids = gi
          .map((e) {
            if (e is int) return e;
            return int.tryParse('$e') ?? -1;
          })
          .where((x) => x >= 0)
          .toList();
    }

    List<String>? oc;
    final ocv = j['origin_country'];
    if (ocv is List) {
      oc = ocv.map((e) => e.toString()).toList();
    }

    return TmdbMovie(
      id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      title: title,
      posterPath: j['poster_path'] as String?,
      backdropPath: j['backdrop_path'] as String?,
      releaseDate: (j['release_date'] ?? j['first_air_date']) as String?,
      mediaType: mt,
      voteAverage: (j['vote_average'] is num)
          ? (j['vote_average'] as num).toDouble()
          : null,
      popularity: (j['popularity'] is num)
          ? (j['popularity'] as num).toDouble()
          : null,
      genreIds: gids,
      originalLanguage: (j['original_language']?.toString()),
      originCountries: oc,
    );
  }
}
