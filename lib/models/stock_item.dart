class StockItem {
  final int? id;
  final String name;
  final double? rate;
  final double quantity;

  StockItem({
    this.id,
    required this.name,
    this.rate,
    this.quantity = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'quantity': quantity,
    };
  }

  factory StockItem.fromMap(Map<String, dynamic> map) {
    return StockItem(
      id: map['id'],
      name: map['name'],
      rate: map['rate'] != null ? (map['rate'] as num).toDouble() : null,
      quantity: (map['quantity'] as num).toDouble(),
    );
  }
}
