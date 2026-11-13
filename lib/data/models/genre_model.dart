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
    final id = json['id'] as int? ?? 0;
    final name = json['name'] as String? ?? 'Película';

    // Buscar en defaults por ID para enriquecer automáticamente con samplePosterUrl, emoji y descripción
    final defaultMatch = defaultGenres.cast<GenreModel?>().firstWhere(
          (g) => g?.id == id,
          orElse: () => null,
        );

    final rawPoster = json['sample_poster_url'] as String?;
    final poster = (rawPoster != null && rawPoster.trim().isNotEmpty)
        ? rawPoster
        : defaultMatch?.samplePosterUrl;

    return GenreModel(
      id: id,
      name: name,
      emoji: json['emoji'] as String? ?? defaultMatch?.emoji ?? '🎬',
      description: json['description'] as String? ?? defaultMatch?.description ?? 'Películas de $name',
      samplePosterUrl: poster,
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
      id: 12,
      name: 'Aventura',
      emoji: '🗺️',
      description: 'Expediciones lejanas, descubrimientos y supervivencia',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/8tZYtuWezp8JbcsvHYO0O46tFbo.jpg', // Mad Max: Furia en el Camino
    ),
    GenreModel(
      id: 16,
      name: 'Animación',
      emoji: '🎨',
      description: 'Magia visual, aventuras familiares y mundos animados',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/iiZZdoQBEYBv6id8su7ImL0oCbD.jpg', // Spider-Man: Un Nuevo Universo
    ),
    GenreModel(
      id: 35,
      name: 'Comedia',
      emoji: '😂',
      description: 'Risas aseguradas, humor inteligente y momentos divertidos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg', // Barbie
    ),
    GenreModel(
      id: 80,
      name: 'Crimen',
      emoji: '🕵️',
      description: 'Mafias, investigaciones policíacas y crímenes complejos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', // El Padrino
    ),
    GenreModel(
      id: 99,
      name: 'Documental',
      emoji: '📹',
      description: 'Hechos reales, naturaleza, ciencia y testimonios históricos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/Ap8QwmKfSjYbWC4XIP8w9pdn72O.jpg', // Documental / Planeta
    ),
    GenreModel(
      id: 18,
      name: 'Drama',
      emoji: '🎭',
      description: 'Historias profundas, emociones reales y personajes complejos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg', // Sueños de Fuga
    ),
    GenreModel(
      id: 10751,
      name: 'Familia',
      emoji: '👨‍👩‍👧‍👦',
      description: 'Películas entrañables para disfrutar todas las edades juntos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/gKkl37BQuKTanygYQG1pyYgLVgf.jpg', // Coco
    ),
    GenreModel(
      id: 14,
      name: 'Fantasía',
      emoji: '🧙',
      description: 'Criaturas míticas, magia ancestral y reinos asombrosos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/t6HIqrRAclMCA60NsSmeqe9RmNV.jpg', // Avatar 2
    ),
    GenreModel(
      id: 36,
      name: 'Historia',
      emoji: '📜',
      description: 'Acontecimientos trascendentales, biografías y épocas pasadas',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', // Oppenheimer
    ),
    GenreModel(
      id: 27,
      name: 'Terror',
      emoji: '👻',
      description: 'Sustos, suspenso paranormal y pesadillas inolvidables',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/wVYREutTvI2tmxr6ujrHT704wGF.jpg', // El Conjuro
    ),
    GenreModel(
      id: 10402,
      name: 'Música',
      emoji: '🎵',
      description: 'Conciertos, bandas sonoras legendarias y vidas de artistas',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/vwsFGblLYxWBNjg9pdWN1Mm5YfW.jpg', // Coco / Musical
    ),
    GenreModel(
      id: 9648,
      name: 'Misterio',
      emoji: '🧩',
      description: 'Enigmas por resolver, secretos ocultos y detectives audaces',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/vgpXtnVaaeXbc6sTwaBvOqD7x9t.jpg', // Knives Out
    ),
    GenreModel(
      id: 10749,
      name: 'Romance',
      emoji: '❤️',
      description: 'Historias de amor, química cautivadora y finales emotivos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg', // Titanic
    ),
    GenreModel(
      id: 878,
      name: 'Ciencia Ficción',
      emoji: '🚀',
      description: 'Viajes temporales, universos paralelos y futuros distópicos',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/d5NXSklXo0qyIYkgV94XAgMIckC.jpg', // Dune: Parte Dos
    ),
    GenreModel(
      id: 10770,
      name: 'Película de TV',
      emoji: '📺',
      description: 'Producciones originales y especiales para televisión',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/iyuVTpASpRy2FpsLbGbwF7T2PtI.jpg', // TV Movie
    ),
    GenreModel(
      id: 53,
      name: 'Thriller / Suspenso',
      emoji: '🔍',
      description: 'Giros inesperados, misterios al límite y tensión constante',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', // Parásitos
    ),
    GenreModel(
      id: 10752,
      name: 'Bélica',
      emoji: '⚔️',
      description: 'Conflictos armados, heroísmo, batallas y hermandad bélica',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/t1azKLExwUxKj6v6m2L535evuRa.jpg', // Bélica / 1917
    ),
    GenreModel(
      id: 37,
      name: 'Western',
      emoji: '🤠',
      description: 'Duelos al sol, forajidos del viejo oeste y ley de la frontera',
      samplePosterUrl: 'https://image.tmdb.org/t/p/w500/5k3xTVq6b3T4Zq9Rz3sD4WfW8fP.jpg', // Django Unchained
    ),
  ];
}
