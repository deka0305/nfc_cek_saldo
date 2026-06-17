class NfcCard {
  final String uid;
  final String cardType;
  final String techType;
  final int? balance;
  final String? cardName;
  final List<String> rawData;
  final DateTime scannedAt;

  NfcCard({
    required this.uid,
    required this.cardType,
    required this.techType,
    this.balance,
    this.cardName,
    required this.rawData,
    required this.scannedAt,
  });

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

  String get shortUid {
    final clean = uid.replaceAll(':', '').replaceAll(' ', '').toUpperCase();
    if (clean.length <= 8) return clean;
    return '${clean.substring(0, 4)}...${clean.substring(clean.length - 4)}';
  }
}
