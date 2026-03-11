<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class UserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Clear existing users (optional)
        User::truncate();

        // Admin user
        User::create([
            'nama' => 'Admin',
            'posisi' => 'admin',
            'password' => Hash::make('admin123'),
            'is_active' => true,
        ]);

        // Kasir user
        User::create([
            'nama' => 'Kasir 1',
            'posisi' => 'kasir',
            'password' => Hash::make('kasir123'),
            'is_active' => true,
        ]);

        // Kitchen user
        User::create([
            'nama' => 'Kitchen Staff',
            'posisi' => 'kitchen',
            'password' => Hash::make('kitchen123'),
            'is_active' => true,
        ]);

        $this->command->info('✓ Default users created:');
        $this->command->info('  Admin: admin / admin123');
        $this->command->info('  Kasir: Kasir 1 / kasir123');
        $this->command->info('  Kitchen: Kitchen Staff / kitchen123');
    }
}