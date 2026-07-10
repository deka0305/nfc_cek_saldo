# NFC Cek Saldo

Aplikasi Flutter untuk membaca **saldo** dan **riwayat transaksi** kartu e-money/e-toll Indonesia lewat NFC — bekerja **100% offline**, tanpa koneksi ke server manapun.

---

## Daftar Isi
1. [Fitur](#fitur)
2. [Kartu yang Didukung](#kartu-yang-didukung)
3. [Teknologi yang Digunakan](#teknologi-yang-digunakan)
4. [Cara Kerja (Arsitektur)](#cara-kerja-arsitektur)
5. [Struktur Proyek](#struktur-proyek)
6. [Prasyarat](#prasyarat)
7. [Cara Build & Menjalankan](#cara-build--menjalankan)
8. [Cara Pakai (Pengguna)](#cara-pakai-pengguna)
9. [Batasan](#batasan)
10. [Troubleshooting](#troubleshooting)
11. [Catatan Teknis Penting](#catatan-teknis-penting)

---

## Fitur
- ✅ Baca **saldo** kartu e-money via NFC (offline)
- ✅ Baca **riwayat transaksi** yang tersimpan di kartu (Mandiri & BNI)
- ✅ Tap transaksi untuk melihat **detail** (tanggal/jam, saldo setelah transaksi, No. Mesin/Terminal, no. urut, kode tipe)
- ✅ Label transaksi ramah: **Pembayaran** (saldo keluar) / **Top-up** (saldo masuk)
- ✅ Riwayat transaksi **diurutkan terbaru → terlama**
- ✅ **Riwayat kartu tersimpan permanen** di HP — kartu yang pernah di-scan bisa dibuka lagi dari tampilan awal (offline, maks 50 kartu). Geser untuk hapus / tombol "Hapus semua"
- ✅ Tidak butuh internet, tidak butuh login, tidak menyimpan/mengirim data ke mana pun

---

## Kartu yang Didukung

| Kartu | Baca Saldo | Baca Riwayat |
|-------|:----------:|:------------:|
| Mandiri e-Money / e-Toll | ✅ | ✅ (± 10 transaksi terakhir) |
| BNI TapCash | ✅ | ✅ (± 10 transaksi terakhir) |
| BCA Flazz | ✅ | ❌ |
| DKI JakCard | ✅ | ❌ |

> Riwayat hanya tersedia untuk Mandiri & BNI karena hanya kartu tersebut yang mengekspos log transaksi via APDU standar.

---

## Teknologi yang Digunakan

| Komponen | Teknologi | Keterangan |
|----------|-----------|------------|
| Framework | **Flutter 3.38.x** (Dart SDK ^3.10.4) | UI lintas platform |
| Bahasa | **Dart** (Flutter) + **Kotlin** (native Android) | |
| Baca kartu | **`prepaid_lib_flutter_null_safety` ^1.0.1** | Library komunitas berisi perintah APDU + parser saldo/history kartu e-money Indonesia |
| Penyimpanan lokal | **`shared_preferences` ^2.5.5** | Simpan riwayat kartu (JSON) permanen di perangkat |
| Transport NFC | **`flutter_nfc_kit`** (dependensi transitif dari library di atas) | Poll tag & kirim APDU (`transceive`) |
| Native NFC (opsional) | **Android NFC API** (`IsoDep`, `MifareClassic`, dll.) di `MainActivity.kt` | Dipakai untuk cek status NFC; jalur pembacaan generik cadangan |
| UI Icons | **`cupertino_icons`** | |
| Lint | **`flutter_lints` ^6.0.0** | |

**Platform target:** Android (minSdk **26** / Android 8.0, targetSdk mengikuti Flutter). Kode iOS ada di library namun aplikasi ini difokuskan & diuji untuk Android.

---

## Cara Kerja (Arsitektur)

### Alur baca kartu
```
HomeScreen  →  NfcService.readCard()  →  prepaid_lib (UnikLibFlutter)
                                              │
                                              ├─ poll tag NFC (flutter_nfc_kit)
                                              ├─ SELECT AID (deteksi jenis kartu)
                                              ├─ kirim APDU balance → parsing lokal
                                              └─ kirim APDU history → parsing lokal
                                              ↓
                                       NfcCard { saldo, nomor, bank, history }
                                              ↓
                                       CardResultSheet (bottom sheet hasil)
```

### Kenapa bisa OFFLINE?
Library `prepaid_lib` sebenarnya dirancang memanggil server MDD saat `initUnikLib()`. **Namun panggilan server itu hanya untuk lisensi SDK & fitur top-up — BUKAN untuk membaca kartu.**

Perintah APDU dan logika parsing saldo/history sudah **hardcoded di dalam library** dan berjalan **lokal di HP**. Objek pemrosesnya (`mainCardProcessor`) di-instansiasi **sebelum** panggilan server dilakukan. Jadi:

1. `NfcService` memanggil `initUnikLib()` **satu kali** hanya untuk memicu instansiasi processor.
2. Panggilan server gagal (server dev sudah tidak dibuka) — **hasil gagalnya sengaja diabaikan**.
3. Pembacaan kartu (`getCardInfo`, `getHistory`) tetap berjalan penuh secara lokal.

Lihat penjelasan detail di komentar [`lib/services/nfc_service.dart`](lib/services/nfc_service.dart).

---

## Struktur Proyek

```
lib/
├── main.dart                     # Entry point aplikasi
├── models/
│   ├── nfc_card.dart             # Model kartu: uid, saldo, nomor, bank, history
│   └── transaction.dart          # Model 1 baris riwayat: amount, date, type, tid, balance, counter
├── services/
│   ├── nfc_service.dart          # Logika baca kartu + inisialisasi library (kunci mode offline)
│   └── card_storage.dart         # Simpan/muat riwayat kartu ke SharedPreferences
├── screens/
│   └── home_screen.dart          # Layar utama: tombol scan, status, daftar hasil
├── widgets/
│   ├── card_result_sheet.dart    # Bottom sheet hasil: saldo, info kartu, riwayat + detail
│   └── nfc_scan_animation.dart   # Animasi saat scanning
└── theme/
    └── app_theme.dart            # Warna & tema aplikasi

android/app/src/main/
├── AndroidManifest.xml           # Permission NFC + intent NFC
├── res/xml/nfc_tech_filter.xml   # Filter teknologi NFC
└── kotlin/.../MainActivity.kt    # Channel native: cek status NFC + reader generik
```

---

## Prasyarat
- **Flutter SDK 3.38.x** atau kompatibel (Dart ^3.10.4) — cek dengan `flutter --version`
- **Android SDK** + perangkat/emulator Android **8.0+** dengan **NFC** (emulator tidak punya NFC — wajib perangkat fisik)
- **Android Studio** / VS Code dengan plugin Flutter
- Kartu e-money fisik untuk pengujian

---

## Cara Build & Menjalankan

```bash
# 1. Pasang dependency
flutter pub get

# 2. Hubungkan HP Android (aktifkan USB debugging), pastikan terdeteksi
flutter devices

# 3. Jalankan mode debug
flutter run -d <device-id>

# 4. Build APK release (untuk dipasang tanpa kabel)
flutter build apk --release
#    Output: build/app/outputs/flutter-apk/app-release.apk
```

Pastikan **NFC aktif** di pengaturan HP sebelum menjalankan.

---

## Cara Pakai (Pengguna)
1. Buka aplikasi **NFC Cek Saldo**. Status di kanan atas menampilkan **NFC ON** bila NFC aktif.
2. Tekan tombol **"Mulai Scan Kartu"**.
3. **Tempelkan kartu** e-money ke bagian belakang HP (biasanya area kamera) dan **tahan** sampai muncul hasil.
4. Muncul **bottom sheet** berisi saldo, nomor kartu, dan riwayat transaksi.
5. **Tap salah satu transaksi** untuk melihat detail lengkap (termasuk No. Mesin/Terminal).

---

## Batasan
- **Riwayat maksimal ± 10 transaksi terakhir** — batas dari memori chip kartu (ring buffer). Transaksi lebih lama sudah ditimpa di kartu, tidak bisa dibaca lagi.
- **Riwayat hanya untuk Mandiri & BNI.** BCA Flazz & DKI hanya baca saldo.
- **Tidak ada lokasi transaksi.** Kartu hanya menyimpan **TID (Terminal ID)** — nomor identitas mesin, bukan GPS/nama merchant. Menerjemahkan TID → nama tempat butuh database bank (online, privat).
- **Top-up saldo tidak didukung** (butuh server MDD yang sudah tidak tersedia). Aplikasi ini hanya untuk **membaca**.
- **Hanya Android.** Butuh perangkat fisik ber-NFC (bukan emulator).

---

## Troubleshooting

| Gejala | Penyebab & Solusi |
|--------|-------------------|
| "NFC tidak tersedia" | Aktifkan NFC di Pengaturan HP; pastikan HP punya hardware NFC. |
| "Waktu habis — kartu tidak terbaca" | Kartu kurang menempel/terlalu cepat dilepas. Tempel di area NFC (dekat kamera) dan tahan. |
| Saldo/riwayat tidak muncul untuk kartu tertentu | Jenis kartu mungkin belum didukung, atau kartu generasi baru dengan protokol berbeda. |
| Aplikasi sempat "diam" di splash | Pastikan konfigurasi cleartext HTTP **tidak** diaktifkan (lihat catatan di bawah). |
| Peringatan build `different roots ... C:\... and D:\...` | Non-fatal. Muncul karena pub cache di drive `C:` sedangkan proyek di `D:` (Kotlin incremental cache lintas-drive). Build tetap sukses. Untuk menghilangkannya, letakkan proyek di drive yang sama dengan pub cache. |

---

## Catatan Teknis Penting
> ⚠️ Hal-hal berikut **kritikal** untuk mode offline — jangan diubah tanpa memahami konsekuensinya.

1. **List hasil baca wajib `['']`, bukan `[]`.** Library menulis langsung ke `list[0]`; list kosong → `RangeError`.
2. **Cleartext HTTP HARUS tetap diblokir** (default Android 9+). Jika diizinkan, panggilan `initUnikLib` benar-benar mencoba konek ke server mati → **main thread freeze ~100 detik**. Dengan diblokir, panggilan gagal instan dan pembacaan tetap jalan.
3. **`NfcService._ensureInit()` sengaja mengabaikan hasil gagal init** — lihat komentar lengkap di file tersebut.
4. Init "dipanaskan" lebih awal (`NfcService.warmUp()`) saat NFC terdeteksi agar scan pertama tidak menunggu.

---

*Dibuat sebagai alat baca-saldo offline. Bukan aplikasi resmi bank penerbit; gunakan sesuai kebutuhan pribadi.*
