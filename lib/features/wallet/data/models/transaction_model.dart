enum TransactionType { credit, debit }

class TransactionModel {
  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final String amount;
  final TransactionType type;
  final String tag;
  final DateTime date;

  const TransactionModel({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.tag,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Backend returns: id, user_id, amount (float), type, description, timestamp
    final rawAmount = json['amount'];
    String amountStr;
    if (rawAmount is num) {
      amountStr = rawAmount.toStringAsFixed(2);
    } else {
      amountStr = rawAmount as String? ?? '0.00';
    }

    final typeStr = json['type'] as String? ?? 'debit';
    final txType = typeStr.toLowerCase() == 'credit' ? TransactionType.credit : TransactionType.debit;

    // Map backend 'description' to title, fall back to Flutter's 'title'
    final title = json['title'] as String? ?? json['description'] as String? ?? '';

    DateTime date;
    try {
      final ts = json['date'] ?? json['timestamp'] ?? json['created_at'];
      if (ts is String && ts.isNotEmpty) {
        date = DateTime.parse(ts);
      } else {
        date = DateTime.now();
      }
    } catch (_) {
      date = DateTime.now();
    }

    return TransactionModel(
      id: json['id'] as String? ?? '',
      icon: json['icon'] as String? ?? (txType == TransactionType.credit ? 'add_circle_rounded' : 'remove_circle_rounded'),
      title: title,
      subtitle: json['subtitle'] as String? ?? '',
      amount: amountStr,
      type: txType,
      tag: json['tag'] as String? ?? typeStr,
      date: date,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'icon': icon,
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'type': type == TransactionType.credit ? 'credit' : 'debit',
        'tag': tag,
        'date': date.toIso8601String(),
      };
}
