class ReviewModel {
  final String id;
  final String author;
  final String avatarUrl;
  final String content;
  final double rating;
  final bool isPositive;
  final int likesCount;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.author,
    required this.avatarUrl,
    required this.content,
    required this.rating,
    required this.isPositive,
    required this.likesCount,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      author: json['author'] as String? ?? 'Anónimo',
      avatarUrl: json['author_details']?['avatar_path'] != null
          ? 'https://image.tmdb.org/t/p/w185${json['author_details']['avatar_path']}'
          : (json['avatar_url'] as String? ?? ''),
      content: json['content'] as String? ?? '',
      rating: ((json['author_details']?['rating'] ?? json['rating'] ?? 8) as num).toDouble(),
      isPositive: json['is_positive'] as bool? ??
          (((json['author_details']?['rating'] ?? json['rating'] ?? 8) as num) >= 7.0),
      likesCount: json['likes_count'] as int? ?? 142,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'avatar_url': avatarUrl,
      'content': content,
      'rating': rating,
      'is_positive': isPositive,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
