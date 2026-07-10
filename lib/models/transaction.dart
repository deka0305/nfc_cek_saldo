/// Satu baris riwayat transaksi kartu e-money.
/// Bentuk data dari library:
/// {"amount": ..., "balance": ..., "date": ..., "type": ..., "tid": ...}
class CardTransaction {
  final int amount;
  final String date;

  /// Kode tipe transaksi mentah dari kartu (mis. "2001" = pembayaran,
  /// "5001" = top-up). Disimpan apa adanya; label ramah lihat [typeLabel].
  final String type;

  /// Terminal ID — nomor identitas mesin/terminal tempat transaksi terjadi
  /// (mis. gardu tol, EDC toko). BUKAN lokasi geografis. Kosong bila kartu
  /// tidak menyediakannya (mis. BNI).
  final String tid;

  /// Saldo pada kartu setelah transaksi ini. Null bila tidak tersedia.
  final int? balance;

  /// Nomor urut transaksi di kartu (counter). Kosong bila tidak tersedia.
  final String counter;

  CardTransaction({
    required this.amount,
    required this.date,
    required this.type,
    this.tid = '',
    this.balance,
    this.counter = '',
  });

  factory CardTransaction.fromJson(Map<String, dynamic> json) {
    int? parseIntOrNull(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    return CardTransaction(
      amount: parseIntOrNull(json['amount']) ?? 0,
      date: json['date']?.toString() ?? '-',
      type: json['type']?.toString() ?? '-',
      tid: json['tid']?.toString() ?? '',
      balance: parseIntOrNull(json['balance']),
      counter: json['counter']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date,
        'type': type,
        'tid': tid,
        'balance': balance,
        'counter': counter,
      };

  static String _rupiah(int value) {
    final str = value.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp $buf';
  }

  /// Nominal tanpa tanda, mis. "Rp 1.234.567". Tanda +/- ditambahkan di UI
  /// berdasarkan [isTopUp] agar tampilan konsisten walau data selalu positif.
  String get formattedAmount => _rupiah(amount);

  /// Saldo setelah transaksi dalam format rupiah, atau '-' bila tidak ada.
  String get formattedBalance => balance != null ? _rupiah(balance!) : '-';

  /// Tanggal terformat rapi "DD/MM/YYYY HH:mm", atau string asli bila gagal parse.
  String get formattedDate {
    final dt = dateTime;
    if (dt == null) return date;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
  }

  /// Parse `date` (format library "YYYY-M-D H:m:s", tanpa padding) menjadi
  /// DateTime untuk pengurutan. Null bila format tidak dikenali.
  DateTime? get dateTime {
    try {
      final parts = date.split(' ');
      final d = parts[0].split('-');
      final t = parts.length > 1 ? parts[1].split(':') : ['0', '0', '0'];
      if (d.length < 3) return null;
      return DateTime(
        int.parse(d[0]),
        int.parse(d[1]),
        int.parse(d[2]),
        t.isNotEmpty ? int.parse(t[0]) : 0,
        t.length > 1 ? int.parse(t[1]) : 0,
        t.length > 2 ? int.parse(t[2]) : 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// True bila transaksi menambah saldo (top-up / isi ulang).
  /// Deteksi: kode top-up yang diketahui (5001) atau kata kunci umum.
  bool get isTopUp {
    if (amount < 0) return false;
    final t = type.toLowerCase();
    return type == '5001' ||
        t.contains('top') ||
        t.contains('isi') ||
        t.contains('load') ||
        t.contains('reload') ||
        t.contains('credit');
  }

  /// Selain top-up dianggap pembayaran (saldo berkurang).
  bool get isDebit => !isTopUp;

  /// Label ramah & universal untuk ditampilkan ke pengguna.
  String get typeLabel => isTopUp ? 'Top-up' : 'Pembayaran';
}
