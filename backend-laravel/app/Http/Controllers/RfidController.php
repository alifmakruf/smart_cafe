<?php

namespace App\Http\Controllers;

use App\Models\Pesanan;
use App\Models\Meja;
use App\Models\Kartu;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class RfidController extends Controller
{
    /**
     * Endpoint untuk aktivasi meja dari ESP8266
     * POST /api/rfid/activate-table
     */
    public function activateTable(Request $request)
    {
        try {
            $validated = $request->validate([
                'card_uid' => 'required|string',
                'table_id' => 'required|integer|exists:mejas,id'
            ]);

            $cardUid = strtoupper($validated['card_uid']);
            $tableId = $validated['table_id'];

            Log::info('ESP Meja: Activate table', [
                'card_uid' => $cardUid,
                'table_id' => $tableId
            ]);

            DB::beginTransaction();

            try {
                // Check kartu exists and status = 'running'
                $kartu = Kartu::where('uid', $cardUid)->first();
                
                if (!$kartu) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => 'Kartu tidak terdaftar',
                        'error' => 'CARD_NOT_REGISTERED'
                    ], 404);
                }
                
                if ($kartu->status !== 'running') {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Kartu tidak aktif (status: {$kartu->status})",
                        'error' => 'CARD_NOT_RUNNING'
                    ], 400);
                }

                // Find pesanan dengan kartu ini (status paid)
                $pesanan = Pesanan::where('kartu_uid', $cardUid)
                    ->where('status', 'paid')
                    ->first();

                if (!$pesanan) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => 'Tidak ada pesanan untuk kartu ini',
                        'error' => 'NO_ORDER_FOUND'
                    ], 404);
                }

                // Check meja
                $meja = Meja::find($tableId);
                
                if (!$meja) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => 'Meja tidak ditemukan'
                    ], 404);
                }

                // Assign meja ke pesanan
                $pesanan->update([
                    'meja_id' => $tableId,
                    'status' => 'placed'  // ← GANTI dari 'served' ke 'placed'
                ]);

                // Update meja status
                $meja->update(['status' => 'terisi']);

                // Update kartu status: running → in_use
                $kartu->update([
                    'status' => 'in_use',
                    'last_used_at' => now()
                ]);

                DB::commit();

                Log::info('Table activated successfully', [
                    'pesanan_id' => $pesanan->id,
                    'meja_id' => $tableId,
                    'kartu_status' => 'in_use'
                ]);

                return response()->json([
                    'success' => true,
                    'message' => 'Meja berhasil diaktifkan',
                    'data' => [
                        'pesanan_id' => $pesanan->id,
                        'nomor_pesanan' => $pesanan->nomor_pesanan,
                        'meja_id' => $meja->id,
                        'nomor_meja' => $meja->nomor_meja
                    ]
                ]);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Error activating table', ['error' => $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'Gagal aktivasi meja',
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Endpoint untuk deaktivasi meja (kartu dilepas)
     * POST /api/rfid/deactivate-table
     */
    public function deactivateTable(Request $request)
    {
        try {
            $validated = $request->validate([
                'card_uid' => 'required|string',
                'table_id' => 'required|integer|exists:mejas,id'
            ]);

            $cardUid = strtoupper($validated['card_uid']);
            $tableId = $validated['table_id'];

            Log::info("RFID Deactivation Request", [
                'card_uid' => $cardUid,
                'table_id' => $tableId
            ]);

            DB::beginTransaction();

            try {
                // Cari pesanan aktif
                $pesanan = Pesanan::where('kartu_uid', $cardUid)
                    ->where('meja_id', $tableId)
                    ->whereIn('status', ['preparing', 'ready', 'placed'])
                    ->first();

                if (!$pesanan) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => 'Tidak ada pesanan aktif untuk meja ini',
                        'error' => 'NO_ACTIVE_ORDER'
                    ], 404);
                }

                // Reset meja
                $meja = Meja::findOrFail($tableId);
                $meja->update(['status' => 'kosong']);

                // Release kartu
                $kartu = Kartu::where('uid', $cardUid)->first();
                if ($kartu) {
                    $kartu->update([
                        'status' => 'available',
                        'last_used_at' => now()
                    ]);
                }

                DB::commit();

                Log::info("Table deactivated successfully", [
                    'pesanan_id' => $pesanan->id,
                    'meja_id' => $meja->id,
                    'kartu_status' => 'available'
                ]);

                return response()->json([
                    'success' => true,
                    'message' => 'Meja berhasil dinonaktifkan',
                    'data' => [
                        'pesanan_id' => $pesanan->id,
                        'meja_nomor' => $meja->nomor_meja,
                        'kartu_status' => 'available'
                    ]
                ], 200);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error("RFID Deactivation Error", [
                'error' => $e->getMessage()
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan server',
                'error' => 'INTERNAL_ERROR'
            ], 500);
        }
    }

    /**
     * NEW: Endpoint untuk ESP cek status kartu
     * GET /api/rfid/check-card/{card_uid}
     */
    public function checkCardStatus($cardUid)
    {
        try {
            $cardUid = strtoupper($cardUid);
            
            Log::info('ESP: Checking card status', ['uid' => $cardUid]);
            
            $kartu = Kartu::where('uid', $cardUid)->first();
            
            if (!$kartu) {
                return response()->json([
                    'success' => false,
                    'message' => 'Kartu tidak ditemukan',
                    'status' => 'not_found',
                    'session_valid' => false
                ], 404);
            }
            
            // ✅ Session valid jika kartu dalam status 'running' atau 'in_use'
            $sessionValid = in_array($kartu->status, ['running', 'in_use']);
            
            Log::info('ESP Card status checked', [
                'uid' => $cardUid,
                'status' => $kartu->status,
                'session_valid' => $sessionValid
            ]);
            
            // ✅ RESPONSE LANGSUNG TANPA WRAPPER "data" untuk ESP
            return response()->json([
                'success' => true,
                'message' => 'Status kartu',
                'status' => $kartu->status,              // ← Di root level
                'session_valid' => $sessionValid,        // ← Di root level
                'uid' => $kartu->uid,
                'last_used_at' => $kartu->last_used_at
            ], 200);
            
        } catch (\Exception $e) {
            Log::error('Error checking card status', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal cek status kartu',
                'status' => 'error',
                'session_valid' => false,
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Endpoint untuk scan kartu di kasir
     * POST /api/rfid/kasir-scan
     */
    public function kasirScan(Request $request)
    {
        try {
            $validated = $request->validate([
                'card_uid' => 'required|string'
            ]);

            $cardUid = strtoupper($validated['card_uid']);

            Log::info("Kasir RFID Scan", ['card_uid' => $cardUid]);

            $kartu = Kartu::where('uid', $cardUid)->first();

            if (!$kartu) {
                // Auto-register kartu baru
                $kartu = Kartu::create([
                    'uid' => $cardUid,
                    'status' => 'available'
                ]);

                Log::info("New card auto-registered", ['card_uid' => $cardUid]);
            }

            if ($kartu->status !== 'available') {
                return response()->json([
                    'success' => false,
                    'message' => "Kartu sedang digunakan (status: {$kartu->status})",
                    'error' => 'CARD_IN_USE',
                    'data' => [
                        'uid' => $kartu->uid,
                        'status' => $kartu->status
                    ]
                ], 400);
            }

            return response()->json([
                'success' => true,
                'message' => 'Kartu siap digunakan',
                'data' => [
                    'uid' => $kartu->uid,
                    'status' => $kartu->status,
                    'last_used_at' => $kartu->last_used_at
                ]
            ], 200);

        } catch (\Exception $e) {
            Log::error("Kasir Scan Error", ['error' => $e->getMessage()]);

            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan server',
                'error' => 'INTERNAL_ERROR'
            ], 500);
        }
    }

    /**
     * Endpoint untuk cek status meja
     * GET /api/rfid/table-status/{table_id}
     */
    public function tableStatus($tableId)
    {
        try {
            $meja = Meja::with(['pesananAktif'])->findOrFail($tableId);

            return response()->json([
                'success' => true,
                'data' => [
                    'meja_id' => $meja->id,
                    'nomor_meja' => $meja->nomor_meja,
                    'status' => $meja->status,
                    'pesanan_aktif' => $meja->pesananAktif
                ]
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Meja tidak ditemukan',
                'error' => 'TABLE_NOT_FOUND'
            ], 404);
        }
    }
}