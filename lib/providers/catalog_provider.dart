import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';

/// Texto actual escrito en el buscador. Lo separamos de la carga de datos
/// para que escribir no dispare peticiones nuevas a Supabase, solo filtra
/// lo que ya está en memoria.
final searchQueryProvider = StateProvider<String>((ref) => '');

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final data = await supabase
      .from('restaurants')
      .select()
      .order('rating', ascending: false);

  return (data as List)
      .map((e) => Restaurant.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// Platillos marcados como oferta (is_featured = true) para el carrusel
/// de "Ofertas para ti".
final featuredItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final data = await supabase
      .from('menu_items')
      .select('*, restaurants(name)')
      .eq('is_featured', true)
      .eq('is_available', true);

  return (data as List)
      .map((e) => MenuItem.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// Todos los platillos disponibles, para la sección "Platillos populares".
final allMenuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final data = await supabase
      .from('menu_items')
      .select('*, restaurants(name)')
      .eq('is_available', true)
      .order('created_at', ascending: false);

  return (data as List)
      .map((e) => MenuItem.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// Restaurantes filtrados según lo que el usuario escribió en el buscador
/// (por nombre o categoría). No vuelve a llamar a Supabase, solo filtra.
final filteredRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final restaurantsAsync = ref.watch(restaurantsProvider);

  return restaurantsAsync.whenData((restaurants) {
    if (query.isEmpty) return restaurants;
    return restaurants
        .where((r) =>
            r.name.toLowerCase().contains(query) ||
            (r.category?.toLowerCase().contains(query) ?? false))
        .toList();
  });
});

/// Platillos de un restaurante específico, para la pantalla de detalle.
/// El '.family' permite pasarle el restaurantId como parámetro.
final restaurantMenuItemsProvider =
    FutureProvider.family<List<MenuItem>, String>((ref, restaurantId) async {
  final data = await supabase
      .from('menu_items')
      .select()
      .eq('restaurant_id', restaurantId)
      .eq('is_available', true);

  return (data as List)
      .map((e) => MenuItem.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// Platillos filtrados según el buscador (por nombre).
final filteredMenuItemsProvider = Provider<AsyncValue<List<MenuItem>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final itemsAsync = ref.watch(allMenuItemsProvider);

  return itemsAsync.whenData((items) {
    if (query.isEmpty) return items;
    return items.where((i) => i.name.toLowerCase().contains(query)).toList();
  });
});