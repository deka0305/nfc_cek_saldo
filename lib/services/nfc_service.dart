import 'package:flutter/services.dart';
import '../models/nfc_card.dart';

class NfcService {
  static const _channel = MethodChannel('com.dedenkurnia.nfc_cek_saldo/nfc');

  static Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      return res?['available'] == true && res?['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<NfcCard> readCard() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('startScan');
    if (raw == null) throw Exception('Tidak ada respons dari NFC');

    final success = raw['success'] as bool? ?? false;
    if (!success) {
      throw Exception(raw['error'] as String? ?? 'Gagal membaca kartu');
    }

    final uid = raw['uid'] as String? ?? 'Unknown';
    final type = raw['type'] as String? ?? 'NFC Tag';
    final balanceRaw = raw['balance'];
    final int? balance = balanceRaw != null ? (balanceRaw as num).toInt() : null;
    final rawData = (raw['rawData'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final techList = (raw['techList'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        type;

    return NfcCard(
      uid: uid,
      cardType: type,
      techType: techList,
      balance: balance,
      cardName: _detectCardName(type, uid),
      rawData: rawData,
      scannedAt: DateTime.now(),
    );
  }

  static Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } catch (_) {}
  }

  static String _detectCardName(String type, String uid) {
    if (type.contains('MIFARE Classic')) return 'Kartu e-Money / Kartu NFC';
    if (type.contains('MIFARE Ultralight')) return 'Kartu NFC Ultralight';
    if (type.contains('ISO-DEP')) return 'Kartu Chip EMV';
    return 'Kartu NFC';
  }
}
