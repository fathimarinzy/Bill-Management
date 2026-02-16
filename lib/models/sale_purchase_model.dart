class SalePurchaseEntry {
  final int? id;
  final String itemName;
  final double salePrice;
  final double purchasePrice;
  final String date;

  SalePurchaseEntry({
    this.id,
    required this.itemName,
    required this.salePrice,
    required this.purchasePrice,
    required this.date,
  });

  double get profit => salePrice - purchasePrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'salePrice': salePrice,
      'purchasePrice': purchasePrice,
      'date': date,
    };
  }

  factory SalePurchaseEntry.fromMap(Map<String, dynamic> map) {
    return SalePurchaseEntry(
      id: map['id'],
      itemName: map['itemName'],
      salePrice: (map['salePrice'] as num).toDouble(),
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      date: map['date'],
    );
  }
}
