class StreamingProviderModel {
  final int id;
  final String name;
  final String logoPath;
  final String type; // 'flatrate' (streaming suscripción), 'rent' (alquilar), 'buy' (comprar)

  const StreamingProviderModel({
    required this.id,
    required this.name,
    required this.logoPath,
    required this.type,
  });

  String get fullLogoUrl {
    if (logoPath.startsWith('http')) return logoPath;
    return 'https://image.tmdb.org/t/p/w154$logoPath';
  }

  factory StreamingProviderModel.fromJson(Map<String, dynamic> json, {String type = 'flatrate'}) {
    return StreamingProviderModel(
      id: json['provider_id'] as int? ?? json['id'] as int? ?? 0,
      name: json['provider_name'] as String? ?? json['name'] as String? ?? 'Streaming',
      logoPath: json['logo_path'] as String? ?? '',
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_path': logoPath,
      'type': type,
    };
  }
}
