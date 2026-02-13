class AccountingEntry {
  final int? id;
  final int userId;
  final String name;
  final String phone;
  final double advanceAmount;
  final double creditAmount;
  final double debitAmount;
  final String date;
  final String? imagePath;

  AccountingEntry({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.advanceAmount = 0.0,
    required this.creditAmount,
    required this.debitAmount,
    required this.date,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'advanceAmount': advanceAmount,
      'creditAmount': creditAmount,
      'debitAmount': debitAmount,
      'date': date,
      'imagePath': imagePath,
    };
  }

  factory AccountingEntry.fromMap(Map<String, dynamic> map) {
    return AccountingEntry(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      phone: map['phone'],
      advanceAmount: map['advanceAmount'] ?? 0.0,
      creditAmount: map['creditAmount'],
      debitAmount: map['debitAmount'],
      date: map['date'],
      imagePath: map['imagePath'],
    );
  }
}
