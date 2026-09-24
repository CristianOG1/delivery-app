import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/offer_card.dart';
import '../widgets/restaurant_card.dart';
import 'cart_screen.dart';
import 'menu_item_detail_screen.dart';
import 'profile_screen.dart';
import 'restaurant_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final featuredAsync = ref.watch(featuredItemsProvider);
    final restaurantsAsync = ref.watch(filteredRestaurantsProvider);
    final menuItemsAsync = ref.watch(filteredMenuItemsProvider);
    final cartCount = ref.watch(cartCountProvider);

    final firstName = (user?.fullName ?? user?.email ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(firstName.isEmpty ? 'Delivery App' : 'Hola, $firstName'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Mi carrito',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              if (cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$cartCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantsProvider);
          ref.invalidate(featuredItemsProvider);
          ref.invalidate(allMenuItemsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ---------- Buscador ----------
            TextField(
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: 'Busca restaurantes o platillos...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---------- Ofertas ----------
            const _SectionTitle('Ofertas para ti'),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: featuredAsync.when(
                data: (items) => items.isEmpty
                    ? const Center(child: Text('Sin ofertas por ahora'))
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: items
                            .map((item) => OfferCard(
                                  item: item,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MenuItemDetailScreen(item: item),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
            const SizedBox(height: 24),

            // ---------- Restaurantes ----------
            const _SectionTitle('Restaurantes'),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: restaurantsAsync.when(
                data: (restaurants) => restaurants.isEmpty
                    ? const Center(child: Text('No se encontraron restaurantes'))
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: restaurants
                            .map((r) => RestaurantCard(
                                  restaurant: r,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RestaurantDetailScreen(restaurant: r),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
            const SizedBox(height: 24),

            // ---------- Platillos ----------
            const _SectionTitle('Platillos populares'),
            const SizedBox(height: 8),
            menuItemsAsync.when(
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No se encontraron platillos'),
                    )
                  : Column(
                      children: items
                          .map((item) => MenuItemCard(
                                item: item,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MenuItemDetailScreen(item: item),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}