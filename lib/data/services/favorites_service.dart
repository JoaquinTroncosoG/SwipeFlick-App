import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_model.dart';
import 'mongodb_service.dart';

class FavoritesService extends ChangeNotifier {
  static const String _defaultFavsPrefKey = 'swipeflick_favorites_list';
  static const String _defaultMatchesPrefKey = 'swipeflick_matches_history';

  final List<MovieModel> _favorites = [];
  final List<MovieModel> _matchesHistory = [];
  String? _currentUserEmail;
  MongoDbService? _mongoService;

  List<MovieModel> get favorites => List.unmodifiable(_favorites);
  List<MovieModel> get matchesHistory => List.unmodifiable(_matchesHistory);

  String get _favsKey => _currentUserEmail != null && _currentUserEmail!.isNotEmpty
      ? 'swipeflick_favorites_${_currentUserEmail!.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
      : _defaultFavsPrefKey;

  String get _matchesKey => _currentUserEmail != null && _currentUserEmail!.isNotEmpty
      ? 'swipeflick_matches_${_currentUserEmail!.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
      : _defaultMatchesPrefKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Cargar favoritos locales
    final favsJson = prefs.getString(_favsKey);
    if (favsJson != null) {
      try {
        final list = (jsonDecode(favsJson) as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _favorites.clear();
        _favorites.addAll(list);
      } catch (_) {}
    } else {
      // Migrar favoritos guardados en sesión previa/invitado si existen
      final defaultFavs = prefs.getString(_defaultFavsPrefKey);
      if (defaultFavs != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
        try {
          final list = (jsonDecode(defaultFavs) as List)
              .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
              .toList();
          _favorites.clear();
          _favorites.addAll(list);
          await _saveLocalFavorites();
        } catch (_) {}
      } else {
        _favorites.clear();
      }
    }

    // 2. Cargar historial de matches local
    final matchesJson = prefs.getString(_matchesKey);
    if (matchesJson != null) {
      try {
        final list = (jsonDecode(matchesJson) as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _matchesHistory.clear();
        _matchesHistory.addAll(list);
      } catch (_) {}
    } else {
      // Migrar historial de matches guardado en sesión previa/invitado si existen
      final defaultMatches = prefs.getString(_defaultMatchesPrefKey);
      if (defaultMatches != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
        try {
          final list = (jsonDecode(defaultMatches) as List)
              .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
              .toList();
          _matchesHistory.clear();
          _matchesHistory.addAll(list);
          await _saveLocalMatches();
        } catch (_) {}
      } else {
        _matchesHistory.clear();
      }
    }

    notifyListeners();
  }

  /// Vincula la sesión de un usuario y sincroniza bidireccionalmente con MongoDB Atlas
  Future<void> attachUser(String? email, MongoDbService? mongo) async {
    _currentUserEmail = email;
    _mongoService = mongo;

    await init();

    if (_currentUserEmail != null && _currentUserEmail!.isNotEmpty && _mongoService != null) {
      try {
        if (_mongoService!.isConnected || await _mongoService!.ensureConnected()) {
          // 1. Sincronizar favoritos: fusión inteligente sin pérdida de datos
          final cloudFavsRaw = await _mongoService!.getUserFavorites(_currentUserEmail!);
          if (cloudFavsRaw.isNotEmpty) {
            final cloudFavs = cloudFavsRaw.map((m) => MovieModel.fromJson(m)).toList();
            final map = <int, MovieModel>{};
            for (final m in cloudFavs) {
              map[m.id] = m;
            }
            for (final m in _favorites) {
              map[m.id] = m;
            }
            _favorites.clear();
            _favorites.addAll(map.values);
            await _saveLocalFavorites();
          }
          if (_favorites.isNotEmpty) {
            await _mongoService!.saveUserFavorites(
              _currentUserEmail!,
              _favorites.map((m) => m.toJson()).toList(),
            );
          }

          // 2. Sincronizar historial de matches: fusión inteligente sin pérdida de datos
          final cloudMatchesRaw = await _mongoService!.getUserMatchesHistory(_currentUserEmail!);
          if (cloudMatchesRaw.isNotEmpty) {
            final cloudMatches = cloudMatchesRaw.map((m) => MovieModel.fromJson(m)).toList();
            final map = <int, MovieModel>{};
            for (final m in cloudMatches) {
              map[m.id] = m;
            }
            for (final m in _matchesHistory) {
              map[m.id] = m;
            }
            _matchesHistory.clear();
            _matchesHistory.addAll(map.values);
            await _saveLocalMatches();
          }
          if (_matchesHistory.isNotEmpty) {
            await _mongoService!.saveUserMatchesHistory(
              _currentUserEmail!,
              _matchesHistory.map((m) => m.toJson()).toList(),
            );
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[FavoritesService] Error al sincronizar biblioteca con Atlas: $e');
      }
    }
  }

  /// Limpia el estado de biblioteca en memoria al cerrar sesión
  void clearOnSignOut() {
    _currentUserEmail = null;
    _favorites.clear();
    _matchesHistory.clear();
    notifyListeners();
  }

  bool isFavorite(int movieId) {
    return _favorites.any((m) => m.id == movieId);
  }

  Future<void> toggleFavorite(MovieModel movie) async {
    final exists = _favorites.any((m) => m.id == movie.id);
    if (exists) {
      _favorites.removeWhere((m) => m.id == movie.id);
    } else {
      _favorites.insert(0, movie);
    }
    await _saveLocalFavorites();

    // Persistir de forma persistente en MongoDB Atlas
    if (_mongoService != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      try {
        await _mongoService!.saveUserFavorites(
          _currentUserEmail!,
          _favorites.map((m) => m.toJson()).toList(),
        );
      } catch (e) {
        debugPrint('[FavoritesService] Error al guardar favorito en Atlas: $e');
      }
    }

    notifyListeners();
  }

  Future<void> addMatchToHistory(MovieModel movie) async {
    _matchesHistory.removeWhere((m) => m.id == movie.id);
    _matchesHistory.insert(0, movie);
    await _saveLocalMatches();

    if (_mongoService != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      try {
        await _mongoService!.saveUserMatchesHistory(
          _currentUserEmail!,
          _matchesHistory.map((m) => m.toJson()).toList(),
        );
      } catch (e) {
        debugPrint('[FavoritesService] Error al guardar match en Atlas: $e');
      }
    }

    notifyListeners();
  }

  Future<void> removeFavorite(int movieId) async {
    _favorites.removeWhere((m) => m.id == movieId);
    await _saveLocalFavorites();

    if (_mongoService != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      try {
        await _mongoService!.saveUserFavorites(
          _currentUserEmail!,
          _favorites.map((m) => m.toJson()).toList(),
        );
      } catch (e) {
        debugPrint('[FavoritesService] Error al actualizar favoritos en Atlas: $e');
      }
    }
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveLocalFavorites();

    if (_mongoService != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      try {
        await _mongoService!.saveUserFavorites(
          _currentUserEmail!,
          [],
        );
      } catch (e) {
        debugPrint('[FavoritesService] Error al vaciar favoritos en Atlas: $e');
      }
    }
    notifyListeners();
  }

  Future<void> removeMatch(int movieId) async {
    _matchesHistory.removeWhere((m) => m.id == movieId);
    await _saveLocalMatches();

    if (_mongoService != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      try {
        await _mongoService!.saveUserMatchesHistory(
          _currentUserEmail!,
          _matchesHistory.map((m) => m.toJson()).toList(),
        );
      } catch (e) {
        debugPrint('[FavoritesService] Error al eliminar match en Atlas: $e');
      }
    }
    notifyListeners();
  }

  Future<void> clearMatchesHistory() async {
    _matchesHistory.clear();
    await _saveLocalMatches();

    if (_mongoService != null && _currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      try {
        await _mongoService!.saveUserMatchesHistory(
          _currentUserEmail!,
          [],
        );
      } catch (e) {
        debugPrint('[FavoritesService] Error al vaciar historial de matches en Atlas: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _saveLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favsKey, jsonEncode(_favorites.map((m) => m.toJson()).toList()));
  }

  Future<void> _saveLocalMatches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_matchesKey, jsonEncode(_matchesHistory.map((m) => m.toJson()).toList()));
  }
}
