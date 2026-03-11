<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Login
     * POST /api/auth/login
     */
    public function login(Request $request)
    {
        try {
            $validated = $request->validate([
                'nama' => 'required|string',
                'password' => 'required|string',
            ]);

            Log::info('Login attempt', ['nama' => $validated['nama']]);

            // Find user by nama
            $user = User::where('nama', $validated['nama'])->first();

            if (!$user) {
                Log::warning('Login failed: user not found', ['nama' => $validated['nama']]);
                
                return response()->json([
                    'success' => false,
                    'message' => 'User tidak ditemukan',
                ], 404);
            }

            // Check if user is active
            if (!$user->is_active) {
                Log::warning('Login failed: user inactive', ['nama' => $validated['nama']]);
                
                return response()->json([
                    'success' => false,
                    'message' => 'User tidak aktif',
                ], 403);
            }

            // Check password
            if (!Hash::check($validated['password'], $user->password)) {
                Log::warning('Login failed: wrong password', ['nama' => $validated['nama']]);
                
                return response()->json([
                    'success' => false,
                    'message' => 'Password salah',
                ], 401);
            }

            // Login success
            Auth::login($user);

            Log::info('Login successful', [
                'user_id' => $user->id,
                'nama' => $user->nama,
                'posisi' => $user->posisi,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Login berhasil',
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'nama' => $user->nama,
                        'posisi' => $user->posisi,
                        'is_active' => $user->is_active,
                    ],
                ],
            ]);

        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $e->errors(),
            ], 422);
            
        } catch (\Exception $e) {
            Log::error('Login error', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan server',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Register (Admin only)
     * POST /api/auth/register
     */
    public function register(Request $request)
    {
        try {
            $validated = $request->validate([
                'nama' => 'required|string|unique:users,nama',
                'posisi' => 'required|in:kasir,kitchen,admin',
                'password' => 'required|string|min:6',
            ]);

            Log::info('Register attempt', [
                'nama' => $validated['nama'],
                'posisi' => $validated['posisi'],
            ]);

            $user = User::create([
                'nama' => $validated['nama'],
                'posisi' => $validated['posisi'],
                'password' => Hash::make($validated['password']),
                'is_active' => true,
            ]);

            Log::info('User registered successfully', [
                'user_id' => $user->id,
                'nama' => $user->nama,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'User berhasil didaftarkan',
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'nama' => $user->nama,
                        'posisi' => $user->posisi,
                    ],
                ],
            ], 201);

        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $e->errors(),
            ], 422);
            
        } catch (\Exception $e) {
            Log::error('Register error', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal mendaftarkan user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Logout
     * POST /api/auth/logout
     */
    public function logout(Request $request)
    {
        try {
            Auth::logout();

            Log::info('User logged out');

            return response()->json([
                'success' => true,
                'message' => 'Logout berhasil',
            ]);

        } catch (\Exception $e) {
            Log::error('Logout error', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal logout',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get current user
     * GET /api/auth/me
     */
    public function me(Request $request)
    {
        try {
            $user = Auth::user();

            if (!$user) {
                return response()->json([
                    'success' => false,
                    'message' => 'User tidak terautentikasi',
                ], 401);
            }

            return response()->json([
                'success' => true,
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'nama' => $user->nama,
                        'posisi' => $user->posisi,
                        'is_active' => $user->is_active,
                    ],
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('Get user error', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal mendapatkan data user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}