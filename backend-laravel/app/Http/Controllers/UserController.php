<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class UserController extends Controller
{
    /**
     * Get all users
     * GET /api/users
     */
    public function index()
    {
        try {
            $users = User::orderBy('created_at', 'desc')->get();

            return response()->json([
                'success' => true,
                'data' => $users->map(fn($user) => [
                    'id' => $user->id,
                    'nama' => $user->nama,
                    'posisi' => $user->posisi,
                    'is_active' => $user->is_active,
                    'created_at' => $user->created_at,
                ]),
            ]);

        } catch (\Exception $e) {
            Log::error('Error fetching users', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal mengambil data user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get single user
     * GET /api/users/{id}
     */
    public function show($id)
    {
        try {
            $user = User::findOrFail($id);

            return response()->json([
                'success' => true,
                'data' => [
                    'id' => $user->id,
                    'nama' => $user->nama,
                    'posisi' => $user->posisi,
                    'is_active' => $user->is_active,
                    'created_at' => $user->created_at,
                ],
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'User tidak ditemukan',
            ], 404);
        }
    }

    /**
     * Update user
     * PUT /api/users/{id}
     */
    public function update(Request $request, $id)
    {
        try {
            $user = User::findOrFail($id);

            $validated = $request->validate([
                'nama' => 'sometimes|string|unique:users,nama,' . $id,
                'posisi' => 'sometimes|in:kasir,kitchen,admin',
                'is_active' => 'sometimes|boolean',
            ]);

            Log::info('Updating user', [
                'user_id' => $id,
                'data' => $validated,
            ]);

            $user->update($validated);

            return response()->json([
                'success' => true,
                'message' => 'User berhasil diupdate',
                'data' => [
                    'id' => $user->id,
                    'nama' => $user->nama,
                    'posisi' => $user->posisi,
                    'is_active' => $user->is_active,
                ],
            ]);

        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $e->errors(),
            ], 422);
            
        } catch (\Exception $e) {
            Log::error('Error updating user', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal update user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Change password
     * PUT /api/users/{id}/password
     */
    public function changePassword(Request $request, $id)
    {
        try {
            $user = User::findOrFail($id);

            $validated = $request->validate([
                'new_password' => 'required|string|min:6',
            ]);

            Log::info('Changing password', ['user_id' => $id]);

            $user->update([
                'password' => Hash::make($validated['new_password']),
            ]);

            Log::info('Password changed successfully', ['user_id' => $id]);

            return response()->json([
                'success' => true,
                'message' => 'Password berhasil diubah',
            ]);

        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors' => $e->errors(),
            ], 422);
            
        } catch (\Exception $e) {
            Log::error('Error changing password', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal ubah password',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete user
     * DELETE /api/users/{id}
     */
    public function destroy($id)
    {
        try {
            $user = User::findOrFail($id);

            // Prevent deleting yourself
            if (auth()->id() === $user->id) {
                return response()->json([
                    'success' => false,
                    'message' => 'Tidak dapat menghapus user sendiri',
                ], 400);
            }

            Log::info('Deleting user', [
                'user_id' => $id,
                'nama' => $user->nama,
            ]);

            $user->delete();

            return response()->json([
                'success' => true,
                'message' => 'User berhasil dihapus',
            ]);

        } catch (\Exception $e) {
            Log::error('Error deleting user', ['error' => $e->getMessage()]);
            
            return response()->json([
                'success' => false,
                'message' => 'Gagal menghapus user',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}