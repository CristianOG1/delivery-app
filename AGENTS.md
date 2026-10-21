# delivery_app — Notas para agentes

App Flutter de delivery con Riverpod + Supabase + Stripe. Todo el texto de UI y los comentarios del código están en español; mantén ese idioma en lo nuevo. El `README.md` sigue siendo la plantilla por defecto de Flutter y no describe la app; no lo uses como referencia.

## Comandos

- `flutter pub get` — instala dependencias (Flutter 3.47.5 / Dart 3.13.4 instalados).
- `flutter run -d windows` (o `-d chrome`, `-d <device>`) — requiere acceso de red al proyecto remoto de Supabase; no hay backend local. El cobro con Stripe solo funciona en Android/iOS.
- `flutter analyze` — actualmente termina con código 1 por 2 deprecaciones de nivel info (`anonKey` en `lib/core/supabase_client.dart:20`, `withOpacity` en `lib/widgets/offer_card.dart`). Solo considera regresiones los errores/warnings nuevos.
- `flutter test` — **ahora mismo falla y no sirve como gate**: `test/widget_test.dart` es la plantilla vieja del contador y monta `MyApp` sin `ProviderScope`/Supabase. Reescribe las pruebas con `ProviderScope` + overrides de providers en lugar de agregar más pruebas encima de eso.
- Una sola prueba: `flutter test test/widget_test.dart --plain-name "<nombre de la prueba>"`.
- No hay CI, pre-commit, build_runner ni codegen; ejecuta analyze/tests manualmente.

## Arquitectura

- Entrypoint `lib/main.dart`: `SupabaseConfig.initialize()` → inicializa Stripe (solo Android/iOS y si hay clave) → `ProviderScope` → `MyApp` → `AuthGate`, que muestra `LoginScreen` o `HomeScreen` según el stream de auth. No hay paquete de routing; la navegación es `Navigator.push` + `MaterialPageRoute`.
- `lib/core/supabase_client.dart` tiene hardcodeados la URL y la publishable key de Supabase y expone un cliente global `supabase`. La mención de `--dart-define` en su comentario es aspiracional: esos valores no se leen. Los providers asumen que `initialize()` ya corrió; leer `supabase` antes lanza excepción.
- `lib/core/stripe_config.dart` contiene una publishable key de prueba **placeholder** (`pk_test_REEMPLAZA...`); mientras no se reemplace, la pantalla de pago solo muestra un aviso y no cobra. La clave secreta (`sk_...`) nunca va en el repo: vive en los secrets de las Edge Functions.
- `lib/providers/`: `auth_provider` (stream de auth + mutaciones con `AsyncNotifier`), `catalog_provider` (`FutureProvider`s de `restaurants`/`menu_items`, búsqueda filtrada en cliente), `cart_provider` (`StateNotifier`, **solo en memoria**), `checkout_provider` (`AutoDisposeAsyncNotifier` que orquesta el pago).
- Flujo de pago (`checkout_provider`): carrito → Edge Function `create-payment-intent` (crea `orders`/`order_items` en estado `pending` y calcula el total con precios de la BD; la app solo manda ids y cantidades) → PaymentSheet nativo de Stripe → Edge Function `confirm-payment` (verifica el cobro con Stripe, compara el monto y marca `paid`, devolviendo el recibo). El carrito se vacía solo tras confirmar.
- `lib/screens/checkout_screen.dart` escucha `checkoutControllerProvider` y navega a `ReceiptScreen` con `pushReplacement` cuando el pago termina; un pago cancelado vuelve a `null` sin error. Si cambias el estado del controller, conserva esa transición `loading → data/error`.
- Android: `MainActivity` debe extender `FlutterFragmentActivity` (no `FlutterActivity`) para que funcione la hoja de Stripe. `android/build.gradle.kts` desactiva `lintVitalAnalyzeRelease` de `stripe_android`; es intencional, no lo borres.

## Backend Supabase

- El esquema de catálogo vive fuera del repo; las tablas de pedidos sí están en `supabase/orders.sql`. Tablas: `restaurants`, `menu_items`, `orders` y `order_items`.
- `restaurants`: `id,name,description,image_url,category,rating,address,is_open`. `menu_items`: `id,restaurant_id,name,description,price,image_url,category,is_available,is_featured,created_at`. `orders`: `id,user_id,status,total,currency,stripe_payment_intent_id,receipt_url,paid_at,created_at`; `order_items`: `id,order_id,menu_item_id,name,unit_price,quantity`.
- `supabase/orders.sql` se aplica **una sola vez a mano** en el SQL Editor del dashboard. RLS: el cliente autenticado solo puede leer sus propios pedidos/items; los insert/update los hacen las Edge Functions con service role.
- `supabase/functions/create-payment-intent` y `confirm-payment` son funciones Deno (`npm:@supabase/supabase-js@2`) que requieren el secret `STRIPE_SECRET_KEY`; `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta Supabase. No hay `supabase/config.toml` ni CLI de Supabase instalado en este entorno: aplícalas/despliégalas desde el dashboard (o instala la CLI) en vez de asumir un `supabase start` local.
- Las filas son snake_case; las consultas de menú usan `select('*, restaurants(name)')`, por eso `MenuItem.restaurantName` viene del mapa anidado `restaurants`. El recibo usa `select('*, order_items(*)')` de forma equivalente.

## Convenciones

- `lib/screens` = páginas, `lib/widgets` = tarjetas/campos reutilizables, `lib/models` = clases simples que mapean filas (sin codegen). Mantén el estado compartido en providers; el estado local de pantalla es solo UI transitoria (p. ej. cantidad).
- No edites a mano archivos generados de Flutter: `ios/Flutter/Generated.xcconfig`, `*/flutter/generated_plugin*`, `android/**/GeneratedPluginRegistrant.java`.
- `analysis_options.yaml` excluye las carpetas de plataforma, así que `flutter analyze` solo cubre el Dart de `lib/` y `test/`.

<!-- CODEGRAPH_START -->
## CodeGraph

En repositorios indexados por CodeGraph (existe un directorio `.codegraph/` en la raíz del repo), usa CodeGraph ANTES de grep/find o de leer archivos cuando necesites entender o localizar código:

- **Herramienta MCP** (cuando esté disponible): `codegraph_explore` responde la mayoría de preguntas de código en una sola llamada: el código fuente literal de los símbolos relevantes, las rutas de llamada entre ellos y un resumen del radio de impacto, incluyendo saltos de despacho dinámico que grep no puede seguir. Nombra un archivo o símbolo en la consulta para leer su código fuente actual con números de línea. Si aparece listada pero diferida, cárgala por nombre con la búsqueda de herramientas.
- **Shell** (siempre funciona): `codegraph explore "<nombres de símbolos o pregunta>"` imprime lo mismo.

Si no hay un directorio `.codegraph/`, ignora CodeGraph por completo: indexar es decisión del usuario.
<!-- CODEGRAPH_END -->
