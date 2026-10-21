import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order_receipt.dart';

/// Recibo digital que se muestra al terminar un pago exitoso.
class ReceiptScreen extends StatelessWidget {
  final OrderReceipt receipt;

  const ReceiptScreen({super.key, required this.receipt});

  String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final fecha = receipt.paidAt ?? receipt.createdAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibo de compra'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 12),
          const Text(
            '¡Pago exitoso!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Recibo #${receipt.number}',
            textAlign: TextAlign.center,
          ),
          Text(
            _fecha(fecha),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const Divider(height: 32),
          for (final i in receipt.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i.quantity} × ${i.name}  (\$${i.unitPrice.toStringAsFixed(2)} c/u)',
                    ),
                  ),
                  Text('\$${i.subtotal.toStringAsFixed(2)}'),
                ],
              ),
            ),
          const Divider(height: 32),
          Row(
            children: [
              const Text(
                'Total pagado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '\$${receipt.total.toStringAsFixed(2)} ${receipt.currency}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pagado con tarjeta · Procesado por Stripe',
            style: TextStyle(color: Colors.black54),
          ),
          if (receipt.receiptUrl != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: receipt.receiptUrl!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enlace del recibo de Stripe copiado'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link),
              label: const Text('Copiar enlace del recibo de Stripe'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }
}
