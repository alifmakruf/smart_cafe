<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Kartu extends Model
{
    protected $fillable = [
        'uid', 'status', 'last_used_at'
    ];

    protected $casts = [
    'last_used_at' => 'datetime:c',  // ← ISO 8601
    'created_at' => 'datetime:c',
    'updated_at' => 'datetime:c',
    ];
}