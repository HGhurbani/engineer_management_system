class MaterialItem {
  final String id;
  final String name;
  final String unit;
  final String imageUrl;

  MaterialItem({required this.id, required this.name, required this.unit, required this.imageUrl});

  factory MaterialItem.fromFirestore(String id, Map<String, dynamic> data) {
    return MaterialItem(
      id: id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'unit': unit, 'imageUrl': imageUrl};
  }
}
