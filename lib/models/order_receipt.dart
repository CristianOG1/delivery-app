/// Una línea del recibo (un platillo con su cantidad). Guardamos el nombre y el
/// precio tal como estaban al pagar, para que el recibo no cambie si después
/// editan el menú.
class ReceiptItem {
  final String name;
  final double unitPrice;
  final int quantity;

  ReceiptItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
    );
  }
}

/// Recibo digital de un pedido ya pagado. Mapea una fila de `orders` con sus
/// `order_items` anidados.
class OrderReceipt {
  final String id;
  final double total;
  final String currency;
  final String? receiptUrl;
  final DateTime? paidAt;
  final DateTime createdAt;
  final List<ReceiptItem> items;

  OrderReceipt({
    required this.id,
    required this.total,
    required this.currency,
    this.receiptUrl,
    this.paidAt,
    required this.createdAt,
    required this.items,
  });

  /// Número corto para mostrar al cliente (primeros 8 caracteres del id).
  String get number =>
      (id.length >= 8 ? id.substring(0, 8) : id).toUpperCase();

  factory OrderReceipt.fromMap(Map<String, dynamic> map) {
    final rawItems = map['order_items'] as List<dynamic>? ?? [];

    return OrderReceipt(
      id: map['id'] as String,
      total: (map['total'] as num).toDouble(),
      currency: (map['currency'] as String? ?? 'mxn').toUpperCase(),
      receiptUrl: map['receipt_url'] as String?,
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      items: [
        for (final i in rawItems)
          ReceiptItem.fromMap(i as Map<String, dynamic>),
      ],
    );
  }
}
