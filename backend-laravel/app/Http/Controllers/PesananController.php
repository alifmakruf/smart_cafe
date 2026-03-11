<?php

namespace App\Http\Controllers;

use App\Models\Pesanan;
use App\Models\Kartu;
use App\Models\Meja;
use App\Models\Menu;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PesananController extends Controller
{
    public function index()
    {
        try {
            $pesanans = Pesanan::with(['meja', 'kartu'])
                ->whereIn('status', ['paid', 'preparing', 'ready', 'placed'])
                ->orderBy('created_at', 'desc')
                ->get()
                ->map(function ($pesanan) {
                    // ✅ Force timezone ke Asia/Jakarta
                    $pesanan->created_at = $pesanan->created_at->setTimezone('Asia/Jakarta');
                    $pesanan->updated_at = $pesanan->updated_at->setTimezone('Asia/Jakarta');
                    return $pesanan;
                });

            Log::info('Fetched pesanans', [
                'count' => $pesanans->count(),
                'ids' => $pesanans->pluck('id')->toArray()
            ]);

            return response()->json($pesanans);
            
        } catch (\Exception $e) {
            Log::error('Error fetching pesanans', ['error' => $e->getMessage()]);
            return response()->json(['error' => 'Failed to fetch pesanans'], 500);
        }
}

   public function store(Request $request)
    {
        try {
            $validated = $request->validate([
                'items' => 'required|array|min:1',
                'items.*.menu_id' => 'required|integer|exists:menus,id',
                'items.*.qty' => 'required|integer|min:1',
                'items.*.notes' => 'nullable|string',
                'total_harga' => 'required|numeric|min:0',
                'metode_pembayaran' => 'required|in:cash,qris',
                'customer_name' => 'nullable|string',
                'tipe' => 'nullable|in:takeaway,dine_in,tambah_pesanan',
                'existing_pesanan_id' => 'nullable|integer|exists:pesanans,id' // for tambah_pesanan
            ]);

            DB::beginTransaction();

            try {
                // jika tambah_pesanan dan ada existing_pesanan_id, merge items
                if (($validated['tipe'] ?? null) === 'tambah_pesanan' && !empty($validated['existing_pesanan_id'])) {
                    $pesanan = Pesanan::findOrFail($validated['existing_pesanan_id']);

                    // hanya boleh tambah jika pesanan belum completed/cancelled
                    if (in_array($pesanan->status, ['completed', 'cancelled'])) {
                        DB::rollBack();
                        return response()->json([
                            'success' => false,
                            'message' => 'Tidak dapat menambah ke pesanan yang sudah selesai atau dibatalkan'
                        ], 400);
                    }

                    $currentItems = $pesanan->items ?? [];
                    // merge: jika menu_id sama, tambahkan qty
                    foreach ($validated['items'] as $newItem) {
                        $found = false;
                        foreach ($currentItems as &$cur) {
                            if ($cur['menu_id'] == $newItem['menu_id']) {
                                $cur['qty'] += $newItem['qty'];
                                // merge notes
                                $cur['notes'] = trim(($cur['notes'] ?? '') . ' ' . ($newItem['notes'] ?? ''));
                                $found = true;
                                break;
                            }
                        }
                        if (!$found) $currentItems[] = $newItem;
                    }
                    $pesanan->update([
                        'items' => $currentItems,
                        'total_harga' => $validated['total_harga'] ?? $pesanan->total_harga + 0
                    ]);

                    DB::commit();

                    Log::info('Pesanan updated (tambah_pesanan)', ['pesanan_id' => $pesanan->id]);

                    return response()->json($pesanan->fresh(), 200);
                }

                // Biasa: create baru
                $pesanan = Pesanan::create([
                    'nomor_pesanan' => 'ORD-' . strtoupper(Str::random(8)),
                    'items' => $validated['items'],
                    'total_harga' => $validated['total_harga'],
                    'metode_pembayaran' => $validated['metode_pembayaran'],
                    'customer_name' => $validated['customer_name'] ?? null,
                    'tipe' => $validated['tipe'] ?? null,
                    'status' => 'pending'
                ]);

                DB::commit();

                Log::info('Pesanan created (pending)', [
                    'pesanan_id' => $pesanan->id,
                ]);

                return response()->json($pesanan, 201);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Error creating pesanan', ['error' => $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'Gagal membuat pesanan',
                'error' => $e->getMessage()
            ], 500);
        }
}


   public function linkKartu(Request $request, $id)
    {
        try {
            $pesanan = Pesanan::findOrFail($id);

            $validated = $request->validate([
                'kartu_uid' => 'required|string'
            ]);

            $kartuUid = strtoupper($validated['kartu_uid']);

            Log::info('Linking kartu', [
                'pesanan_id' => $id,
                'kartu_uid' => $kartuUid
            ]);

            DB::beginTransaction();

            try {
                $kartu = Kartu::where('uid', $kartuUid)->first();

                if (!$kartu) {
                    $kartu = Kartu::create([
                        'uid' => $kartuUid,
                        'status' => 'available'
                    ]);
                    Log::info('New card auto-registered', ['uid' => $kartuUid]);
                }

                // Allow re-link for same pesanan (idempotency)
                if ($pesanan->kartu_uid === $kartuUid && $pesanan->status === 'paid') {
                    DB::rollBack();
                    return response()->json([
                        'success' => true,
                        'message' => 'Kartu sudah di-link ke pesanan ini',
                        'data' => $pesanan
                    ], 200);
                }

                // Check if card used by other active order
                $otherActivePesanan = Pesanan::where('kartu_uid', $kartuUid)
                    ->where('id', '!=', $id)
                    ->whereNotIn('status', ['completed', 'cancelled'])
                    ->first();

                if ($otherActivePesanan) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Kartu sedang digunakan oleh pesanan {$otherActivePesanan->nomor_pesanan}"
                    ], 400);
                }

                // SILENT stock update: use row locking to avoid race
                foreach ($pesanan->items as $item) {
                    // lock menu row
                    $menu = Menu::lockForUpdate()->find($item['menu_id']);
                    if (!$menu) {
                        DB::rollBack();
                        return response()->json(['success' => false, 'message' => "Menu tidak ditemukan"], 404);
                    }

                    // If pesanan already paid earlier we shouldn't reduce again (idempotency)
                    // We'll check pesanan->status: only reduce stock when transitioning to 'paid'
                    if ($pesanan->status !== 'paid') {
                        if ($menu->stok < $item['qty']) {
                            DB::rollBack();
                            return response()->json([
                                'success' => false,
                                'message' => "Stock menu '{$menu->nama}' tidak cukup"
                            ], 400);
                        }
                        // decrement with Eloquent to avoid race
                        $menu->decrement('stok', $item['qty']);
                        Log::info("Stock decremented: {$menu->nama} by {$item['qty']}");
                    }
                }

                // update pesanan + kartu
                $pesanan->update([
                    'kartu_uid' => $kartuUid,
                    'status' => 'paid'
                ]);

                $kartu->update([
                    'status' => 'running',
                    'last_used_at' => now()
                ]);

                DB::commit();

                Log::info('Kartu linked and order confirmed', [
                    'pesanan_id' => $pesanan->id,
                ]);

                return response()->json([
                    'success' => true,
                    'message' => 'Kartu berhasil di-link dan pesanan dikonfirmasi',
                    'data' => $pesanan->fresh()
                ]);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Error linking kartu', ['error' => $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'Gagal link kartu',
                'error' => $e->getMessage()
            ], 500);
        }
    }


    // File: app/Http/Controllers/PesananController.php

