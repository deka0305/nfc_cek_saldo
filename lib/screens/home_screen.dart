import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../models/nfc_card.dart';
import '../services/nfc_service.dart';
import '../services/card_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/nfc_scan_animation.dart';
import '../widgets/card_result_sheet.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  bool _isScanning = false;
  bool _nfcAvailable = false;
  bool _autoScan = true; // mode tempel-langsung-baca
  bool _manualActive = false; // sesi scan manual sedang berjalan (mode auto off)
  bool _loopRunning = false; // penanda loop persisten sedang berjalan
  bool _sheetOpen = false; // jeda scan saat hasil sedang ditampilkan
  bool _appActive = true; // false saat app di background
  String _statusText = 'Tempel kartu NFC ke belakang HP';
  List<NfcCard> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNfc();
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NfcService.stopScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cukup tandai aktif/tidak — jangan panggil finish() (bisa menggantungkan
    // poll yang sedang berjalan). Poll pendek akan selesai sendiri lalu loop
    // idle saat background, dan lanjut saat kembali.
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive) _scanLoop(); // pastikan loop hidup saat kembali ke depan
  }

  Future<void> _loadHistory() async {
    final saved = await CardStorage.loadAll();
    if (!mounted) return;
    setState(() => _history = saved);
  }

  Future<void> _checkNfc() async {
    final ok = await NfcService.isAvailable();
    if (!mounted) return;
    setState(() {
      _nfcAvailable = ok;
      if (!ok) _statusText = 'NFC tidak tersedia di perangkat ini';
    });
    if (ok) {
      await NfcService.warmUp(); // panaskan library agar scan pertama cepat
      _scanLoop(); // satu loop persisten seumur layar
    }
  }

  /// Loop tunggal & persisten. Tidak pernah mati selama layar hidup; hanya
  /// "idle" saat mode auto dimatikan, app di background, atau sheet terbuka.
  /// Desain ini menghindari race saat toggle mati→nyala (yang dulu bikin
  /// loop kedua tak jalan karena penjaga _loopRunning).
  Future<void> _scanLoop() async {
    if (_loopRunning) return;
    _loopRunning = true;
    while (mounted) {
      // Loop mem-poll bila mode auto ON, ATAU ada sesi scan manual aktif.
      final wantScan = _autoScan || _manualActive;
      if (!wantScan || !_nfcAvailable || !_appActive || _sheetOpen) {
        await Future.delayed(Duration(milliseconds: 250));
        continue;
      }
      if (!_isScanning || _statusText.startsWith('Kartu berhasil')) {
        setState(() {
          _isScanning = true;
          _statusText = 'Siap — tempelkan kartu ke belakang HP';
        });
      }
      try {
        final card = await NfcService.readCard();
        HapticFeedback.mediumImpact(); // getar tanda berhasil
        final saved = await CardStorage.add(card);
        if (!mounted) break;
        setState(() {
          _history = saved;
          _statusText = 'Kartu berhasil dibaca!';
          _manualActive = false; // sesi manual selesai setelah 1 bacaan sukses
          if (!_autoScan) _isScanning = false;
        });
        await _showResult(card); // tunggu sheet ditutup sebelum scan lagi
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final benign = msg.contains('habis') ||
            msg.contains('timeout') ||
            msg.contains('dibatalkan') ||
            msg.contains('cancel');
        if (!benign && mounted) {
          setState(() => _statusText =
              'Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
        }
        await Future.delayed(Duration(milliseconds: 250));
      }
    }
    _loopRunning = false;
  }

  void _toggleAutoScan(bool value) {
    setState(() {
      _autoScan = value;
      _isScanning = false;
      _statusText = value
          ? 'Siap — tempelkan kartu ke belakang HP'
          : 'Tekan tombol untuk scan';
    });
    // PENTING: JANGAN panggil finish()/stopScan() di sini. Bila dipanggil saat
    // loop sedang menunggu poll, poll bisa "mati tanpa selesai" di Android →
    // await readCard() menggantung selamanya → toggle ON tak bisa menembusnya.
    // Cukup ubah flag; poll pendek (≤3 dtk) akan selesai sendiri lalu loop
    // menyesuaikan (idle saat off, lanjut saat on).
    if (value) _scanLoop(); // hidupkan ulang loop bila sempat berhenti
  }

  /// Mulai sesi scan manual (mode auto off). Cukup nyalakan flag; loop robust
  /// yang menangani poll pendek berulang — TIDAK ada finish() yang bisa
  /// menggantungkan poll seperti sebelumnya.
  void _startScan() {
    if (_isScanning || !_nfcAvailable || _autoScan) return;
    setState(() {
      _manualActive = true;
      _isScanning = true;
      _statusText = 'Tempel kartu ke belakang HP...';
    });
    _scanLoop(); // pastikan loop hidup untuk memproses sesi manual
  }

  void _cancelScan() {
    // Cukup matikan flag; loop akan idle setelah poll pendek selesai.
    // Tidak memanggil finish() agar poll tidak menggantung.
    setState(() {
      _manualActive = false;
      _isScanning = false;
      _statusText = 'Scan dibatalkan';
    });
  }

  Future<void> _showResult(NfcCard card) async {
    _sheetOpen = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CardResultSheet(card: card),
      ),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: 48),
                    NfcScanAnimation(isScanning: _isScanning),
                    SizedBox(height: 32),
                    _buildStatusText(),
                    SizedBox(height: 24),
                    if (_nfcAvailable) _buildAutoScanToggle(),
                    SizedBox(height: 16),
                    _buildScanButton(),
                    SizedBox(height: 48),
                    if (_history.isNotEmpty) _buildHistory(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.nfc_rounded, color: AppTheme.primary, size: 22),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NFC Cek Saldo',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Baca saldo kartu NFC',
                style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
              ),
            ],
          ),
          Spacer(),
          IconButton(
            tooltip: 'Ganti tema',
            onPressed: () => AppTheme.toggle(!AppTheme.isDark.value),
            icon: Icon(
              AppTheme.isDark.value
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: AppTheme.onSurfaceMuted,
              size: 22,
            ),
          ),
          SizedBox(width: 4),
          _NfcStatusBadge(available: _nfcAvailable),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: Text(
        _statusText,
        key: ValueKey(_statusText),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _isScanning ? AppTheme.primary : AppTheme.onSurfaceMuted,
          fontSize: 15,
          fontWeight: _isScanning ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildAutoScanToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded,
              size: 18,
              color: _autoScan ? AppTheme.primary : AppTheme.onSurfaceMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Scan otomatis',
              style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _autoScan,
            activeThumbColor: AppTheme.primary,
            onChanged: _toggleAutoScan,
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    // Dalam mode auto, tombol jadi indikator (nonaktif untuk ditekan).
    if (_autoScan) {
      return Opacity(
        opacity: _nfcAvailable ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.contactless_rounded,
                    color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Menunggu kartu ditempel...',
                  style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _isScanning ? _cancelScan : _startScan,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: _nfcAvailable && !_isScanning
              ? LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                )
              : null,
          color: _isScanning
              ? AppTheme.surfaceVariant
              : (!_nfcAvailable ? AppTheme.surfaceVariant : null),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _nfcAvailable && !_isScanning
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Center(
          child: _isScanning
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Mendeteksi... (Tap untuk batal)',
                      style: TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.contactless_rounded,
                      color: _nfcAvailable ? Colors.white : AppTheme.onSurfaceMuted,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _nfcAvailable ? 'Mulai Scan Kartu' : 'NFC Tidak Tersedia',
                      style: TextStyle(
                        color: _nfcAvailable ? Colors.white : AppTheme.onSurfaceMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _deleteCard(NfcCard card) async {
    final saved = await CardStorage.remove(card.uid);
    if (!mounted) return;
    setState(() => _history = saved);
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Hapus semua riwayat?',
            style: TextStyle(color: AppTheme.onSurface, fontSize: 16)),
        content: Text(
          'Semua kartu tersimpan akan dihapus dari daftar. Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: TextStyle(color: AppTheme.onSurfaceMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await CardStorage.clear();
    if (!mounted) return;
    setState(() => _history = []);
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Riwayat Scan',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: _clearHistory,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Hapus semua',
                  style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: 12),
        ..._history.map((card) => Dismissible(
              key: ValueKey(card.uid),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _deleteCard(card),
              background: Container(
                alignment: Alignment.centerRight,
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.delete_outline, color: AppTheme.error),
              ),
              child: _HistoryTile(
                card: card,
                onTap: () => _showResult(card),
              ),
            )),
        SizedBox(height: 24),
      ],
    );
  }
}

class _NfcStatusBadge extends StatelessWidget {
  final bool available;
  _NfcStatusBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: available
            ? AppTheme.success.withOpacity(0.15)
            : AppTheme.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: available ? AppTheme.success : AppTheme.error,
            ),
          ),
          SizedBox(width: 6),
          Text(
            available ? 'NFC ON' : 'NFC OFF',
            style: TextStyle(
              color: available ? AppTheme.success : AppTheme.error,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final NfcCard card;
  final VoidCallback onTap;
  _HistoryTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.credit_card, color: AppTheme.primary, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.cardName ?? card.cardType,
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    card.shortUid,
                    style: TextStyle(
                      color: AppTheme.onSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  card.formattedBalance,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${card.scannedAt.hour.toString().padLeft(2, '0')}:'
                  '${card.scannedAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: AppTheme.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: AppTheme.onSurfaceMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
