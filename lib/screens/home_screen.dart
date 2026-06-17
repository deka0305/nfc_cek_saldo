import 'package:flutter/material.dart';
import '../models/nfc_card.dart';
import '../services/nfc_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nfc_scan_animation.dart';
import '../widgets/card_result_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isScanning = false;
  bool _nfcAvailable = false;
  String _statusText = 'Tempel kartu NFC ke belakang HP';
  List<NfcCard> _history = [];

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    final ok = await NfcService.isAvailable();
    setState(() {
      _nfcAvailable = ok;
      if (!ok) _statusText = 'NFC tidak tersedia di perangkat ini';
    });
  }

  Future<void> _startScan() async {
    if (_isScanning || !_nfcAvailable) return;
    setState(() {
      _isScanning = true;
      _statusText = 'Tempel kartu ke belakang HP...';
    });

    try {
      final card = await NfcService.readCard();
      if (!mounted) return;
      setState(() {
        _history.insert(0, card);
        _isScanning = false;
        _statusText = 'Kartu berhasil dibaca!';
      });
      _showResult(card);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        final msg = e.toString().toLowerCase();
        _statusText = msg.contains('dibatalkan') || msg.contains('cancel')
            ? 'Scan dibatalkan'
            : 'Gagal membaca kartu';
      });
    }
  }

  Future<void> _cancelScan() async {
    await NfcService.stopScan();
    setState(() {
      _isScanning = false;
      _statusText = 'Scan dibatalkan';
    });
  }

  void _showResult(NfcCard card) {
    showModalBottomSheet(
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    NfcScanAnimation(isScanning: _isScanning),
                    const SizedBox(height: 32),
                    _buildStatusText(),
                    const SizedBox(height: 40),
                    _buildScanButton(),
                    const SizedBox(height: 48),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.nfc_rounded, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
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
          const Spacer(),
          _NfcStatusBadge(available: _nfcAvailable),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
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

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _isScanning ? _cancelScan : _startScan,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: _nfcAvailable && !_isScanning
              ? const LinearGradient(
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
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Center(
          child: _isScanning
              ? const Row(
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
                    const SizedBox(width: 8),
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

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat Scan',
          style: TextStyle(
            color: AppTheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._history.take(5).map((card) => _HistoryTile(
              card: card,
              onTap: () => _showResult(card),
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NfcStatusBadge extends StatelessWidget {
  final bool available;
  const _NfcStatusBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          const SizedBox(width: 6),
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
  const _HistoryTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.cardName ?? card.cardType,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.shortUid,
                    style: const TextStyle(
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
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${card.scannedAt.hour.toString().padLeft(2, '0')}:'
                  '${card.scannedAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppTheme.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppTheme.onSurfaceMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