/**
 * ✅ FIX: Method assignMeja()
 * Allow assigning to "terisi" meja for "tambah_pesanan" type
 */
    public function assignMeja(Request $request, $id)
    {
        $validated = $request->validate([
            'meja_id' => 'required|integer',
            'tipe' => 'nullable|string', // ✅ NEW: tipe field
        ]);

        try {
            DB::beginTransaction();

            $pesanan = Pesanan::findOrFail($id);
            $mejaId = $validated['meja_id'];
            $tipe = $validated['tipe'] ?? null;

            // Find meja by nomor_meja (input from kasir)
            $meja = Meja::where('nomor_meja', $mejaId)->first();

            if (!$meja) {
                DB::rollBack();
                return response()->json([
                    'success' => false,
                    'message' => "Meja $mejaId tidak ditemukan"
                ], 404);
            }

            // ✅ KEY FIX: Allow "terisi" meja for "tambah_pesanan"
            if ($tipe === 'tambah_pesanan') {
                // ✅ TAMBAH PESANAN: Boleh assign ke meja yang sudah terisi
                if ($meja->status === 'offline') {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Meja $mejaId sedang offline"
                    ], 400);
                }

                // Update pesanan
                $pesanan->meja_id = $meja->id;
                $pesanan->tipe = 'tambah_pesanan';
                $pesanan->status = 'paid'; // ✅ Langsung paid (seperti take away)
                $pesanan->save();

                // ✅ JANGAN update status meja (biarkan tetap "terisi")

                DB::commit();

                return response()->json([
                    'success' => true,
                    'message' => "Pesanan ditambahkan ke Meja {$meja->nomor_meja}",
                    'data' => [
                        'id' => $pesanan->id,
                        'nomor_pesanan' => $pesanan->nomor_pesanan,
                        'meja_id' => $pesanan->meja_id,
                        'nomor_meja' => $meja->nomor_meja,
                        'tipe' => $pesanan->tipe,
                        'status' => $pesanan->status,
                        'total_harga' => $pesanan->total_harga,
                        'metode_pembayaran' => $pesanan->metode_pembayaran,
                        'items' => $pesanan->items,
                        'created_at' => $pesanan->created_at,
                        'updated_at' => $pesanan->updated_at,
                    ],
                ]);

            } else {
                // ✅ PESANAN BARU: Check meja harus kosong
                if ($meja->status !== 'kosong') {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Meja {$meja->nomor_meja} sedang terisi"
                    ], 400);
                }

                // Update pesanan
                $pesanan->meja_id = $meja->id;
                $pesanan->status = 'paid';
                $pesanan->save();

                // Update meja status
                $meja->status = 'terisi';
                $meja->save();

                DB::commit();

                return response()->json([
                    'success' => true,
                    'message' => "Pesanan berhasil di-assign ke Meja {$meja->nomor_meja}",
                    'data' => [
                        'id' => $pesanan->id,
                        'nomor_pesanan' => $pesanan->nomor_pesanan,
                        'meja_id' => $pesanan->meja_id,
                        'nomor_meja' => $meja->nomor_meja,
                        'tipe' => $pesanan->tipe,
                        'status' => $pesanan->status,
                        'total_harga' => $pesanan->total_harga,
                        'metode_pembayaran' => $pesanan->metode_pembayaran,
                        'items' => $pesanan->items,
                        'created_at' => $pesanan->created_at,
                        'updated_at' => $pesanan->updated_at,
                    ],
                ]);
            }

        } catch (\Exception $e) {
            DB::rollBack();
            \Log::error('Assign meja error: ' . $e->getMessage());

            return response()->json([
                'success' => false,
                'message' => 'Gagal assign meja: ' . $e->getMessage()
            ], 500);
        }
}

    public function updateStatus(Request $request, $id)
    {
        try {
            $pesanan = Pesanan::findOrFail($id);
            
            $validated = $request->validate([
                'status' => 'required|in:paid,preparing,ready,placed,completed,cancelled'
            ]);
            
            $oldStatus = $pesanan->status;
            $newStatus = $validated['status'];
            
            Log::info('Updating pesanan status', [
                'pesanan_id' => $id,
                'old_status' => $oldStatus,
                'new_status' => $newStatus
            ]);

            DB::beginTransaction();

            try {
                $pesanan->update(['status' => $newStatus]);

                if (in_array($newStatus, ['completed', 'cancelled'])) {
                    
                    if ($pesanan->meja) {
                        $pesanan->meja->update(['status' => 'kosong']);
                        Log::info('Table reset to empty', [
                            'meja_id' => $pesanan->meja->id
                        ]);
                    }
                    
                    if ($newStatus === 'cancelled' && $oldStatus !== 'cancelled') {
                        foreach ($pesanan->items as $item) {
                            $menu = Menu::find($item['menu_id']);
                            if ($menu) {
                                $oldStock = $menu->stok;
                                $menu->increment('stok', $item['qty']);
                                
                                Log::info('Stock restored', [
                                    'menu' => $menu->nama,
                                    'old_stock' => $oldStock,
                                    'new_stock' => $menu->fresh()->stok,
                                    'qty_restored' => $item['qty']
                                ]);
                            }
                        }
                    }
                    
                    Log::info('Pesanan ' . $newStatus . ', resources released', [
                        'pesanan_id' => $pesanan->id
                    ]);
                }

                DB::commit();

                return response()->json([
                    'success' => true,
                    'message' => 'Status berhasil diupdate',
                    'data' => $pesanan->fresh(['meja', 'kartu'])
                ]);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Error updating status', [
                'error' => $e->getMessage(),
                'pesanan_id' => $id
            ]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal update status',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    public function show($id)
    {
        try {
            $pesanan = Pesanan::with(['meja', 'kartu'])->findOrFail($id);
            return response()->json($pesanan);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Pesanan tidak ditemukan'
            ], 404);
        }
    }

    public function history()
    {
        try {
            $history = Pesanan::with(['meja', 'kartu'])
                ->where('status', 'completed')
                ->orderBy('updated_at', 'desc')
                ->get();

            Log::info('History fetched', ['count' => $history->count()]);

            return response()->json($history);
            
        } catch (\Exception $e) {
            Log::error('Error fetching history', ['error' => $e->getMessage()]);
            return response()->json(['error' => 'Failed to fetch history'], 500);
        }
    }

    /**
     * ✅ DEACTIVATE CARD = COMPLETE ORDER
     * Pesanan jadi completed, kartu available, meja kosong
     */
    public function deactivateCard(Request $request)
    {
        try {
            $validated = $request->validate([
                'kartu_uid' => 'required|string'
            ]);

            $kartuUid = strtoupper($validated['kartu_uid']);

            Log::info('Deactivating card & completing order', ['uid' => $kartuUid]);

            DB::beginTransaction();

            try {
                $kartu = Kartu::where('uid', $kartuUid)->first();
                
                if (!$kartu) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => 'Kartu tidak ditemukan'
                    ], 404);
                }
                
                if (!in_array($kartu->status, ['running', 'in_use'])) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Kartu tidak dapat dinonaktifkan (status: {$kartu->status})"
                    ], 400);
                }
                
                // Find pesanan aktif dengan kartu ini
                $pesanan = Pesanan::where('kartu_uid', $kartuUid)
                    ->where('status', '!=', 'completed')
                    ->where('status', '!=', 'cancelled')
                    ->first();
                
                // ✅ SET PESANAN JADI COMPLETED
                if ($pesanan) {
                    $pesanan->update(['status' => 'completed']);
                    Log::info('Pesanan completed', ['pesanan_id' => $pesanan->id]);
                }
                
                // ✅ RESET MEJA
                if ($pesanan && $pesanan->meja) {
                    $pesanan->meja->update(['status' => 'kosong']);
                    Log::info('Table reset', ['meja_id' => $pesanan->meja->id]);
                }
                
                // ✅ KARTU AVAILABLE (bisa dipakai lagi)
                $kartu->update([
                    'status' => 'available',
                    'last_used_at' => now()
                ]);
                
                DB::commit();

                Log::info('Card deactivated & order completed', [
                    'uid' => $kartuUid,
                    'pesanan_id' => $pesanan?->id,
                    'pesanan_status' => 'completed'
                ]);

                return response()->json([
                    'success' => true,
                    'message' => 'Kartu dinonaktifkan dan pesanan diselesaikan',
                    'data' => [
                        'kartu_uid' => $kartuUid,
                        'kartu_status' => 'available',
                        'pesanan_id' => $pesanan?->id,
                        'pesanan_status' => 'completed',
                        'nomor_pesanan' => $pesanan?->nomor_pesanan
                    ]
                ]);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Error deactivating card', ['error' => $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'Gagal menonaktifkan kartu',
                'error' => $e->getMessage()
            ], 500);
        }
    }

   public function checkTableOrder($table_id)
    {
        try {
            // Cari pesanan aktif untuk meja ini (status bukan completed/cancelled)
            $pesanan = Pesanan::where('meja_id', $table_id)
                ->whereIn('status', ['paid', 'placed', 'preparing', 'ready'])
                ->orderBy('created_at', 'desc')
                ->first();
            
            if ($pesanan) {
                \Log::info('ESP Check Table Order:', [
                    'table_id' => $table_id,
                    'order_id' => $pesanan->id,
                    'status' => $pesanan->status,
                    'found' => true
                ]);
                
                return response()->json([
                    'success' => true,
                    'has_order' => true,
                    'order_id' => $pesanan->id,
                    'status' => $pesanan->status,
                    'table_id' => $table_id,
                    'nomor_pesanan' => $pesanan->nomor_pesanan
                ]);
            } else {
                \Log::info('ESP Check Table Order:', [
                    'table_id' => $table_id,
                    'found' => false
                ]);
                
                return response()->json([
                    'success' => true,
                    'has_order' => false,
                    'table_id' => $table_id
                ]);
            }
        } catch (\Exception $e) {
            \Log::error('Check Table Order Error:', [
                'table_id' => $table_id,
                'error' => $e->getMessage()
            ]);
            
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'has_order' => false
            ], 500);
        }
    }

}