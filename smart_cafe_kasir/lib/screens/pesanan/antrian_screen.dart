import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Untuk kDebugMode
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pesanan_provider.dart';
import '../../providers/menu_provider.dart';

class AntrianScreen extends StatefulWidget {
  const AntrianScreen({Key? key}) : super(key: key);

  @override
  State<AntrianScreen> createState() => _AntrianScreenState();
}

class _AntrianScreenState extends State<AntrianScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PesananProvider>().fetchPesanans();
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

    // Group pesanan by date
    Map<String, List<dynamic>> groupedPesanans = {};

    for (var pesanan in pesananProvider.pesanans) {
      DateTime createdDate;
      try {
        if (pesanan.createdAt != null) {
          createdDate = pesanan.createdAt!;

          // ✅ DEBUG: Print timezone info
          if (kDebugMode) {
            print('📅 Display Time for ${pesanan.nomorPesanan}:');
            print('   DateTime: $createdDate');
            print('   Hour: ${createdDate.hour}:${createdDate.minute}');
            print('   Is UTC: ${createdDate.isUtc}');
            print('   Timezone offset: ${createdDate.timeZoneOffset}');
          }
        } else {
          createdDate = DateTime.now();
          if (kDebugMode) {
            print('⚠️ No createdAt, using current time');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error parsing date for pesanan ${pesanan.id}: $e');
        }
        createdDate = DateTime.now();
      }

      String dateKey = DateFormat('yyyy-MM-dd').format(createdDate);
      String displayDate = formatIndonesianDate(createdDate);

      if (!groupedPesanans.containsKey(dateKey)) {
        groupedPesanans[dateKey] = [];
      }

      groupedPesanans[dateKey]!.add({
        'pesanan': pesanan,
        'date': createdDate,
        'displayDate': displayDate,
      });
    }

    var sortedDates = groupedPesanans.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Antrian Pesanan'),
        backgroundColor: Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PesananProvider>().fetchPesanans();
              context.read<MenuProvider>().fetchMenus();
            },
          ),
        ],
      ),
      body: pesananProvider.isLoading || menuProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pesananProvider.pesanans.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada antrian pesanan',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, dateIndex) {
          String dateKey = sortedDates[dateIndex];
          List<dynamic> pesanansForDate = groupedPesanans[dateKey]!;
          String displayDate = pesanansForDate[0]['displayDate'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Color(0xFF6D4C41)),
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

                // ✅ FIXED: Logic untuk menentukan tipe pesanan
                Color statusColor = Colors.grey;
                Color borderColor = Colors.grey;
                IconData statusIcon = Icons.hourglass_empty;
                String pesananType = 'Unknown';
                IconData badgeIcon = Icons.help_outline;

                // 1️⃣ CEK TAKE AWAY DULU (prioritas tertinggi)
                if (pesanan.isTakeAway) {
                  borderColor = Colors.purple;
                  pesananType = 'Take Away';
                  badgeIcon = Icons.shopping_bag;
                }
                // 2️⃣ CEK TAMBAH PESANAN (ada meja + tidak ada kartu + tidak ada customer name)
                else if (pesanan.isTambahPesanan) {
                  borderColor = Colors.orange;
                  pesananType = 'Tambah Pesanan';
                  badgeIcon = Icons.table_restaurant;
                }
                // 3️⃣ CEK PESANAN BARU (ada kartu)
                else if (pesanan.isPesananBaru) {
                  borderColor = Colors.blue;
                  pesananType = 'Pesanan Baru';
                  badgeIcon = Icons.credit_card;
                }
                // 4️⃣ FALLBACK
                else if (pesanan.mejaId != null) {
                  borderColor = Colors.grey;
                  pesananType = 'Dine In';
                  badgeIcon = Icons.table_restaurant;
                }

                // Then determine status color
                switch (pesanan.status) {
                  case 'paid':
                    statusColor = Colors.blue;
                    statusIcon = Icons.payment;
                    break;
                  case 'preparing':
                    statusColor = Colors.orange;
                    statusIcon = Icons.restaurant;
                    break;
                  case 'ready':
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    break;
                  case 'placed':
                    statusColor = Colors.purple;
                    statusIcon = Icons.table_restaurant;
                    break;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 3),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.2),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pesanan.nomorPesanan,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // ✅ BADGE TIPE PESANAN
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                badgeIcon,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pesananType.toUpperCase(),
                                style: const TextStyle(
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              timeFormat.format(createdDate), // ✅ createdDate sudah local
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            // ✅ SHOW APPROPRIATE INFO BASED ON TYPE
                            if (pesanan.isTakeAway && pesanan.customerName != null)
                            // TAKE AWAY: Show customer name
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.person, size: 14, color: Colors.purple[600]),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        pesanan.customerName!,
                                        style: TextStyle(
                                          color: Colors.purple[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (pesanan.mejaId != null)
                            // TAMBAH PESANAN atau DINE IN: Show table number
                              Row(
                                children: [
                                  Icon(
                                      Icons.table_restaurant,
                                      size: 14,
                                      color: pesanan.isTambahPesanan ? Colors.orange[600] : Colors.grey[600]
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Meja ${pesanan.mejaId}',
                                    style: TextStyle(
                                      color: pesanan.isTambahPesanan ? Colors.orange[700] : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: pesanan.isTambahPesanan ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              )
                            else
                            // PENDING: Show dash
                              Row(
                                children: [
                                  Icon(Icons.table_restaurant, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('Meja: -', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pesanan.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              currencyFormat.format(pesanan.totalHarga),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Pesanan
                            Row(
                              children: [
                                Icon(Icons.restaurant_menu, size: 18, color: Colors.grey[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Item Pesanan',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // ✅ SHOW ITEMS WITH NOTES
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
                                if (kDebugMode) {
                                  print('Menu not found: ${item['menu_id']}');
                                }
                              }

                              int qty = item['qty'] ?? 1;
                              String notes = item['notes'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Color(0xFF6D4C41).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${qty}x',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF6D4C41),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                menuName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (harga > 0)
                                                Text(
                                                  '${currencyFormat.format(harga)} x $qty',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (harga > 0)
                                          Text(
                                            currencyFormat.format(harga * qty),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                    // ✅ SHOW NOTES
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.orange.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.note, size: 14, color: Colors.orange),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                notes,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            const Divider(height: 24, thickness: 1),

                            // ACTION BUTTONS
                            Row(
                              children: [
                                Icon(Icons.update, size: 18, color: Colors.grey[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Aksi',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // PREPARING BUTTON
                                if (pesanan.status == 'paid' || pesanan.status == 'placed')
                                  ElevatedButton.icon(
                                    onPressed: () => _updateStatus(context, pesanan.id!, 'preparing'),
                                    icon: const Icon(Icons.restaurant, size: 18),
                                    label: const Text('Mulai Preparing'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 2,
                                    ),
                                  ),

                                // READY BUTTON
                                if (pesanan.status == 'preparing')
                                  ElevatedButton.icon(
                                    onPressed: () => _updateStatus(context, pesanan.id!, 'ready'),
                                    icon: const Icon(Icons.check_circle, size: 18),
                                    label: const Text('Siap'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 2,
                                    ),
                                  ),

                                // COMPLETE BUTTON
                                ElevatedButton.icon(
                                  onPressed: () => _showCompleteDialog(context, pesanan),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Complete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    elevation: 2,
                                  ),
                                ),

                                // CANCEL BUTTON
                                if (pesanan.status != 'ready')
                                  ElevatedButton.icon(
                                    onPressed: () => _showCancelDialog(context, pesanan),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Cancel'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 2,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  void _updateStatus(BuildContext context, int pesananId, String status) async {
    try {
      await context.read<PesananProvider>().updateStatus(pesananId, status);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('✓ Status diupdate ke: ${status.toUpperCase()}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCompleteDialog(BuildContext context, pesanan) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Complete Pesanan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selesaikan pesanan ${pesanan.nomorPesanan}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yang akan dilakukan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Status → Completed'),
                    ],
                  ),
                  if (pesanan.kartuUid != null && pesanan.kartuUid.isNotEmpty)
                    const Row(
                      children: [
                        Icon(Icons.check, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Kartu → Deactivated'),
                      ],
                    ),
                  if (pesanan.mejaId != null)
                    const Row(
                      children: [
                        Icon(Icons.check, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Meja → Kosong'),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await context.read<PesananProvider>().completeOrder(pesanan.id!);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('✓ Pesanan berhasil diselesaikan!'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, pesanan) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Cancel Pesanan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batalkan pesanan ${pesanan.nomorPesanan}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yang akan dilakukan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Status → Cancelled'),
                    ],
                  ),
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Stock → Dikembalikan'),
                    ],
                  ),
                  if (pesanan.kartuUid != null && pesanan.kartuUid.isNotEmpty)
                    const Row(
                      children: [
                        Icon(Icons.check, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Kartu → Deactivated'),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await context.read<PesananProvider>().cancelOrder(pesanan.id!);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('✓ Pesanan berhasil dibatalkan!'),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Pesanan'),
          ),
        ],
      ),
    );
  }
}