<?php

namespace App\Http\Controllers;

use App\Models\Kartu;
use App\Models\Pesanan;
use App\Models\Meja;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class KartuController extends Controller
{
    public function index()
    {
        return response()->json(Kartu::all());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'uid' => 'required|string|unique:kartus'
        ]);

        $kartu = Kartu::create([
            'uid' => strtoupper($validated['uid']),
            'status' => 'available'
        ]);
        
        return response()->json($kartu, 201);
    }

    /**
     * ✅ FIX BUG #2: Auto-cleanup sebelum delete kartu
     */
    public function destroy($id)
    {
        try {
            Log::info('Deleting kartu', ['kartu_id' => $id]);

            DB::beginTransaction();

            try {
                $kartu = Kartu::findOrFail($id);
                
                Log::info('Found kartu', [
                    'uid' => $kartu->uid,
                    'status' => $kartu->status
                ]);

                // ✅ CLEANUP: Find pesanan aktif dengan kartu ini
                $activePesanans = Pesanan::where('kartu_uid', $kartu->uid)
                    ->whereNotIn('status', ['completed', 'cancelled'])
                    ->get();

                if ($activePesanans->isNotEmpty()) {
                    Log::info('Found active pesanans with this card', [
                        'count' => $activePesanans->count(),
                        'ids' => $activePesanans->pluck('id')->toArray()
                    ]);

                    foreach ($activePesanans as $pesanan) {
                        // Set pesanan jadi completed
                        $pesanan->update(['status' => 'completed']);
                        
                        Log::info('Pesanan auto-completed', [
                            'pesanan_id' => $pesanan->id,
                            'nomor' => $pesanan->nomor_pesanan
                        ]);

                        // ✅ RESET MEJA
                        if ($pesanan->meja) {
                            $pesanan->meja->update(['status' => 'kosong']);
                            
                            Log::info('Meja reset to kosong', [
                                'meja_id' => $pesanan->meja->id,
                                'nomor_meja' => $pesanan->meja->nomor_meja
                            ]);
                        }
                    }
                }

                // ✅ NOW DELETE THE CARD
                $kartu->delete();

                DB::commit();

                Log::info('Kartu deleted successfully', [
                    'uid' => $kartu->uid,
                    'cleaned_orders' => $activePesanans->count()
                ]);

                return response()->json([
                    'success' => true,
                    'message' => 'Kartu berhasil dihapus',
                    'data' => [
                        'deleted_uid' => $kartu->uid,
                        'cleaned_orders' => $activePesanans->count()
                    ]
                ]);

            } catch (\Exception $e) {
                DB::rollBack();
                throw $e;
            }

        } catch (\Exception $e) {
            Log::error('Error deleting kartu', [
                'error' => $e->getMessage(),
                'kartu_id' => $id
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Gagal menghapus kartu',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}