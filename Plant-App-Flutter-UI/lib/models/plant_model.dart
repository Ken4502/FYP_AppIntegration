class Plant {
  final String id;
  final String name;
  final String species;
  final String imageUrl;
  final String description;
  String? iotDeviceId; // Make iotDeviceId optional and mutable

  Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.imageUrl,
    this.description = "",
    this.iotDeviceId,
  });

  Plant copyWith({
    String? id,
    String? name,
    String? species,
    String? imageUrl,
    String? description,
    String? iotDeviceId,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      iotDeviceId: iotDeviceId ?? this.iotDeviceId,
    );
  }
}
