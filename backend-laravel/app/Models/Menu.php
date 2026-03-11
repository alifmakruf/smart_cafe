<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Menu extends Model
{
    protected $fillable = [
        'nama', 'harga', 'kategori', 'gambar', 'stok', 'aktif'
    ];

    protected $casts = [
        'harga' => 'decimal:2',
        'stok' => 'integer',
        'aktif' => 'boolean'
    ];

    
}