<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use Notifiable;

    protected $fillable = [
        'nama',
        'posisi',
        'password',
        'is_active',
    ];

    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'created_at' => 'datetime:c',
        'updated_at' => 'datetime:c',
    ];

    /**
     * Check if user has specific role
     */
    public function hasRole(string $role): bool
    {
        return $this->posisi === $role;
    }

    /**
     * Check if user is admin
     */
    public function isAdmin(): bool
    {
        return $this->posisi === 'admin';
    }

    /**
     * Check if user is kasir
     */
    public function isKasir(): bool
    {
        return $this->posisi === 'kasir';
    }

    /**
     * Check if user is kitchen
     */
    public function isKitchen(): bool
    {
        return $this->posisi === 'kitchen';
    }
}