class InvoiceItemModel {
  final int? id;
  final int transactionId;
  final String itemName;
  final double quantity;
  final String unit;
  final double rate;
  final double total;

  InvoiceItemModel({
    this.id,
    required this.transactionId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'total': total,
    };
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'],
      transactionId: map['transactionId'],
      itemName: map['itemName'],
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'],
      rate: (map['rate'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }
}
