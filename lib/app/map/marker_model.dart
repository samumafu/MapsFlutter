class MarkerModel {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;

  MarkerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory MarkerModel.fromJson(Map<String, dynamic> json) {
    return MarkerModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
