<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('kartus', function (Blueprint $table) {
            // Drop old enum
            $table->dropColumn('status');
        });
        
        Schema::table('kartus', function (Blueprint $table) {
            // Add new enum with 'running'
            $table->enum('status', ['available', 'running', 'in_use'])
                  ->default('available')
                  ->after('uid');
        });
    }

    public function down()
    {
        Schema::table('kartus', function (Blueprint $table) {
            $table->dropColumn('status');
        });
        
        Schema::table('kartus', function (Blueprint $table) {
            $table->enum('status', ['available', 'in_use'])->default('available');
        });
    }
};