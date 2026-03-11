<?php

namespace App\Http\Controllers;

use App\Models\Meja;
use Illuminate\Http\Request;

class MejaController extends Controller
{
    public function index()
    {
        return response()->json(Meja::with('pesananAktif')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'nomor_meja' => 'required|integer|unique:mejas',
            'kapasitas' => 'nullable|integer|min:1',
            'esp8266_id' => 'nullable|string|unique:mejas'
        ]);

        $meja = Meja::create($validated);
        return response()->json($meja, 201);
    }

    public function update(Request $request, $id)
    {
        $meja = Meja::findOrFail($id);
        $meja->update($request->all());
        return response()->json($meja);
    }

    public function destroy($id)
    {
        Meja::findOrFail($id)->delete();
        return response()->json(['message' => 'Meja deleted']);
    }

    public function updateStatus($id, Request $request)
    {
        $meja = Meja::findOrFail($id);
        $meja->update(['status' => $request->status]);
        return response()->json($meja);
    }
}