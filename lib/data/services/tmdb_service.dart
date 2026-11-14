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

  /// Genera una clave de caché que expira naturalmente con el cambio de día del calendario (24 horas)
  String _getDailyCacheKey(String prefix) {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${_cachePrefix}${prefix}_$dateStr';
  }

  /// Obtener películas en tendencia (actualizado automáticamente cada 24 horas vía TMDB Day Trending)
  Future<List<MovieModel>> getTrendingMovies({int pages = 2, bool forceRefresh = false}) async {
    final key = effectiveApiKey;
    if (key.isEmpty) {
      return MockMoviesData.sampleMovies;
    }

    final cacheKey = _getDailyCacheKey('trending_day_v1');
    if (!forceRefresh) {
      final cached = await _getFromCache(cacheKey);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached) as List;
          final list = decoded.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
          if (list.isNotEmpty) return list;
        } catch (_) {}
      }
    }

    try {
      final List<MovieModel> accumulated = [];
      for (int p = 1; p <= pages; p++) {
        // Consultar /trending/movie/day (se actualiza diariamente en TMDB cada 24h a las 00:00 UTC)
        final url = Uri.parse('$_baseUrl/trending/movie/day?language=es-ES&page=$p&api_key=$key');
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
      debugPrint('[TmdbService] Error al consultar trending diario de TMDB: $e');
    }

    return MockMoviesData.sampleMovies;
  }

  /// Filtrar películas por géneros aprobados en el swipe.
  /// Si [streamingOnly] es true, descarta títulos que solo están en cines y
  /// consulta únicamente películas disponibles en plataformas de streaming (Netflix, Disney+, Max, etc.).
  /// Rota dinámicamente las páginas cada 24 horas según el día del año para garantizar variedad continua.
  Future<List<MovieModel>> discoverMoviesByGenres(
    List<int> genreIds, {
    int pages = 3,
    bool streamingOnly = false,
    String region = 'CL',
  }) async {
    if (genreIds.isEmpty) {
      final trending = await getTrendingMovies();
      var all = List<MovieModel>.from(trending);
      if (streamingOnly) {
        all = all.where((m) => m.streamingProviders.isNotEmpty).toList();
      }
      all.shuffle();
      return all;
    }

    final key = effectiveApiKey;
    if (key.isNotEmpty) {
      final genresParam = genreIds.join('|'); // OR condition
      // Rotación de catálogo cada 24 horas según el día del año
      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final dailyPageOffset = (dayOfYear % 4); // Rota páginas 1, 2, 3, 4 diariamente
      final startPage = 1 + dailyPageOffset;

      final streamingTag = streamingOnly ? '_stream_${region}_' : '_all_';
      final cacheKey = _getDailyCacheKey('disc_${genreIds.join("_")}_${streamingTag}p${pages}_s$startPage');
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
        final streamingParam = streamingOnly
            ? '&with_watch_monetization_types=flatrate|free|ads&watch_region=$region'
            : '';

        for (int p = startPage; p < startPage + pages; p++) {
          final url = Uri.parse(
            '$_baseUrl/discover/movie?language=es-ES&sort_by=popularity.desc&include_adult=false&with_genres=$genresParam$streamingParam&page=$p&api_key=$key',
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

        // Si streamingOnly devolvió pocos resultados en la región principal, complementar con catálogo MX
        if (streamingOnly && accumulated.length < 8 && region != 'MX') {
          try {
            final fallbackUrl = Uri.parse(
              '$_baseUrl/discover/movie?language=es-ES&sort_by=popularity.desc&include_adult=false&with_genres=$genresParam&with_watch_monetization_types=flatrate|free|ads&watch_region=MX&page=1&api_key=$key',
            );
            final resFb = await http.get(fallbackUrl).timeout(const Duration(seconds: 4));
            if (resFb.statusCode == 200) {
              final decodedFb = jsonDecode(resFb.body) as Map<String, dynamic>;
              final resultsFb = decodedFb['results'] as List? ?? [];
              for (final item in resultsFb) {
                final movie = MovieModel.fromJson(item as Map<String, dynamic>);
                if (movie.posterUrl.isNotEmpty && !accumulated.any((m) => m.id == movie.id)) {
                  accumulated.add(movie);
                }
              }
            }
          } catch (_) {}
        }

        if (accumulated.isNotEmpty) {
          // Enriquecer en paralelo las primeras películas con sus proveedores de streaming (JustWatch)
          final enriched = await Future.wait(
            accumulated.take(12).map((m) async {
              try {
                final provs = await getWatchProviders(m.id);
                if (provs.isNotEmpty) {
                  return m.copyWith(streamingProviders: provs);
                }
              } catch (_) {}
              return m;
            }),
          );
          final finalDeck = [
            ...enriched,
            ...accumulated.skip(12),
          ];
          await _saveToCache(cacheKey, jsonEncode(finalDeck.map((m) => m.toJson()).toList()));
          finalDeck.shuffle();
          return finalDeck;
        }
      } catch (e) {
        debugPrint('[TmdbService] Error al consultar discover de TMDB: $e');
      }
    }

    // Fallback estricto con baraja mock local
    var filtered = MockMoviesData.sampleMovies.where((movie) {
      return movie.genreIds.any((id) => genreIds.contains(id));
    }).toList();
    if (streamingOnly) {
      filtered = filtered.where((m) => m.streamingProviders.isNotEmpty).toList();
    }
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

  /// Obtener proveedores de streaming actualizados de una película en Latinoamérica y España
  Future<List<StreamingProviderModel>> getWatchProviders(int movieId) async {
    final key = effectiveApiKey;
    if (key.isEmpty) return [];

    try {
      final url = Uri.parse('$_baseUrl/movie/$movieId/watch/providers?api_key=$key');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'];
        if (results is Map) {
          return _parseProvidersFromResults(results);
        }
      }
    } catch (e) {
      debugPrint('[TmdbService] Error al consultar watch/providers de película $movieId: $e');
    }
    return [];
  }

  /// Extrae proveedores tipo suscripción (flatrate), gratis/con anuncios (free/ads) o compra/alquiler digital
  List<StreamingProviderModel> _parseProvidersFromResults(Map results) {
    final priorityRegions = ['CL', 'MX', 'ES', 'AR', 'CO', 'US'];
    final seenProviderIds = <int>{};
    final providers = <StreamingProviderModel>[];

    // 1. Priorizar servicios de streaming por suscripción (flatrate) y gratuitos/ads
    for (final region in priorityRegions) {
      final regionData = results[region];
      if (regionData is Map) {
        for (final key in ['flatrate', 'ads', 'free']) {
          if (regionData[key] is List) {
            for (final p in regionData[key]) {
              if (p is Map<String, dynamic>) {
                final model = StreamingProviderModel.fromJson(p, type: 'flatrate');
                if (!seenProviderIds.contains(model.id)) {
                  seenProviderIds.add(model.id);
                  providers.add(model);
                }
              }
            }
          }
        }
      }
    }

    // 2. Si no se encontraron en regiones prioritarias, revisar en cualquier otra región
    if (providers.isEmpty) {
      for (final entry in results.entries) {
        final regionData = entry.value;
        if (regionData is Map) {
          for (final key in ['flatrate', 'ads', 'free']) {
            if (regionData[key] is List) {
              for (final p in regionData[key]) {
                if (p is Map<String, dynamic>) {
                  final model = StreamingProviderModel.fromJson(p, type: 'flatrate');
                  if (!seenProviderIds.contains(model.id)) {
                    seenProviderIds.add(model.id);
                    providers.add(model);
                  }
                }
              }
            }
          }
        }
      }
    }

    // 3. Complemento digital si no hay suscripción activa: tiendas de alquiler y compra digital
    if (providers.isEmpty) {
      for (final region in priorityRegions) {
        final regionData = results[region];
        if (regionData is Map) {
          for (final key in ['buy', 'rent']) {
            if (regionData[key] is List) {
              for (final p in regionData[key]) {
                if (p is Map<String, dynamic>) {
                  final model = StreamingProviderModel.fromJson(p, type: key);
                  if (!seenProviderIds.contains(model.id)) {
                    seenProviderIds.add(model.id);
                    providers.add(model);
                  }
                }
              }
            }
          }
        }
      }
    }

    return providers;
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

        // Parsear providers JustWatch multi-región
        List<StreamingProviderModel> providers = [];
        final results = data['watch/providers']?['results'];
        if (results is Map) {
          providers = _parseProvidersFromResults(results);
        }

        // Parsear reviews
        List<ReviewModel> reviews = [];
        final revResults = data['reviews']?['results'];
        if (revResults is List && revResults.isNotEmpty) {
          reviews = revResults.map((r) => ReviewModel.fromJson(r as Map<String, dynamic>)).toList();
        } else {
          // Si no había reseñas en es-ES, consultar endpoint general de reviews de TMDB
          try {
            final globalRevUrl = Uri.parse('$_baseUrl/movie/$movieId/reviews?api_key=$key');
            final gRes = await http.get(globalRevUrl).timeout(const Duration(seconds: 4));
            if (gRes.statusCode == 200) {
              final gData = jsonDecode(gRes.body) as Map<String, dynamic>;
              final gList = gData['results'] as List? ?? [];
              reviews = gList.map((r) => ReviewModel.fromJson(r as Map<String, dynamic>)).toList();
            }
          } catch (_) {}
        }

        // Asegurar como mínimo 1 positiva y 1 crítica/negativa (garantía de reseñas balanceadas)
        reviews = ReviewModel.ensureBalancedReviews(
          reviews.isNotEmpty ? reviews : (local?.reviews ?? []),
          title: data['title'] as String? ?? local?.title ?? 'Película',
          rating: ((data['vote_average'] ?? local?.rating ?? 7.5) as num).toDouble(),
        );

        final movie = MovieModel.fromJson(data).copyWith(
          streamingProviders: providers.isNotEmpty ? providers : (local?.streamingProviders ?? []),
          reviews: reviews,
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
