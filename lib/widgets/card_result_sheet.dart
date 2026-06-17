import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nfc_card.dart';
import '../theme/app_theme.dart';

class CardResultSheet extends StatelessWidget {
  final NfcCard card;
  const CardResultSheet({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.onSurfaceMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildBalanceCard(),
                const SizedBox(height: 20),
                _buildInfoSection(),
                const SizedBox(height: 16),
                if (card.rawData.isNotEmpty) _buildRawDataSection(),
                const SizedBox(height: 32),
              ],
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
      padding: const EdgeInsets.all(24),
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
                  offset: const Offset(0, 8),
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          Text(
            'SALDO',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.formattedBalance,
            style: const TextStyle(
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

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow(Icons.fingerprint, 'UID Kartu', card.uid),
          const Divider(color: AppTheme.onSurfaceMuted, height: 20, thickness: 0.2),
          _infoRow(Icons.contactless, 'Tipe NFC', card.cardType),
          const Divider(color: AppTheme.onSurfaceMuted, height: 20, thickness: 0.2),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
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
            child: const Icon(Icons.copy_rounded,
                color: AppTheme.onSurfaceMuted, size: 16),
          ),
      ],
    );
  }

  Widget _buildRawDataSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Data Teknis',
        style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
      ),
      iconColor: AppTheme.onSurfaceMuted,
      collapsedIconColor: AppTheme.onSurfaceMuted,
      children: card.rawData
          .map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    d,
                    style: const TextStyle(
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
