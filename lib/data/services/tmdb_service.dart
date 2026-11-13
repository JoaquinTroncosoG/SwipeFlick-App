import 'dart:convert';
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
  bool get hasApiKey => _customApiKey != null && _customApiKey!.isNotEmpty;

  /// Obtener lista de géneros/categorías (con cache de 24h)
  Future<List<GenreModel>> getGenres() async {
    if (!hasApiKey) {
      return GenreModel.defaultGenres;
    }

    const cacheKey = '${_cachePrefix}genres';
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
      final url = Uri.parse('$_baseUrl/genre/movie/list?language=es-ES&api_key=$_customApiKey');
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

  /// Obtener películas en tendencia (con cache de 24h)
  Future<List<MovieModel>> getTrendingMovies() async {
    if (!hasApiKey) {
      return MockMoviesData.sampleMovies;
    }

    const cacheKey = '${_cachePrefix}trending';
    final cached = await _getFromCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final list = (decoded['results'] as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .toList();
        return list;
      } catch (_) {}
    }

    try {
      final url = Uri.parse('$_baseUrl/trending/movie/week?language=es-ES&api_key=$_customApiKey');
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        await _saveToCache(cacheKey, res.body);
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return (decoded['results'] as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return MockMoviesData.sampleMovies;
  }

  /// Filtrar películas por géneros aprobados en el swipe
  /// Garantiza que TODAS las películas devueltas contengan AL MENOS uno de los géneros ganadores
  /// y descarta completamente las no coincidentes. Además, baraja la baraja para evitar
  /// mostrar la misma ruleta fija cada vez.
  Future<List<MovieModel>> discoverMoviesByGenres(List<int> genreIds) async {
    if (genreIds.isEmpty) {
      final all = List<MovieModel>.from(MockMoviesData.sampleMovies)..shuffle();
      return all;
    }

    if (!hasApiKey) {
      // Filtrar estrictamente: solo películas que tengan al menos 1 género coincidente
      final filtered = MockMoviesData.sampleMovies.where((movie) {
        return movie.genreIds.any((id) => genreIds.contains(id));
      }).toList();
      filtered.shuffle();
      return filtered;
    }

    final genresParam = genreIds.join('|'); // OR condition
    final cacheKey = '${_cachePrefix}discover_$genresParam';
    final cached = await _getFromCache(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final list = (decoded['results'] as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .where((m) => m.genreIds.any((id) => genreIds.contains(id)))
            .toList();
        if (list.isNotEmpty) {
          list.shuffle();
          return list;
        }
      } catch (_) {}
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/discover/movie?language=es-ES&sort_by=popularity.desc&include_adult=false&with_genres=$genresParam&api_key=$_customApiKey');
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        await _saveToCache(cacheKey, res.body);
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (decoded['results'] as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .where((m) => m.genreIds.any((id) => genreIds.contains(id)))
            .toList();
        if (list.isNotEmpty) {
          list.shuffle();
          return list;
        }
      }
    } catch (_) {}

    // Fallback estricto con baraja mock local
    final filtered = MockMoviesData.sampleMovies.where((movie) {
      return movie.genreIds.any((id) => genreIds.contains(id));
    }).toList();
    filtered.shuffle();
    return filtered;
  }

  /// Buscar películas por texto o género utilizando el diccionario inteligente
  /// Soporta faltas de acentos (ej: "accion", "ficcion"), términos populares ("miedo", "tiros", "scifi", "dibujos")
  /// y búsquedas por título o sinopsis.
  Future<List<MovieModel>> searchMovies(String query) async {
    if (query.trim().isEmpty) {
      return getTrendingMovies();
    }

    return SearchDictionaryHelper.searchMovies(
      catalog: MockMoviesData.sampleMovies,
      query: query,
    );
  }

  /// Obtener detalle completo de película (con append_to_response para optimización)
  Future<MovieModel> getMovieDetails(int movieId) async {
    // Buscar primero en mock
    final local = MockMoviesData.sampleMovies.cast<MovieModel?>().firstWhere(
          (m) => m?.id == movieId,
          orElse: () => null,
        );

    if (!hasApiKey) {
      if (local != null) return local;
      return MockMoviesData.sampleMovies.first;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/movie/$movieId?language=es-ES&append_to_response=credits,reviews,watch/providers&api_key=$_customApiKey');
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        
        // Parsear providers
        List<StreamingProviderModel> providers = [];
        final results = data['watch/providers']?['results'];
        if (results != null) {
          // Intentar ES o US o MX
          final countryData = results['ES'] ?? results['MX'] ?? results['US'] ?? results.values.firstOrNull;
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
    } catch (_) {}

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
