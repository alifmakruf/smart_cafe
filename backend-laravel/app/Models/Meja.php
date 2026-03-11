<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Meja extends Model
{
    protected $fillable = [
        'nomor_meja', 'kapasitas', 'status', 'esp8266_id'
    ];

    protected $casts = [
    'created_at' => 'datetime:c',
    'updated_at' => 'datetime:c',
    ];

    public function pesananAktif()
    {
    return $this->hasOne(Pesanan::class, 'meja_id')
        ->whereIn('status', ['preparing', 'ready', 'served'])
        ->latest();
    }

}