class TransactionModel {
  final int? id;
  final int entryId;
  final double amount;
  final String date;
  final String description;
  final String type; // 'CREDIT' or 'DEBIT'

  TransactionModel({
    this.id,
    required this.entryId,
    required this.amount,
    required this.date,
    required this.description,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entryId': entryId,
      'amount': amount,
      'date': date,
      'description': description,
      'type': type,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      entryId: map['entryId'],
      amount: (map['amount'] as num).toDouble(),
      date: map['date'],
      description: map['description'],
      type: map['type'],
    );
  }
}
