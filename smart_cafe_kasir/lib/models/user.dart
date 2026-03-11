class User {
  final int id;
  final String nama;
  final String posisi;
  final bool isActive;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.nama,
    required this.posisi,
    this.isActive = true,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nama: json['nama'],
      posisi: json['posisi'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'posisi': posisi,
      'is_active': isActive,
    };
  }

  // Helper methods
  bool get isAdmin => posisi == 'admin';
  bool get isKasir => posisi == 'kasir';
  bool get isKitchen => posisi == 'kitchen';

  // Display name untuk posisi
  String get posisiDisplay {
    switch (posisi) {
      case 'admin':
        return 'Administrator';
      case 'kasir':
        return 'Kasir';
      case 'kitchen':
        return 'Kitchen';
      default:
        return posisi;
    }
  }
}