import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/menu_item.dart';
import '../providers/cart_provider.dart';

class MenuItemDetailScreen extends ConsumerStatefulWidget {
  final MenuItem item;

  const MenuItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<MenuItemDetailScreen> createState() => _MenuItemDetailScreenState();
}

class _MenuItemDetailScreenState extends ConsumerState<MenuItemDetailScreen> {
  int _quantity = 1;

  void _addToCart() {
    ref.read(cartProvider.notifier).addItem(widget.item, quantity: _quantity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item.name} agregado al carrito ($_quantity)'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                      )
                    : Container(color: Colors.grey.shade300),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (item.restaurantName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.restaurantName!,
                        style: TextStyle(color: Colors.grey.shade300),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 16),
                      Text(item.description!, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text('$_quantity', style: const TextStyle(fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: item.isAvailable ? _addToCart : null,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(
              item.isAvailable
                  ? 'Agregar al carrito · \$${(item.price * _quantity).toStringAsFixed(2)}'
                  : 'No disponible',
            ),
          ),
        ),
      ),
    );
  }
}