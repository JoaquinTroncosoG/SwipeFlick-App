import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/search_dictionary_helper.dart';
import '../models/genre_model.dart';
import '../models/movie_model.dart';
import '../models/streaming_provider_model.dart';
import '../models/review_model.dart';
import '../mock/mock_movies_data.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _cachePrefix = 'tmdb_cache_';
  static const String _apiKeyPrefKey = 'tmdb_api_key_custom';
  static const Duration _cacheTtl = Duration(hours: 24);

  /// Clave API predeterminada de TMDB obfuscada (XOR 0x3F) para habilitar el catálogo completo de películas
  static String get defaultApiKey {
    const fromEnv = String.fromEnvironment('TMDB_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      const xorBytes = [
        11, 90, 11, 11, 91, 6, 15, 13, 6, 93, 14, 13, 8, 15, 94, 8, 10, 8, 92, 91, 91, 92, 8, 9, 9, 94, 14, 93, 92, 93, 9, 12
      ];
      return String.fromCharCodes(xorBytes.map((b) => b ^ 0x3F));
    } catch (_) {
      return '';
    }
  }

  String? _customApiKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customApiKey = prefs.getString(_apiKeyPrefKey);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _customApiKey = key.trim().isEmpty ? null : key.trim();
    if (_customApiKey != null) {
      await prefs.setString(_apiKeyPrefKey, _customApiKey!);
    } else {
      await prefs.remove(_apiKeyPrefKey);
    }
  }

  String? get apiKey => _customApiKey;

  String get effectiveApiKey {
    if (_customApiKey != null && _customApiKey!.trim().isNotEmpty) {
      return _customApiKey!.trim();
    }
    return defaultApiKey;
  }

  bool get hasApiKey => effectiveApiKey.isNotEmpty;

  /// Obtener lista de géneros/categorías (con cache de 24h)
  Future<List<GenreModel>> getGenres() async {
    final key = effectiveApiKey;
    if (key.isEmpty) {
      return GenreModel.defaultGenres;
    }

    const cacheKey = '${_cachePrefix}genres_v4';
    final cached = await _getFromCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final list = (decoded['genres'] as List)
            .map((g) => GenreModel.fromJson(g as Map<String, dynamic>))
            .toList();
        return list;
      } catch (_) {}
    }

    try {
      final url = Uri.parse('$_baseUrl/genre/movie/list?language=es-ES&api_key=$key');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        await _saveToCache(cacheKey, res.body);
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return (decoded['genres'] as List)
            .map((g) => GenreModel.fromJson(g as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return GenreModel.defaultGenres;
  }

  /// Obtener películas en tendencia (con cache de 24h y paginación de hasta 40 películas)
  Future<List<MovieModel>> getTrendingMovies({int pages = 2}) async {
    final key = effectiveApiKey;
    if (key.isEmpty) {
      return MockMoviesData.sampleMovies;
    }

    const cacheKey = '${_cachePrefix}trending_v4';
    final cached = await _getFromCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        final list = decoded.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    try {
      final List<MovieModel> accumulated = [];
      for (int p = 1; p <= pages; p++) {
        final url = Uri.parse('$_baseUrl/trending/movie/week?language=es-ES&page=$p&api_key=$key');
        final res = await http.get(url).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final results = decoded['results'] as List? ?? [];
          for (final item in results) {
            final movie = MovieModel.fromJson(item as Map<String, dynamic>);
            if (movie.posterUrl.isNotEmpty && !accumulated.any((m) => m.id == movie.id)) {
              accumulated.add(movie);
            }
          }
        }
      }
      if (accumulated.isNotEmpty) {
        await _saveToCache(cacheKey, jsonEncode(accumulated.map((m) => m.toJson()).toList()));
        return accumulated;
      }
    } catch (e) {
      debugPrint('[TmdbService] Error al consultar trending de TMDB: $e');
    }

    return MockMoviesData.sampleMovies;
  }

  /// Filtrar películas por géneros aprobados en el swipe
  /// Consulta el catálogo completo de TMDB (hasta 60 películas por combinación)
  /// y garantiza que contengan al menos uno de los géneros ganadores con baraja dinámica.
  Future<List<MovieModel>> discoverMoviesByGenres(List<int> genreIds, {int pages = 3}) async {
    if (genreIds.isEmpty) {
      final trending = await getTrendingMovies();
      final all = List<MovieModel>.from(trending)..shuffle();
      return all;
    }

    final key = effectiveApiKey;
    if (key.isNotEmpty) {
      final genresParam = genreIds.join('|'); // OR condition
      final cacheKey = '${_cachePrefix}discover_${genreIds.join("_")}_p$pages';
      final cached = await _getFromCache(cacheKey);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached) as List;
          final list = decoded.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
          if (list.isNotEmpty) {
            list.shuffle();
            return list;
          }
        } catch (_) {}
      }

      try {
        final List<MovieModel> accumulated = [];
        for (int p = 1; p <= pages; p++) {
          final url = Uri.parse(
            '$_baseUrl/discover/movie?language=es-ES&sort_by=popularity.desc&include_adult=false&with_genres=$genresParam&page=$p&api_key=$key',
          );
          final res = await http.get(url).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body) as Map<String, dynamic>;
            final results = decoded['results'] as List? ?? [];
            for (final item in results) {
              final movie = MovieModel.fromJson(item as Map<String, dynamic>);
              if (movie.posterUrl.isNotEmpty && !accumulated.any((m) => m.id == movie.id)) {
                accumulated.add(movie);
              }
            }
          }
        }
        if (accumulated.isNotEmpty) {
          await _saveToCache(cacheKey, jsonEncode(accumulated.map((m) => m.toJson()).toList()));
          accumulated.shuffle();
          return accumulated;
        }
      } catch (e) {
        debugPrint('[TmdbService] Error al consultar discover de TMDB: $e');
      }
    }

    // Fallback estricto con baraja mock local
    final filtered = MockMoviesData.sampleMovies.where((movie) {
      return movie.genreIds.any((id) => genreIds.contains(id));
    }).toList();
    filtered.shuffle();
    return filtered;
  }

  /// Buscar películas por texto o título utilizando el catálogo de TMDB
  /// con fallback en el diccionario inteligente tolerante a acentos y sinónimos.
  Future<List<MovieModel>> searchMovies(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return getTrendingMovies();
    }

    final key = effectiveApiKey;
    if (key.isNotEmpty) {
      try {
        final encoded = Uri.encodeComponent(clean);
        final url = Uri.parse('$_baseUrl/search/movie?language=es-ES&query=$encoded&include_adult=false&api_key=$key');
        final res = await http.get(url).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final results = decoded['results'] as List? ?? [];
          final list = results
              .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
              .where((m) => m.posterUrl.isNotEmpty)
              .toList();
          if (list.isNotEmpty) return list;
        }
      } catch (e) {
        debugPrint('[TmdbService] Error en búsqueda TMDB: $e');
      }
    }

    return SearchDictionaryHelper.searchMovies(
      catalog: MockMoviesData.sampleMovies,
      query: clean,
    );
  }

  /// Obtener detalle completo de película (con streaming providers JustWatch y reviews)
  Future<MovieModel> getMovieDetails(int movieId) async {
    final local = MockMoviesData.sampleMovies.cast<MovieModel?>().firstWhere(
          (m) => m?.id == movieId,
          orElse: () => null,
        );

    final key = effectiveApiKey;
    if (key.isEmpty) {
      if (local != null) return local;
      return MockMoviesData.sampleMovies.first;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/movie/$movieId?language=es-ES&append_to_response=credits,reviews,watch/providers&api_key=$key');
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // Parsear providers JustWatch
        List<StreamingProviderModel> providers = [];
        final results = data['watch/providers']?['results'];
        if (results != null) {
          final countryData = results['CL'] ?? results['ES'] ?? results['MX'] ?? results['US'] ?? results.values.firstOrNull;
          if (countryData != null && countryData['flatrate'] is List) {
            for (var p in countryData['flatrate']) {
              providers.add(StreamingProviderModel.fromJson(p as Map<String, dynamic>, type: 'flatrate'));
            }
          }
        }

        // Parsear reviews
        List<ReviewModel> reviews = [];
        final revResults = data['reviews']?['results'];
        if (revResults is List) {
          reviews = revResults.map((r) => ReviewModel.fromJson(r as Map<String, dynamic>)).toList();
        }

        final movie = MovieModel.fromJson(data).copyWith(
          streamingProviders: providers.isNotEmpty ? providers : (local?.streamingProviders ?? []),
          reviews: reviews.isNotEmpty ? reviews : (local?.reviews ?? []),
        );
        return movie;
      }
    } catch (e) {
      debugPrint('[TmdbService] Error al obtener detalles de película: $e');
    }

    return local ?? MockMoviesData.sampleMovies.first;
  }

  // Caching helpers (TTL 24 horas)
  Future<void> _saveToCache(String key, String data) async {
    final prefs = await SharedPreferences.getInstance();
    final item = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await prefs.setString(key, jsonEncode(item));
  }

  Future<String?> _getFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = map['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _cacheTtl.inMilliseconds) {
        await prefs.remove(key);
        return null;
      }
      return map['data'] as String?;
    } catch (_) {
      return null;
    }
  }
}
