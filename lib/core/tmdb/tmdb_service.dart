import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'tmdb_models.dart';

class TmdbService {
  final Dio _dio;
  final String _key;
  final String language; // e.g. en-US
  final String region; // e.g. US

  // retry config
  final int _maxRetries = 2;
  final Duration _retryBaseDelay = const Duration(milliseconds: 400);

  // Short ISO-639-1 code from language (e.g. en)
  String get _langShort {
    final l = language.trim();
    if (l.isEmpty) return 'en';
    final dash = l.indexOf('-');
    return (dash > 0 ? l.substring(0, dash) : l).toLowerCase();
  }

  TmdbService()
    : _key =
          (dotenv.env['TMDB_KEY'] ?? const String.fromEnvironment('TMDB_KEY'))
              .trim(),
      language = (dotenv.env['TMDB_LANG'] ?? 'en-US').trim(),
      region = (dotenv.env['TMDB_REGION'] ?? 'US').trim(),
      _dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.themoviedb.org/3',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 15),
        ),
      ) {
    if (kDebugMode) {
      _dio.interceptors.add(_SafeLogInterceptor());
    }
  }

  // ---------- Image helpers ----------
  static String imageW500(String? path) => (path == null || path.isEmpty)
      ? ''
      : 'https://image.tmdb.org/t/p/w500$path';
  static String imageW780(String? path) => (path == null || path.isEmpty)
      ? ''
      : 'https://image.tmdb.org/t/p/w780$path';
  static String imageOriginal(String? path) => (path == null || path.isEmpty)
      ? ''
      : 'https://image.tmdb.org/t/p/original$path';

  // ---------- Lists ----------
  Future<List<TmdbMovie>> trendingMovies({int page = 1}) async {
    try {
      return await _getList(
        '/trending/movie/day',
        params: {'page': page},
        forcedType: 'movie',
      );
    } catch (_) {
      // Fallback to popular on transient failure
      return popularMovies(page: page);
    }
  }

  Future<List<TmdbMovie>> trendingTv({int page = 1}) async {
    try {
      return await _getList(
        '/trending/tv/day',
        params: {'page': page},
        forcedType: 'tv',
      );
    } catch (_) {
      return popularTv(page: page);
    }
  }

  Future<List<TmdbMovie>> upcomingStrictMovies({int page = 1}) => _getList(
    '/discover/movie',
    params: {
      'sort_by': 'primary_release_date.asc',
      'primary_release_date.gte': _today(),
      'page': page,
    },
    forcedType: 'movie',
  );

  Future<List<TmdbMovie>> upcomingTv({int page = 1}) => _getList(
    '/discover/tv',
    params: {
      'sort_by': 'first_air_date.asc',
      'first_air_date.gte': _today(),
      'page': page,
    },
    forcedType: 'tv',
  );

  Future<List<TmdbMovie>> popularMovies({int page = 1}) =>
      _getList('/movie/popular', params: {'page': page}, forcedType: 'movie');

  Future<List<TmdbMovie>> topRatedMovies({int page = 1}) =>
      _getList('/movie/top_rated', params: {'page': page}, forcedType: 'movie');

  Future<List<TmdbMovie>> popularTv({int page = 1}) =>
      _getList('/tv/popular', params: {'page': page}, forcedType: 'tv');

  Future<List<TmdbMovie>> topRatedTv({int page = 1}) =>
      _getList('/tv/top_rated', params: {'page': page}, forcedType: 'tv');

  // ---------- Discover flexible ----------
  Future<List<TmdbMovie>> discoverMovies(
    Map<String, dynamic> params, {
    int page = 1,
  }) => _getList(
    '/discover/movie',
    params: {...params, 'page': page},
    forcedType: 'movie',
  );

  Future<List<TmdbMovie>> discoverTv(
    Map<String, dynamic> params, {
    int page = 1,
  }) => _getList(
    '/discover/tv',
    params: {...params, 'page': page},
    forcedType: 'tv',
  );

  // ---------- Search ----------
  Future<List<TmdbMovie>> searchMovies(String query, {int page = 1}) =>
      _getList(
        '/search/movie',
        params: {'query': query, 'page': page, 'include_adult': false},
        forcedType: 'movie',
      );

  Future<List<TmdbMovie>> searchTv(String query, {int page = 1}) => _getList(
    '/search/tv',
    params: {'query': query, 'page': page, 'include_adult': false},
    forcedType: 'tv',
  );

  Future<List<Map<String, dynamic>>> searchPerson(
    String query, {
    int page = 1,
  }) async {
    _ensureKey();
    final qp = <String, dynamic>{
      'api_key': _key,
      'language': language,
      'query': query,
      'page': page,
      'include_adult': false,
    };
    final resp = await _withRetry(
      () => _dio.get('/search/person', queryParameters: qp),
    );
    final results = (resp.data['results'] as List? ?? []);
    return results
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ---------- Genres ----------
  Future<List<Map<String, dynamic>>> genreListMovie() async {
    _ensureKey();
    final qp = <String, dynamic>{'api_key': _key, 'language': language};
    final resp = await _withRetry(
      () => _dio.get('/genre/movie/list', queryParameters: qp),
    );
    final list = (resp.data['genres'] as List? ?? [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return list;
  }

  Future<List<Map<String, dynamic>>> genreListTv() async {
    _ensureKey();
    final qp = <String, dynamic>{'api_key': _key, 'language': language};
    final resp = await _withRetry(
      () => _dio.get('/genre/tv/list', queryParameters: qp),
    );
    final list = (resp.data['genres'] as List? ?? [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return list;
  }

  // ---------- Details + addons ----------
  Future<Map<String, dynamic>> movieDetails(int id) => _getMap(
    '/movie/$id',
    params: {
      'append_to_response':
          'videos,images,credits,release_dates,recommendations',
      'include_image_language': '$_langShort,null',
    },
  );

  Future<Map<String, dynamic>> tvDetails(int id) => _getMap(
    '/tv/$id',
    params: {
      'append_to_response':
          'videos,images,aggregate_credits,content_ratings,recommendations',
      'include_image_language': '$_langShort,null',
    },
  );

  Future<Map<String, dynamic>> seasonDetails(int tvId, int seasonNumber) =>
      _getMap('/tv/$tvId/season/$seasonNumber');

  Future<Map<String, dynamic>> collectionDetails(int collectionId) =>
      _getMap('/collection/$collectionId');

  Future<List<TmdbMovie>> recommendations(
    String mediaType,
    int id, {
    int page = 1,
  }) {
    final path = (mediaType == 'tv')
        ? '/tv/$id/recommendations'
        : '/movie/$id/recommendations';
    return _getList(path, params: {'page': page}, forcedType: mediaType);
  }

  // ---------- People ----------
  Future<Map<String, dynamic>> personDetails(int id) => _getMap(
    '/person/$id',
    params: {
      'append_to_response': 'combined_credits,images',
      'include_image_language': '$_langShort,null',
    },
  );

  // ---------- Configuration (languages/countries) ----------
  Future<List<Map<String, dynamic>>> allLanguages() async {
    _ensureKey();
    final qp = <String, dynamic>{'api_key': _key};
    final resp = await _withRetry(
      () => _dio.get('/configuration/languages', queryParameters: qp),
    );
    final list = (resp.data as List? ?? []);
    return list.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> allCountries() async {
    _ensureKey();
    final qp = <String, dynamic>{'api_key': _key};
    final resp = await _withRetry(
      () => _dio.get('/configuration/countries', queryParameters: qp),
    );
    final list = (resp.data as List? ?? []);
    return list.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ---------- Internals ----------
  Future<List<TmdbMovie>> _getList(
    String path, {
    Map<String, dynamic>? params,
    String? forcedType,
  }) async {
    _ensureKey();
    final qp = <String, dynamic>{
      'api_key': _key,
      'language': language,
      ...?params,
    };

    if (path.startsWith('/discover/')) {
      qp['include_adult'] = false;
      qp['region'] = qp['region'] ?? region;
    }

    try {
      final resp = await _withRetry(() => _dio.get(path, queryParameters: qp));
      final list = (resp.data['results'] as List?) ?? const [];
      final out = list
          .map(
            (e) => TmdbMovie.fromJson(
              e as Map<String, dynamic>,
              forcedMediaType: forcedType,
            ),
          )
          .where((m) => (m.posterPath != null) || (m.backdropPath != null))
          .toList();

      // client guard for upcoming discover queries
      final today = DateTime.parse(_today());
      if (path.contains('/discover/movie') &&
          (params?['primary_release_date.gte'] != null)) {
        return out.where((m) => _isOnOrAfter(m.releaseDate, today)).toList();
      }
      if (path.contains('/discover/tv') &&
          (params?['first_air_date.gte'] != null)) {
        return out.where((m) => _isOnOrAfter(m.releaseDate, today)).toList();
      }
      return out;
    } on DioException catch (e) {
      _rethrowWithMessage(e, path);
    }
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    _ensureKey();
    final qp = <String, dynamic>{
      'api_key': _key,
      'language': language,
      ...?params,
    };
    try {
      final resp = await _withRetry(() => _dio.get(path, queryParameters: qp));
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      _rethrowWithMessage(e, path);
    }
  }

  Future<Response<T>> _withRetry<T>(Future<Response<T>> Function() send) async {
    DioException? last;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await send();
      } on DioException catch (e) {
        last = e;
        final t = e.type;
        final transient =
            t == DioExceptionType.connectionTimeout ||
            t == DioExceptionType.receiveTimeout ||
            t == DioExceptionType.sendTimeout || // added
            t == DioExceptionType.connectionError;
        if (!transient || attempt == _maxRetries) {
          rethrow;
        }
        // simple backoff: 400ms, 800ms
        final delay = _retryBaseDelay * (attempt + 1);
        await Future.delayed(delay);
      }
    }
    throw last ?? Exception('Dio request failed');
  }

  Never _rethrowWithMessage(DioException e, String path) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String apiMsg = '';
    if (data is Map && data['status_message'] != null) {
      apiMsg = ' | ${data['status_message']}';
    }
    debugPrint('[TMDB] $path failed: HTTP $code$apiMsg');
    throw Exception('TMDB request failed: $code$apiMsg');
  }

  bool _isOnOrAfter(String? iso, DateTime ref) {
    if (iso == null || iso.isEmpty) return false;
    try {
      final d = DateTime.parse(iso);
      final dd = DateTime(d.year, d.month, d.day);
      final rr = DateTime(ref.year, ref.month, ref.day);
      return !dd.isBefore(rr);
    } catch (_) {
      return false;
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _ensureKey() {
    if (_key.isEmpty) {
      throw Exception(
        'TMDB_KEY missing. Put it in .env or pass --dart-define=TMDB_KEY=YOUR_TMDB_KEY',
      );
    }
  }
}

// Debug logging interceptor that masks api_key
class _SafeLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[DIO] → ${_safeLine(options)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[DIO] ← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final ro = err.requestOptions;
      debugPrint(
        '[DIO] ⨯ ${ro.method} ${ro.path} | ${err.response?.statusCode} ${err.message}',
      );
    }
    handler.next(err);
  }

  String _safeLine(RequestOptions o) {
    final uri = o.uri;
    final qp = Map<String, String>.from(uri.queryParameters);
    if (qp.containsKey('api_key')) qp['api_key'] = '***';
    final query = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${o.method} ${uri.path}${query.isEmpty ? '' : '?$query'}';
  }
}
