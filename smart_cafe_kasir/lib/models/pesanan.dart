class Pesanan {
  final int? id;
  final String nomorPesanan;
  final List<dynamic> items;
  final double totalHarga;
  final String metodePembayaran;
  final String status;
  final int? mejaId;
  final String? kartuUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? customerName;
  final String? tipe;

  Pesanan({
    this.id,
    required this.nomorPesanan,
    required this.items,
    required this.totalHarga,
    required this.metodePembayaran,
    required this.status,
    this.mejaId,
    this.kartuUid,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.tipe,
  });

  factory Pesanan.fromJson(Map<String, dynamic> json) {
    // ✅ PARSE created_at - FIXED METHOD
    DateTime? parsedCreatedAt;
    try {
      if (json['created_at'] != null) {
        parsedCreatedAt = _parseServerDateTime(json['created_at']);
      }
    } catch (e) {
      print('❌ Error parsing created_at: $e');
      parsedCreatedAt = DateTime.now();
    }

    // ✅ Parse updated_at
    DateTime? parsedUpdatedAt;
    try {
      if (json['updated_at'] != null) {
        parsedUpdatedAt = _parseServerDateTime(json['updated_at']);
      }
    } catch (e) {
      print('❌ Error parsing updated_at: $e');
    }

    // ✅ Parse total_harga
    double parsedTotalHarga = 0.0;
    try {
      if (json['total_harga'] != null) {
        if (json['total_harga'] is String) {
          parsedTotalHarga = double.parse(json['total_harga']);
        } else if (json['total_harga'] is num) {
          parsedTotalHarga = json['total_harga'].toDouble();
        }
      }
    } catch (e) {
      print('❌ Error parsing total_harga: $e');
    }

    // ✅ Parse items
    List<dynamic> parsedItems = [];
    try {
      if (json['items'] != null && json['items'] is List) {
        parsedItems = (json['items'] as List).map((item) {
          if (item is Map<String, dynamic>) {
            return {
              'menu_id': item['menu_id'],
              'qty': item['qty'],
              'notes': item['notes'] ?? '',
            };
          }
          return item;
        }).toList();
      }
    } catch (e) {
      print('❌ Error parsing items: $e');
      parsedItems = json['items'] ?? [];
    }

    return Pesanan(
      id: json['id'],
      nomorPesanan: json['nomor_pesanan'] ?? '',
      items: parsedItems,
      totalHarga: parsedTotalHarga,
      metodePembayaran: json['metode_pembayaran'] ?? '',
      status: json['status'] ?? '',
      mejaId: json['meja_id'],
      kartuUid: json['kartu_uid'],
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      customerName: json['customer_name'],
      tipe: json['tipe'],
    );
  }

  // ✅ ============================================================
  // CRITICAL FIX: Parse datetime dari server (ASSUME UTC)
  // ============================================================
  static DateTime _parseServerDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    String dateString = value.toString().trim();

    try {
      DateTime parsed;

      // Parse berbagai format
      if (dateString.contains('T')) {
        // ISO 8601: "2025-12-09T10:30:00.000000Z"
        parsed = DateTime.parse(dateString);
      } else if (dateString.contains(' ')) {
        // SQL format: "2025-12-09 10:30:00"
        // Replace space dengan 'T' untuk parsing
        dateString = dateString.replaceAll(' ', 'T');
        parsed = DateTime.parse(dateString);
      } else {
        parsed = DateTime.parse(dateString);
      }

      // ✅ KEY FIX: Paksa anggap sebagai UTC, lalu convert ke local
      if (!parsed.isUtc) {
        // Jika tidak ada marker timezone (Z), PAKSA ke UTC dulu
        parsed = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }

      // Convert UTC ke local timezone HP
      final localTime = parsed.toLocal();

      // 🐛 DEBUG (hapus setelah testing)
      print('📅 Server: $dateString → UTC: $parsed → Local: $localTime (${localTime.timeZoneName})');

      return localTime;

    } catch (e) {
      print('❌ Error parsing datetime "$dateString": $e');
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nomor_pesanan': nomorPesanan,
      'items': items,
      'total_harga': totalHarga,
      'metode_pembayaran': metodePembayaran,
      'status': status,
      'meja_id': mejaId,
      'kartu_uid': kartuUid,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'customer_name': customerName,
      'tipe': tipe,
    };
  }

  // ============================================================
  // HELPER METHODS - TIPE PESANAN (TIDAK BERUBAH)
  // ============================================================

  /// Take Away: punya tipe 'takeaway' ATAU customerName tanpa meja & kartu
  bool get isTakeAway {
    if (tipe == 'takeaway') return true;

    if (customerName != null &&
        customerName!.isNotEmpty &&
        mejaId == null &&
        (kartuUid == null || kartuUid!.isEmpty)) {
      return true;
    }

    return false;
  }

  /// Pesanan Baru dengan Kartu: punya kartu tapi bukan take away
  bool get isPesananBaru {
    return !isTakeAway &&
        kartuUid != null &&
        kartuUid!.isNotEmpty &&
        tipe != 'tambah_pesanan';
  }

  /// Tambah Pesanan (kasir pilih meja manual)
  bool get isTambahPesanan {
    if (tipe == 'tambah_pesanan') return true;

    // Fallback: ada meja, tidak ada kartu, tidak ada customer name
    return !isTakeAway &&
        mejaId != null &&
        (kartuUid == null || kartuUid!.isEmpty) &&
        (customerName == null || customerName!.isEmpty);
  }

  /// Dine in dengan kartu (alias isPesananBaru)
  bool get isDineInWithCard => isPesananBaru;

  /// Display info untuk UI (dengan 3 tipe)
  String get displayInfo {
    if (isTakeAway && customerName != null) {
      return 'Take Away - $customerName';
    } else if (isTambahPesanan && mejaId != null) {
      return 'Tambah - Meja $mejaId';
    } else if (isPesananBaru) {
      return 'Baru - Kartu: ${kartuUid!.substring(0, 8)}...';
    } else if (mejaId != null) {
      return 'Meja $mejaId';
    }
    return '-';
  }

  /// Tipe untuk display (3 kategori)
  String get tipePesanan {
    if (isTakeAway) return 'Take Away';
    if (isTambahPesanan) return 'Tambah Pesanan';
    if (isPesananBaru) return 'Pesanan Baru';
    return 'Dine In';
  }
}