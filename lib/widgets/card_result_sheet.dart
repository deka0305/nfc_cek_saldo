import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/nfc_card.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class CardResultSheet extends StatelessWidget {
  final NfcCard card;
  CardResultSheet({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.onSurfaceMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildBalanceCard(),
                  SizedBox(height: 12),
                  _buildShareButton(),
                  SizedBox(height: 20),
                  _buildInfoSection(),
                  SizedBox(height: 16),
                  if (card.history.isNotEmpty) _buildHistorySection(context),
                  if (card.rawData.isNotEmpty) _buildRawDataSection(),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final hasBalance = card.balance != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasBalance
              ? [AppTheme.primary, AppTheme.secondary]
              : [AppTheme.surfaceVariant, AppTheme.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: hasBalance
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasBalance ? Icons.account_balance_wallet : Icons.credit_card,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                card.cardName ?? card.cardType,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'SALDO',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            card.formattedBalance,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _shareCard,
        icon: Icon(Icons.share_outlined, size: 18, color: AppTheme.primary),
        label: Text('Bagikan / Ekspor',
            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Susun ringkasan kartu + riwayat sebagai teks lalu buka menu share Android.
  void _shareCard() {
    final b = StringBuffer();
    b.writeln('=== NFC Cek Saldo ===');
    b.writeln('Kartu   : ${card.cardName ?? card.cardType}');
    if (card.cardNumber != null && card.cardNumber!.isNotEmpty) {
      b.writeln('Nomor   : ${card.formattedCardNumber}');
    }
    b.writeln('Saldo   : ${card.formattedBalance}');
    b.writeln('UID     : ${card.uid}');
    b.writeln('Discan  : ${card.scannedAt}');

    if (card.history.isNotEmpty) {
      b.writeln('\n--- Riwayat Transaksi (${card.history.length}) ---');
      var i = 1;
      for (final t in card.history) {
        final sign = t.isDebit ? '-' : '+';
        final sisa = t.balance != null ? ' (sisa ${t.formattedBalance})' : '';
        b.writeln(
            '${i++}. ${t.formattedDate} | ${t.typeLabel} | $sign${t.formattedAmount}$sisa');
      }
    }
    SharePlus.instance.share(
      ShareParams(
        text: b.toString(),
        subject: 'Data kartu ${card.cardName ?? ''}'.trim(),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (card.bankName != null && card.bankName!.isNotEmpty) ...[
            _infoRow(Icons.account_balance, 'Bank / Kartu', card.bankName!),
            Divider(
                color: AppTheme.onSurfaceMuted, height: 20, thickness: 0.2),
          ],
          if (card.cardNumber != null && card.cardNumber!.isNotEmpty) ...[
            _infoRow(Icons.credit_card, 'Nomor Kartu', card.formattedCardNumber),
            Divider(
                color: AppTheme.onSurfaceMuted, height: 20, thickness: 0.2),
          ],
          _infoRow(Icons.fingerprint, 'UID Kartu', card.uid),
          Divider(color: AppTheme.onSurfaceMuted, height: 20, thickness: 0.2),
          _infoRow(Icons.contactless, 'Tipe NFC', card.cardType),
          Divider(color: AppTheme.onSurfaceMuted, height: 20, thickness: 0.2),
          _infoRow(Icons.access_time, 'Waktu Scan',
              '${card.scannedAt.hour.toString().padLeft(2, '0')}:'
              '${card.scannedAt.minute.toString().padLeft(2, '0')}:'
              '${card.scannedAt.second.toString().padLeft(2, '0')}'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 11)),
              SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (label == 'UID Kartu')
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: value)),
            child: Icon(Icons.copy_rounded,
                color: AppTheme.onSurfaceMuted, size: 16),
          ),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Riwayat Transaksi',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Text(
                '${card.history.length} transaksi',
                style: TextStyle(
                  color: AppTheme.onSurfaceMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          ...card.history.map((txn) => _transactionRow(context, txn)),
        ],
      ),
    );
  }

  Widget _transactionRow(BuildContext context, CardTransaction txn) {
    final isDebit = txn.isDebit;
    return InkWell(
      onTap: () => _showTransactionDetail(context, txn),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDebit ? AppTheme.error : AppTheme.success)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDebit
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isDebit ? AppTheme.error : AppTheme.success,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.typeLabel,
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    txn.formattedDate,
                    style: TextStyle(
                      color: AppTheme.onSurfaceMuted,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${isDebit ? '-' : '+'} ${txn.formattedAmount}',
              style: TextStyle(
                color: isDebit ? AppTheme.error : AppTheme.success,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, CardTransaction txn) {
    final isDebit = txn.isDebit;
    final color = isDebit ? AppTheme.error : AppTheme.success;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onSurfaceMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDebit
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    txn.typeLabel,
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${isDebit ? '-' : '+'} ${txn.formattedAmount}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _detailRow('Tanggal & Jam', txn.formattedDate),
            if (txn.balance != null)
              _detailRow('Saldo setelah transaksi', txn.formattedBalance),
            if (txn.tid.isNotEmpty) _detailRow('No. Mesin (Terminal)', txn.tid),
            if (txn.counter.isNotEmpty) _detailRow('No. Urut', txn.counter),
            _detailRow('Kode Tipe', txn.type),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.onSurfaceMuted, fontSize: 13)),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Data Teknis',
        style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
      ),
      iconColor: AppTheme.onSurfaceMuted,
      collapsedIconColor: AppTheme.onSurfaceMuted,
      children: card.rawData
          .map((d) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
