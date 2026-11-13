import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_model.dart';
import '../mock/mock_movies_data.dart';

class FavoritesService extends ChangeNotifier {
  static const String _favsPrefKey = 'swipeflick_favorites_list';
  static const String _matchesPrefKey = 'swipeflick_matches_history';

  final List<MovieModel> _favorites = [];
  final List<MovieModel> _matchesHistory = [];

  List<MovieModel> get favorites => List.unmodifiable(_favorites);
  List<MovieModel> get matchesHistory => List.unmodifiable(_matchesHistory);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Favoritos
    final favsJson = prefs.getString(_favsPrefKey);
    if (favsJson != null) {
      try {
        final list = (jsonDecode(favsJson) as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _favorites.clear();
        _favorites.addAll(list);
      } catch (_) {}
    } else {
      // Agregar Dune por defecto para que la biblioteca tenga contenido inicial
      if (MockMoviesData.sampleMovies.isNotEmpty) {
        _favorites.add(MockMoviesData.sampleMovies[0]);
      }
    }

    // Historial de matches
    final matchesJson = prefs.getString(_matchesPrefKey);
    if (matchesJson != null) {
      try {
        final list = (jsonDecode(matchesJson) as List)
            .map((m) => MovieModel.fromJson(m as Map<String, dynamic>))
            .toList();
        _matchesHistory.clear();
        _matchesHistory.addAll(list);
      } catch (_) {}
    }

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
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> addMatchToHistory(MovieModel movie) async {
    _matchesHistory.removeWhere((m) => m.id == movie.id);
    _matchesHistory.insert(0, movie);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_matchesPrefKey, jsonEncode(_matchesHistory.map((m) => m.toJson()).toList()));
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favsPrefKey, jsonEncode(_favorites.map((m) => m.toJson()).toList()));
  }
}
