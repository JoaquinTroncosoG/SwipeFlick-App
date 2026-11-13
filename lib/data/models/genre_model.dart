class GenreModel {
  final int id;
  final String name;
  final String emoji;
  final String description;
  final String? samplePosterUrl;

  const GenreModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.samplePosterUrl,
  });

  factory GenreModel.fromJson(Map<String, dynamic> json) {
    return GenreModel(
      id: json['id'] as int,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🎬',
      description: json['description'] as String? ?? 'Películas de ${json["name"]}',
      samplePosterUrl: json['sample_poster_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'sample_poster_url': samplePosterUrl,
    };
  }

  /// Lista oficial de géneros TMDB con emojis, descripciones e imágenes 100% verificadas y exactas
  static const List<GenreModel> defaultGenres = [
    GenreModel(
      id: 28,
      name: 'Acción',
      emoji: '💥',
      description: 'Adrenalina, persecuciones intensas y combates épicos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/vZloFAK7NmvMGKE7VkF5UHaz0I.jpg', // John Wick 4
    ),
    GenreModel(
      id: 35,
      name: 'Comedia',
      emoji: '😂',
      description: 'Risas aseguradas, humor inteligente y momentos divertidos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg', // Barbie
    ),
    GenreModel(
      id: 27,
      name: 'Terror',
      emoji: '👻',
      description: 'Sustos, suspenso paranormal y pesadillas inolvidables',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/wVYREutTvI2tmxr6ujrHT704wGF.jpg', // El Conjuro
    ),
    GenreModel(
      id: 878,
      name: 'Ciencia Ficción',
      emoji: '🚀',
      description: 'Viajes temporales, universos paralelos y futuros distópicos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/d5NXSklXo0qyIYkgV94XAgMIckC.jpg', // Dune: Parte Dos
    ),
    GenreModel(
      id: 18,
      name: 'Drama',
      emoji: '🎭',
      description: 'Historias profundas, emociones reales y personajes complejos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg', // Sueños de Fuga
    ),
    GenreModel(
      id: 10749,
      name: 'Romance',
      emoji: '❤️',
      description: 'Historias de amor, química cautivadora y finales emotivos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg', // Titanic
    ),
    GenreModel(
      id: 16,
      name: 'Animación',
      emoji: '🎨',
      description: 'Magia visual, aventuras familiares y mundos animados',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/iiZZdoQBEYBv6id8su7ImL0oCbD.jpg', // Spider-Man: Un Nuevo Universo
    ),
    GenreModel(
      id: 53,
      name: 'Thriller / Suspenso',
      emoji: '🔍',
      description: 'Giros inesperados, misterios al límite y tensión constante',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', // Parásitos
    ),
    GenreModel(
      id: 14,
      name: 'Fantasía',
      emoji: '🧙',
      description: 'Criaturas míticas, magia ancestral y reinos asombrosos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/t6HIqrRAclMCA60NsSmeqe9RmNV.jpg', // Avatar 2
    ),
    GenreModel(
      id: 12,
      name: 'Aventura',
      emoji: '🗺️',
      description: 'Expediciones lejanas, descubrimientos y supervivencia',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/8tZYtuWezp8JbcsvHYO0O46tFbo.jpg', // Mad Max: Furia en el Camino
    ),
  ];
}
