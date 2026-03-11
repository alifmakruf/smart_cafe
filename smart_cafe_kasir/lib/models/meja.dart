class Meja {
  final int? id;
  final int nomorMeja;
  final int kapasitas;
  final String status;
  final String? esp8266Id;

  Meja({
    this.id,
    required this.nomorMeja,
    this.kapasitas = 4,
    this.status = 'kosong',
    this.esp8266Id,
  });

  factory Meja.fromJson(Map<String, dynamic> json) {
    return Meja(
      id: json['id'],
      nomorMeja: json['nomor_meja'],
      kapasitas: json['kapasitas'] ?? 4,
      status: json['status'] ?? 'kosong',
      esp8266Id: json['esp8266_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nomor_meja': nomorMeja,
      'kapasitas': kapasitas,
      'status': status,
      'esp8266_id': esp8266Id,
    };
  }
}