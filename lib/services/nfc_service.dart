import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:prepaid_lib_flutter_null_safety/unik_lib_flutter.dart';
import '../models/nfc_card.dart';
import '../models/transaction.dart';

class NfcService {
  // Channel native lama hanya dipakai untuk cek status NFC (tanpa side-effect).
  static const _channel = MethodChannel('com.dedenkurnia.nfc_cek_saldo/nfc');

  // MID / init key untuk library.
  static const String _mid = '1234567abc';
  static const int _env = 0; // 0 = dev, 1 = prod

  // Mode OFFLINE.
  //
  // initUnikLib() memanggil server MDD HANYA untuk lisensi SDK & fitur top-up.
  // Server dev (apidev.mdd.co.id:28194) sudah tidak dibuka ke publik, sehingga
  // panggilan itu selalu gagal. NAMUN library meng-instantiate card processor
  // (dengan APDU hardcoded + isMandiriEnable=true) di dalam readFile() SEBELUM
  // panggilan server tersebut. Artinya kemampuan BACA saldo & history tetap
  // aktif meski init "gagal" — semua parsing dilakukan lokal di HP, tanpa server.
  //
  // Jadi kita panggil initUnikLib() sekali hanya untuk memicu instansiasi
  // processor itu (terjadi dalam milidetik), lalu ABAIKAN hasil gagalnya.
  // Timeout pendek dipakai agar tidak menunggu koneksi server yang menggantung.
  static Future<void>? _initFuture;

  static Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      return res?['available'] == true && res?['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Picu instansiasi card processor library sekali seumur sesi. Aman dipanggil
  /// berkali-kali (idempoten) dan sengaja diprakarsai lebih awal (mis. saat NFC
  /// terdeteksi) agar scan pertama tidak menunggu timeout jaringan.
  static Future<void> warmUp() => _ensureInit();

  static Future<void> _ensureInit() {
    return _initFuture ??= () async {
      try {
        // Nilai balik (true/false) diabaikan — processor sudah ter-set di native
        // sebelum panggilan server, jadi baca offline tetap jalan apa pun hasilnya.
        await UnikLibFlutter.initUnikLib(_mid, _env)
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      } catch (_) {
        // Kegagalan init tidak menghalangi baca kartu offline.
      }
    }();
  }

  /// Baca kartu.
  ///
  /// [pollTimeout] = berapa lama menunggu kartu ditempel. Kita melakukan poll
  /// SENDIRI (bukan lewat library) dengan timeout ini, lalu memanggil
  /// getCardInfo(startPooling: false) pada tag yang sudah tersambung.
  ///
  /// Alasan: `FlutterNfcKit.finish()` tidak membatalkan poll yang sedang
  /// menunggu. Bila library yang mem-poll (default ~20 dtk), loop scan otomatis
  /// akan "nyangkut" di poll lama saat mode dimatikan lalu dinyalakan lagi.
  /// Dengan poll pendek milik kita, loop selalu berputar cepat & responsif.
  static Future<NfcCard> readCard(
      {Duration pollTimeout = const Duration(seconds: 3)}) async {
    await _ensureInit();

    // Tunggu kartu ditempel. Lempar PlatformException(408) bila timeout —
    // pemanggil (loop) menganggapnya "tidak ada kartu" dan mencoba lagi.
    NFCTag tag;
    try {
      tag = await FlutterNfcKit.poll(
        timeout: pollTimeout,
        iosAlertMessage: 'Tempelkan kartu ke iPhone',
        // Optimasi: semua e-money Indonesia = ISO14443 Type A (IsoDep).
        // Matikan tipe lain + lewati pengecekan NDEF agar koneksi ke kartu
        // lebih cepat & andal (e-money bukan tag NDEF).
        readIso14443A: true,
        readIso14443B: false,
        readIso15693: false,
        readIso18092: false,
        androidCheckNDEF: false,
      );
    } catch (e) {
      await _finishQuietly();
      rethrow; // 408 "Polling tag timeout" ditangani sebagai benign di loop
    }

    UnikLibFlutter.setIosMessage('Mohon tunggu, jangan lepaskan kartu...');

    // Library MENULIS ke index [0] tiap list → wajib berisi satu elemen.
    final cardUid = <String>[''];
    final cardNumber = <String>[''];
    final balance = <String>[''];
    final bankName = <String>[''];

    // startPooling: false → library pakai tag yang SUDAH kita sambungkan lewat
    // poll di atas, tidak mem-poll lagi.
    final ok = await UnikLibFlutter.getCardInfo(
      cardUid,
      cardNumber,
      balance,
      bankName,
      startPooling: false,
    );

    if (!ok) {
      await _finishQuietly();
      throw Exception('Gagal membaca kartu');
    }

    // Riwayat transaksi (hanya didukung untuk Mandiri & BNI).
    final history = await _readHistory();

    await UnikLibFlutter.stopReader(messageSuccess: 'Cek saldo berhasil');

    // UID dari tag hasil poll kita (library tak mengisinya saat startPooling:false).
    final uid = _firstOrNull(cardUid) ?? tag.id;
    final number = _firstOrNull(cardNumber);
    final bank = _firstOrNull(bankName);
    final rawBal = _firstOrNull(balance);
    final int? bal = rawBal != null ? int.tryParse(_digitsOnly(rawBal)) : null;

    return NfcCard(
      uid: uid,
      cardType: bank ?? 'Kartu e-Money',
      techType: bank ?? 'NFC',
      balance: bal,
      cardName: bank ?? 'Kartu e-Money',
      cardNumber: number,
      bankName: bank,
      history: history,
      rawData: const [],
      scannedAt: DateTime.now(),
    );
  }

  static Future<List<CardTransaction>> _readHistory() async {
    try {
      final histRaw = <String>[''];
      final okHist = await UnikLibFlutter.getHistory(histRaw);
      final raw = _firstOrNull(histRaw);
      if (!okHist || raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final list = decoded
          .whereType<Map>()
          .map((e) =>
              CardTransaction.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();

      // Buang duplikat yang muncul akibat pembacaan ring buffer (record identik).
      final seen = <String>{};
      final unique = list
          .where((t) => seen.add('${t.date}|${t.amount}|${t.tid}|${t.counter}'))
          .toList();

      // Urutkan terbaru dulu. Record tanpa tanggal valid ditaruh paling akhir.
      unique.sort((a, b) {
        final da = a.dateTime, db = b.dateTime;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      return unique;
    } catch (_) {
      // History opsional — abaikan bila kartu tidak mendukung.
      return const [];
    }
  }

  static Future<void> stopScan() async {
    await _finishQuietly();
  }

  /// Tutup sesi NFC (FlutterNfcKit.finish via stopReader) tanpa melempar error
  /// bila memang tidak ada sesi aktif.
  static Future<void> _finishQuietly() async {
    try {
      await UnikLibFlutter.stopReader();
    } catch (_) {}
  }

  /// Ambil elemen pertama yang tidak kosong, atau null. Library selalu
  /// mengisi index [0] tapi bisa tetap '' bila field tidak didukung kartu.
  static String? _firstOrNull(List<String> list) {
    if (list.isEmpty) return null;
    final v = list.first.trim();
    return v.isEmpty ? null : v;
  }

  static String _digitsOnly(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? '0' : d;
  }
}
