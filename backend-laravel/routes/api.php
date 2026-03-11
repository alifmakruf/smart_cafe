<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\MenuController;
use App\Http\Controllers\MejaController;
use App\Http\Controllers\KartuController;
use App\Http\Controllers\PesananController;
use App\Http\Controllers\RfidController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\UserController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// ========================================
// AUTH ROUTES (Public - No Auth Required)
// ========================================
Route::prefix('auth')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
});

// ========================================
// PROTECTED ROUTES (Require Auth)
// ========================================
Route::prefix('v1')->group(function () {
    
    // MENU ROUTES
    Route::apiResource('menus', MenuController::class);
    
    // MEJA ROUTES
    Route::apiResource('mejas', MejaController::class);
    Route::put('mejas/{id}/status', [MejaController::class, 'updateStatus']);
    
    // KARTU ROUTES
    Route::apiResource('kartus', KartuController::class);
    
    // ✅ PESANAN ROUTES - PINDAHKAN assign-meja KE SINI
    Route::get('pesanans/history', [PesananController::class, 'history']);
    Route::post('pesanans/deactivate-card', [PesananController::class, 'deactivateCard']);
    Route::post('pesanans/{id}/link-kartu', [PesananController::class, 'linkKartu']);
    Route::post('pesanans/{id}/assign-meja', [PesananController::class, 'assignMeja']); // ✅ SUDAH DI DALAM v1
    Route::put('pesanans/{id}/status', [PesananController::class, 'updateStatus']);
    Route::apiResource('pesanans', PesananController::class);
    
    // ========================================
    // ADMIN ONLY ROUTES
    // ========================================
    // User Management (Admin only)
    Route::post('auth/register', [AuthController::class, 'register']);
    Route::get('users', [UserController::class, 'index']);
    Route::get('users/{id}', [UserController::class, 'show']);
    Route::put('users/{id}', [UserController::class, 'update']);
    Route::put('users/{id}/password', [UserController::class, 'changePassword']);
    Route::delete('users/{id}', [UserController::class, 'destroy']);
});

// ========================================
// RFID/ESP ROUTES (Outside v1, No Auth)
// ========================================
Route::prefix('rfid')->group(function () {
    Route::post('/activate-table', [RfidController::class, 'activateTable']);
    Route::post('/deactivate-table', [RfidController::class, 'deactivateTable']);
    Route::get('/check-card/{card_uid}', [RfidController::class, 'checkCardStatus']);
    Route::post('/kasir-scan', [RfidController::class, 'kasirScan']);
    Route::get('/table-status/{table_id}', [RfidController::class, 'tableStatus']);
});

// ✅ Check table pesanan (outside v1, untuk ESP)
Route::get('/pesanan/check-table/{table_id}', [PesananController::class, 'checkTableOrder']);
