import '../../data/models/genre_model.dart';
import '../../data/models/movie_model.dart';

/// Helper inteligente para búsqueda de películas y categorías con:
/// 1. Normalización diacrítica (elimina tildes y acentos como á, é, í, ó, ú, ü, ñ).
/// 2. Diccionario de sinónimos y variaciones coloquiales de géneros cinematográficos.
/// 3. Búsqueda tolerante a mayúsculas, minúsculas y términos populares (ej. "accion", "disparos", "miedo", "scifi").
class SearchDictionaryHelper {
  /// Normaliza una cadena de texto eliminando tildes, diacríticos y espacios sobrantes
  static String normalize(String input) {
    if (input.isEmpty) return '';

    const withDiacritics = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const defaultLetters = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    var result = input;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], defaultLetters[i]);
    }

    return result.toLowerCase().trim();
  }

  /// Diccionario enriquecido que mapea el ID de género de TMDB a múltiples sinónimos,
  /// términos coloquiales, faltas comunes de ortografía (sin tilde) y traducciones.
  static final Map<int, List<String>> genreDictionary = {
    // ACCIÓN (28)
    28: [
      'accion',
      'action',
      'tiros',
      'disparos',
      'balas',
      'balacera',
      'peleas',
      'pelea',
      'combate',
      'artes marciales',
      'golpes',
      'pistolas',
      'armas',
      'explosiones',
      'persecucion',
      'persecuciones',
      'adrenalina',
      'guerreros',
    ],

    // COMEDIA (35)
    35: [
      'comedia',
      'comedy',
      'humor',
      'chiste',
      'chistes',
      'chistosa',
      'chistoso',
      'graciosa',
      'gracioso',
      'divertida',
      'divertido',
      'risa',
      'risas',
      'carcajadas',
      'comico',
      'comica',
    ],

    // TERROR (27)
    27: [
      'terror',
      'horror',
      'miedo',
      'susto',
      'sustos',
      'aterrador',
      'aterradora',
      'escalofrio',
      'escalofrios',
      'paranormal',
      'fantasmas',
      'fantasma',
      'demonio',
      'demonios',
      'posesion',
      'espanto',
      'pesadilla',
      'pesadillas',
      'scary',
      'spooky',
      'gore',
      'sangre',
      'slasher',
      'brujeria',
    ],

    // CIENCIA FICCIÓN (878)
    878: [
      'ciencia ficcion',
      'scifi',
      'sci-fi',
      'sci fi',
      'cifi',
      'ci-fi',
      'ci fi',
      'ficcion',
      'futuro',
      'futurista',
      'espacio',
      'espacial',
      'alien',
      'aliens',
      'extraterrestres',
      'extraterrestre',
      'ovni',
      'ovnis',
      'multiverso',
      'galaxia',
      'galaxias',
      'viaje temporal',
      'viajes en el tiempo',
      'ia',
      'inteligencia artificial',
      'robot',
      'robots',
      'androide',
      'distopia',
      'distopico',
      'distopica',
      'science fiction',
    ],

    // DRAMA (18)
    18: [
      'drama',
      'dramatica',
      'dramatico',
      'triste',
      'tristeza',
      'llorar',
      'lagrimas',
      'conmovedor',
      'conmovedora',
      'emotivo',
      'emotiva',
      'seria',
      'serio',
      'profunda',
      'profundo',
      'reflexion',
      'historias reales',
      'superacion',
    ],

    // ROMANCE (10749)
    10749: [
      'romance',
      'romantica',
      'romantico',
      'amor',
      'desamor',
      'pareja',
      'parejas',
      'enamorados',
      'enamoramiento',
      'novios',
      'boda',
      'corazon',
      'sentimientos',
      'pasion',
      'romantic',
      'love',
    ],

    // ANIMACIÓN (16)
    16: [
      'animacion',
      'animada',
      'animadas',
      'animado',
      'animados',
      'dibujos',
      'dibujos animados',
      'caricatura',
      'caricaturas',
      'cartoon',
      'cartoons',
      'anime',
      'infantil',
      'ninos',
      'pixar',
      'disney',
      'animation',
    ],

    // THRILLER / SUSPENSO (53)
    53: [
      'thriller',
      'triller',
      'suspenso',
      'suspense',
      'misterio',
      'intriga',
      'tension',
      'detective',
      'detectives',
      'policial',
      'crimen',
      'crimenes',
      'asesino',
      'asesinos',
      'investigacion',
      'psicologico',
      'giro',
      'giro inesperado',
    ],

    // FANTASÍA (14)
    14: [
      'fantasia',
      'magia',
      'magica',
      'magico',
      'hechicero',
      'hechiceros',
      'hechizos',
      'bruja',
      'brujas',
      'dragon',
      'dragones',
      'mitologia',
      'mitologico',
      'criaturas',
      'reinos',
      'hadas',
      'espadas',
      'fantasy',
    ],

    // AVENTURA (12)
    12: [
      'aventura',
      'aventuras',
      'adventure',
      'viaje',
      'viajes',
      'expedicion',
      'exploracion',
      'explorar',
      'tesoro',
      'tesoros',
      'supervivencia',
      'selva',
      'naufragio',
      'odisea',
      'odiseas',
    ],
  };

  /// Detecta si el texto buscado coincide con algún género del diccionario
  static List<int> matchGenreIds(String query) {
    final normQuery = normalize(query);
    if (normQuery.isEmpty) return [];

    final matched = <int>{};
    for (final entry in genreDictionary.entries) {
      final genreId = entry.key;
      final synonyms = entry.value;

      for (final syn in synonyms) {
        if (normQuery == syn || normQuery.contains(syn) || syn.contains(normQuery)) {
          matched.add(genreId);
          break;
        }
      }
    }
    return matched.toList();
  }

  /// Retorna el primer modelo de género coincidente si el usuario buscó una categoría
  static GenreModel? detectGenre(String query) {
    final matchedIds = matchGenreIds(query);
    if (matchedIds.isEmpty) return null;

    final targetId = matchedIds.first;
    try {
      return GenreModel.defaultGenres.firstWhere((g) => g.id == targetId);
    } catch (_) {
      return null;
    }
  }

  /// Filtra un catálogo de películas aplicando:
  /// 1. Coincidencia por género en el diccionario (ej. "accion", "tiros", "miedo", "scifi").
  /// 2. Coincidencia por título normalizado (sin tildes ni mayúsculas).
  /// 3. Coincidencia por sinopsis o etiqueta normalizada.
  static List<MovieModel> searchMovies({
    required List<MovieModel> catalog,
    required String query,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return catalog;

    final normQuery = normalize(trimmed);
    final matchedGenreIds = matchGenreIds(normQuery);

    final results = <MovieModel>[];
    final seenIds = <int>{};

    for (final movie in catalog) {
      bool isMatch = false;

      // 1. Coincide con alguno de los géneros identificados por el diccionario
      if (matchedGenreIds.isNotEmpty && movie.genreIds.any((id) => matchedGenreIds.contains(id))) {
        isMatch = true;
      }

      // 2. Coincide con el título normalizado
      if (!isMatch && normalize(movie.title).contains(normQuery)) {
        isMatch = true;
      }

      // 3. Coincide con alguno de los nombres de género textuales de la película
      if (!isMatch && movie.genres.any((g) => normalize(g).contains(normQuery))) {
        isMatch = true;
      }

      // 4. Coincide con la sinopsis normalizada
      if (!isMatch && normalize(movie.overview).contains(normQuery)) {
        isMatch = true;
      }

      // 5. Coincide con el lema (tagline)
      if (!isMatch && movie.tagline != null && normalize(movie.tagline!).contains(normQuery)) {
        isMatch = true;
      }

      if (isMatch && !seenIds.contains(movie.id)) {
        seenIds.add(movie.id);
        results.add(movie);
      }
    }

    return results;
  }
}
