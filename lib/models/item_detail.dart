class ItemDetail {
  final int? id;
  final int entryId;
  final String itemName;
  final double rate;
  final double quantity;
  final double totalPrice;
  final String dateAdded;

  ItemDetail({
    this.id,
    required this.entryId,
    required this.itemName,
    required this.rate,
    required this.quantity,
    required this.totalPrice,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entryId': entryId,
      'itemName': itemName,
      'rate': rate,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'dateAdded': dateAdded,
    };
  }

  factory ItemDetail.fromMap(Map<String, dynamic> map) {
    return ItemDetail(
      id: map['id'],
      entryId: map['entryId'],
      itemName: map['itemName'],
      rate: map['rate'],
      quantity: map['quantity'],
      totalPrice: map['totalPrice'],
      dateAdded: map['dateAdded'],
    );
  }
}
