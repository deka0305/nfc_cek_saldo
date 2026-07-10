import 'transaction.dart';

class NfcCard {
  final String uid;
  final String cardType;
  final String techType;
  final int? balance;
  final String? cardName;
  final String? cardNumber;
  final String? bankName;
  final List<CardTransaction> history;
  final List<String> rawData;
  final DateTime scannedAt;

  NfcCard({
    required this.uid,
    required this.cardType,
    required this.techType,
    this.balance,
    this.cardName,
    this.cardNumber,
    this.bankName,
    this.history = const [],
    required this.rawData,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'cardType': cardType,
        'techType': techType,
        'balance': balance,
        'cardName': cardName,
        'cardNumber': cardNumber,
        'bankName': bankName,
        'history': history.map((t) => t.toJson()).toList(),
        'rawData': rawData,
        'scannedAt': scannedAt.toIso8601String(),
      };

  factory NfcCard.fromJson(Map<String, dynamic> json) {
    return NfcCard(
      uid: json['uid']?.toString() ?? 'Unknown',
      cardType: json['cardType']?.toString() ?? 'Kartu e-Money',
      techType: json['techType']?.toString() ?? 'NFC',
      balance: json['balance'] is num ? (json['balance'] as num).toInt() : null,
      cardName: json['cardName']?.toString(),
      cardNumber: json['cardNumber']?.toString(),
      bankName: json['bankName']?.toString(),
      history: (json['history'] as List?)
              ?.whereType<Map>()
              .map((e) => CardTransaction.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList() ??
          const [],
      rawData: (json['rawData'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      scannedAt:
          DateTime.tryParse(json['scannedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get formattedBalance {
    if (balance == null) return 'Tidak Terdeteksi';
    final b = balance!;
    if (b < 0) return 'Error';
    final str = b.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return 'Rp $result';
  }

  /// Nomor kartu diformat 4-4-4-4 bila panjang & numerik.
  String get formattedCardNumber {
    final n = cardNumber;
    if (n == null || n.isEmpty) return '-';
    final clean = n.replaceAll(RegExp(r'\s'), '');
    if (clean.length < 8) return clean;
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(clean[i]);
    }
    return buf.toString();
  }

  String get shortUid {
    final clean = uid.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
    if (clean.length <= 8) return clean;
    return '${clean.substring(0, 4)}...${clean.substring(clean.length - 4)}';
  }
}
