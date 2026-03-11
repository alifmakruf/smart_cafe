class Kartu {
  final int? id;
  final String uid;
  final String status;
  final DateTime? lastUsedAt;

  Kartu({
    this.id,
    required this.uid,
    this.status = 'available',
    this.lastUsedAt,
  });

  factory Kartu.fromJson(Map<String, dynamic> json) {
    return Kartu(
      id: json['id'],
      uid: json['uid'],
      status: json['status'] ?? 'available',
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at']).toLocal()  // ✅ FIX
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'status': status,
    };
  }
}
