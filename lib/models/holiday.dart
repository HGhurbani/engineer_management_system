class Holiday {
  final String name;
  final DateTime date;

  Holiday({required this.name, required this.date});

  factory Holiday.fromMap(Map<String, dynamic> map) {
    return Holiday(
      name: map['name'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date.toIso8601String().split('T').first,
    };
  }
}
