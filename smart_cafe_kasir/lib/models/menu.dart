class Menu {
  final int? id;
  final String nama;
  final double harga;
  final String? kategori;
  final String? gambar;
  final int stok;
  final bool aktif;

  Menu({
    this.id,
    required this.nama,
    required this.harga,
    this.kategori,
    this.gambar,
    this.stok = 999,
    this.aktif = true,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'],
      nama: json['nama'],
      harga: double.parse(json['harga'].toString()),
      kategori: json['kategori'],
      gambar: json['gambar'],
      stok: json['stok'] ?? 999,
      aktif: json['aktif'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama': nama,
      'harga': harga,
      'kategori': kategori,
      'gambar': gambar,
      'stok': stok,
      'aktif': aktif,
    };
  }
}