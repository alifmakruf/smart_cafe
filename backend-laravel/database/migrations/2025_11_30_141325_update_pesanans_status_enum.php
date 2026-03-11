<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Step 1: Tambah 'served' dan 'placed' ke enum (transisi)
        DB::statement("ALTER TABLE pesanans MODIFY COLUMN status ENUM('pending', 'paid', 'served', 'placed', 'preparing', 'ready', 'completed', 'cancelled') DEFAULT 'pending'");
        
        // Step 2: Update semua data 'served' → 'placed'
        DB::table('pesanans')
            ->where('status', 'served')
            ->update(['status' => 'placed']);
        
        // Step 3: Hapus 'served' dari enum (final)
        DB::statement("ALTER TABLE pesanans MODIFY COLUMN status ENUM('pending', 'paid', 'placed', 'preparing', 'ready', 'completed', 'cancelled') DEFAULT 'pending'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Step 1: Tambah 'served' kembali
        DB::statement("ALTER TABLE pesanans MODIFY COLUMN status ENUM('pending', 'paid', 'served', 'placed', 'preparing', 'ready', 'completed', 'cancelled') DEFAULT 'pending'");
        
        // Step 2: Update semua data 'placed' → 'served'
        DB::table('pesanans')
            ->where('status', 'placed')
            ->update(['status' => 'served']);
        
        // Step 3: Hapus 'placed' dari enum
        DB::statement("ALTER TABLE pesanans MODIFY COLUMN status ENUM('pending', 'paid', 'preparing', 'ready', 'served', 'completed', 'cancelled') DEFAULT 'pending'");
    }
};