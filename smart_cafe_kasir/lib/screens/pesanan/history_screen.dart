import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pesanan_provider.dart';
import '../../providers/menu_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PesananProvider>().fetchHistory();
      context.read<MenuProvider>().fetchMenus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pesananProvider = context.watch<PesananProvider>();
    final menuProvider = context.watch<MenuProvider>();
    final currencyFormat = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final timeFormat = DateFormat('HH:mm');

    String formatIndonesianDate(DateTime date) {
      final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];

      int dayIndex = date.weekday % 7;
      String dayName = days[dayIndex];
      String monthName = months[date.month - 1];

      return '$dayName, ${date.day} $monthName ${date.year}';
    }

    // Group history by date
    Map<String, List<dynamic>> groupedHistory = {};

    for (var pesanan in pesananProvider.history) {
      DateTime createdDate;
      try {
        if (pesanan.createdAt != null) {
          createdDate = pesanan.createdAt!;
        } else {
          createdDate = DateTime.now();
        }
      } catch (e) {
        print('Error parsing date for pesanan ${pesanan.id}: $e');
        createdDate = DateTime.now();
      }

      String dateKey = DateFormat('yyyy-MM-dd').format(createdDate);
      String displayDate = formatIndonesianDate(createdDate);

      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }

      groupedHistory[dateKey]!.add({
        'pesanan': pesanan,
        'date': createdDate,
        'displayDate': displayDate,
      });
    }

    var sortedDates = groupedHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        backgroundColor: Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PesananProvider>().fetchHistory();
              context.read<MenuProvider>().fetchMenus();
            },
          ),
        ],
      ),
      body: pesananProvider.isLoading || menuProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pesananProvider.history.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat pesanan',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan yang selesai akan muncul di sini',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, dateIndex) {
          String dateKey = sortedDates[dateIndex];
          List<dynamic> pesanansForDate = groupedHistory[dateKey]!;
          String displayDate = pesanansForDate[0]['displayDate'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18, color: Color(0xFF6D4C41)),
                    const SizedBox(width: 8),
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6D4C41),
                      ),
                    ),
                  ],
                ),
              ),
              ...pesanansForDate.map((item) {
                final pesanan = item['pesanan'];
                final DateTime createdDate = item['date'];

                // ✅ Background color berdasarkan tipe
                Color cardColor = pesanan.isTakeAway
                    ? Colors.purple.shade50
                    : Colors.white;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: pesanan.isTakeAway
                          ? Colors.purple.withOpacity(0.3)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                pesanan.isTakeAway
                                    ? Icons.shopping_bag
                                    : Icons.check_circle,
                                color: pesanan.isTakeAway
                                    ? Colors.purple
                                    : Colors.green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pesanan.nomorPesanan,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      // ✅ BADGE TAKE AWAY
                                      if (pesanan.isTakeAway)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.shopping_bag,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'TAKE AWAY',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeFormat.format(createdDate),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // ✅ INFO CUSTOMER ATAU MEJA
                                      if (pesanan.isTakeAway && pesanan.customerName != null)
                                        Row(
                                          children: [
                                            Icon(Icons.person,
                                                size: 14, color: Colors.purple[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              pesanan.customerName!,
                                              style: TextStyle(
                                                color: Colors.purple[600],
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          children: [
                                            Icon(Icons.table_restaurant,
                                                size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Meja ${pesanan.mejaId ?? "-"}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormat.format(pesanan.totalHarga),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: pesanan.isTakeAway
                                    ? Colors.purple
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        ...pesanan.items.map((item) {
                          String menuName = 'Item #${item['menu_id']}';
                          double harga = 0;

                          try {
                            final menu = menuProvider.menus.firstWhere(
                                  (m) => m.id == item['menu_id'],
                            );
                            menuName = menu.nama;
                            harga = menu.harga;
                          } catch (e) {
                            // Menu not found
                          }

                          int qty = item['qty'] ?? 1;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${qty}x',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    menuName,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (harga > 0)
                                  Text(
                                    currencyFormat.format(harga * qty),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.payment,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                pesanan.metodePembayaran.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'SELESAI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}