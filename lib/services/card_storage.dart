import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nfc_card.dart';

/// Penyimpanan lokal riwayat kartu yang pernah di-scan.
/// Data disimpan sebagai JSON di SharedPreferences perangkat (offline, permanen
/// sampai dihapus pengguna atau aplikasi di-uninstall).
class CardStorage {
  static const _key = 'scanned_cards';
  static const int maxItems = 50; // batas agar penyimpanan tidak membengkak

  /// Muat semua kartu tersimpan (terbaru dulu, sesuai urutan simpan).
  static Future<List<NfcCard>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => NfcCard.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Simpan kartu baru di paling atas. Bila UID sama sudah ada, entri lama
  /// diganti (di-refresh) agar tidak menumpuk duplikat kartu yang sama.
  static Future<List<NfcCard>> add(NfcCard card) async {
    final list = await loadAll();
    list.removeWhere((c) => c.uid == card.uid);
    list.insert(0, card);
    if (list.length > maxItems) list.removeRange(maxItems, list.length);
    await _save(list);
    return list;
  }

  /// Hapus satu kartu berdasarkan UID.
  static Future<List<NfcCard>> remove(String uid) async {
    final list = await loadAll();
    list.removeWhere((c) => c.uid == uid);
    await _save(list);
    return list;
  }

  /// Hapus semua riwayat.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(List<NfcCard> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(list.map((c) => c.toJson()).toList()));
  }
}
