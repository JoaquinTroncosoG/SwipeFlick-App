import '../../core/constants/app_constants.dart';
import 'streaming_provider_model.dart';
import 'review_model.dart';

class MovieModel {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String releaseDate;
  final double rating;
  final int voteCount;
  final List<String> genres;
  final List<int> genreIds;
  final int runtime; // en minutos
  final String? tagline;
  final List<StreamingProviderModel> streamingProviders;
  final List<ReviewModel> reviews;

  const MovieModel({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate = '2024',
    required this.rating,
    this.voteCount = 0,
    this.genres = const [],
    this.genreIds = const [],
    this.runtime = 120,
    this.tagline,
    this.streamingProviders = const [],
    this.reviews = const [],
  });

  String get releaseYear {
    if (releaseDate.isEmpty) return '2024';
    return releaseDate.split('-').first;
  }

  String get formattedRuntime {
    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get fullPosterUrl {
    if (posterPath == null || posterPath!.isEmpty) {
      return '${AppConstants.tmdbImageBaseUrl}/d5NXSklXo0qyIYkgV94XAgMIckC.jpg';
    }
    if (posterPath!.startsWith('http')) return posterPath!;
    return '${AppConstants.tmdbImageBaseUrl}$posterPath';
  }

  String get posterUrl => fullPosterUrl;

  String get fullBackdropUrl {
    if (backdropPath == null || backdropPath!.isEmpty) {
      return fullPosterUrl;
    }
    if (backdropPath!.startsWith('http')) return backdropPath!;
    return '${AppConstants.tmdbBackdropBaseUrl}$backdropPath';
  }

  String get backdropUrl => fullBackdropUrl;

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    // Géneros
    List<String> parsedGenres = [];
    List<int> parsedGenreIds = [];
    if (json['genres'] is List) {
      for (var g in json['genres']) {
        if (g is Map<String, dynamic>) {
          parsedGenres.add(g['name']?.toString() ?? '');
          if (g['id'] is int) parsedGenreIds.add(g['id'] as int);
        } else if (g is String) {
          parsedGenres.add(g);
        }
      }
    } else if (json['genre_ids'] is List) {
      for (var id in json['genre_ids']) {
        if (id is int) parsedGenreIds.add(id);
      }
    }

    // Providers
    List<StreamingProviderModel> parsedProviders = [];
    if (json['streaming_providers'] is List) {
      parsedProviders = (json['streaming_providers'] as List)
          .map((p) => StreamingProviderModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    // Reviews
    List<ReviewModel> parsedReviews = [];
    if (json['reviews'] is List) {
      parsedReviews = (json['reviews'] as List)
          .map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return MovieModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Película sin título',
      overview: json['overview'] as String? ?? 'Sin descripción disponible.',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String? ?? '2024',
      rating: ((json['vote_average'] ?? json['rating'] ?? 7.5) as num).toDouble(),
      voteCount: json['vote_count'] as int? ?? 100,
      genres: parsedGenres,
      genreIds: parsedGenreIds,
      runtime: json['runtime'] as int? ?? 120,
      tagline: json['tagline'] as String?,
      streamingProviders: parsedProviders,
      reviews: parsedReviews,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'release_date': releaseDate,
      'vote_average': rating,
      'vote_count': voteCount,
      'genres': genres,
      'genre_ids': genreIds,
      'runtime': runtime,
      'tagline': tagline,
      'streaming_providers': streamingProviders.map((p) => p.toJson()).toList(),
      'reviews': reviews.map((r) => r.toJson()).toList(),
    };
  }

  MovieModel copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? rating,
    int? voteCount,
    List<String>? genres,
    List<int>? genreIds,
    int? runtime,
    String? tagline,
    List<StreamingProviderModel>? streamingProviders,
    List<ReviewModel>? reviews,
  }) {
    return MovieModel(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      voteCount: voteCount ?? this.voteCount,
      genres: genres ?? this.genres,
      genreIds: genreIds ?? this.genreIds,
      runtime: runtime ?? this.runtime,
      tagline: tagline ?? this.tagline,
      streamingProviders: streamingProviders ?? this.streamingProviders,
      reviews: reviews ?? this.reviews,
    );
  }
}
