<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Pesanan extends Model
{
    protected $fillable = [
        'nomor_pesanan',
        'items',
        'total_harga',
        'metode_pembayaran',
        'status',
        'meja_id',
        'kartu_uid',
        'customer_name',
        'tipe',
    ];

    protected $casts = [
        'items' => 'array',
        'total_harga' => 'decimal:2',
        // ✅ CRITICAL: Cast ke datetime dengan timezone
        'created_at' => 'datetime:Y-m-d H:i:s',
        'updated_at' => 'datetime:Y-m-d H:i:s',
    ];

    // Relations
    public function meja()
    {
        return $this->belongsTo(Meja::class);
    }

    public function kartu()
    {
        return $this->belongsTo(Kartu::class, 'kartu_uid', 'uid');
    }
}

// ✅ FIX 4: PesananController.php - Force timezone saat return JSON

