# delivery_app — Notas para agentes

App Flutter de delivery con Riverpod + Supabase + Stripe. Todo el texto de UI y los comentarios del código están en español; mantén ese idioma en lo nuevo. El `README.md` sigue siendo la plantilla por defecto de Flutter y no describe la app; no lo uses como referencia.

## Comandos

- `flutter pub get` — instala dependencias (Flutter 3.47.5 / Dart 3.13.4 instalados).
- `flutter run -d windows` (o `-d chrome`, `-d <device>`) — requiere acceso de red al proyecto remoto de Supabase; no hay backend local. El cobro con Stripe solo funciona en Android/iOS.
- `flutter analyze` — termina con código 1 por un solo aviso info: `anonKey` deprecado en `lib/core/supabase_client.dart:20`. Si en Windows aparece `Building with plugins requires symlink support` (p. ej. tras un `flutter pub get` con plugins), habilita el Modo para desarrolladores (`start ms-settings:developers`) o usa `dart analyze lib test`.
- `flutter test` — **ahora mismo falla y no sirve como gate**: `test/widget_test.dart` es la plantilla vieja del contador y monta `MyApp` sin `ProviderScope`/Supabase. Reescribe las pruebas con `ProviderScope` + overrides de providers en lugar de agregar más pruebas encima de eso.
- Una sola prueba: `flutter test test/widget_test.dart --plain-name "<nombre de la prueba>"`.
- `flutter build apk --release` — genera `build/app/outputs/flutter-apk/app-release.apk`. En Windows requiere el Modo para desarrolladores (symlinks). Sin keystore propio firma con la clave de debug: sirve para pruebas, no para Play Store (para eso, `flutter build appbundle --release`).
- `codegraph sync` actualiza el índice `.codegraph/` tras editar código; `codegraph init` solo hace falta si el índice no existe. `.codegraph/` ya está creado y en `.gitignore`.
- No hay CI, pre-commit, build_runner ni codegen; ejecuta analyze/tests manualmente.

## Arquitectura

- Entrypoint `lib/main.dart`: `SupabaseConfig.initialize()` → inicializa Stripe (solo Android/iOS y si hay clave) → `ProviderScope` → `MyApp` → `AuthGate`, que muestra `LoginScreen` o `HomeScreen` según el stream de auth. No hay paquete de routing; la navegación es `Navigator.push` + `MaterialPageRoute`.
- `lib/core/supabase_client.dart` tiene hardcodeados la URL y la publishable key de Supabase y expone un cliente global `supabase`. La mención de `--dart-define` en su comentario es aspiracional: esos valores no se leen. Los providers asumen que `initialize()` ya corrió; leer `supabase` antes lanza excepción.
- `lib/core/stripe_config.dart` ya tiene configurada una publishable key de prueba (`pk_test_...`); no la cambies por una secreta. El cobro solo se habilita en Android/iOS y requiere que las Edge Functions estén desplegadas con `STRIPE_SECRET_KEY`; si la key falta o es inválida, la pantalla de pago solo muestra un aviso.
- `lib/providers/`: `auth_provider` (stream de auth + mutaciones con `AsyncNotifier`), `catalog_provider` (`FutureProvider`s de `restaurants`/`menu_items`, búsqueda filtrada en cliente), `cart_provider` (`StateNotifier`, **solo en memoria**), `checkout_provider` (`AutoDisposeAsyncNotifier` que orquesta el pago), `courier_provider` (perfil de repartidor, documentos y viajes).
- Repartidores: se entra desde el icono de moto en el AppBar de `HomeScreen`. `CourierController` lee `couriers` por `id = auth.uid` y se recarga al iniciar/cerrar sesión; `setOnline(true)` falla si `status != 'approved'`. El registro es en 2 pasos (datos/vehículo y luego documentos); sube a Storage en `${userId}/${docType}.${ext}` y hace upsert en `courier_documents` (jpg/jpeg/png/pdf, máx. 5 MB). No hay UI de aprobación: los `status` (`pending|approved|rejected`) se cambian fuera de la app.
- Flujo de pago (`checkout_provider`): carrito → Edge Function `create-payment-intent` (crea `orders`/`order_items` en estado `pending` y calcula el total con precios de la BD; la app solo manda ids y cantidades) → PaymentSheet nativo de Stripe → Edge Function `confirm-payment` (verifica el cobro con Stripe, compara el monto y marca `paid`, devolviendo el recibo). El carrito se vacía solo tras confirmar.
- `lib/screens/checkout_screen.dart` escucha `checkoutControllerProvider` y navega a `ReceiptScreen` con `pushReplacement` cuando el pago termina; un pago cancelado vuelve a `null` sin error. Si cambias el estado del controller, conserva esa transición `loading → data/error`.
- Android: `MainActivity` debe extender `FlutterFragmentActivity` (no `FlutterActivity`) para que funcione la hoja de Stripe. `android/build.gradle.kts` desactiva `lintVitalAnalyzeRelease` de `stripe_android`; es intencional, no lo borres.

## Backend Supabase

- El catálogo y las tablas de repartidores viven fuera del repo; solo los pedidos tienen SQL (`supabase/orders.sql`). Tablas: `profiles`, `restaurants`, `menu_items`, `couriers`, `courier_documents`, `deliveries`, `orders` y `order_items`.
- `restaurants`: `id,name,description,image_url,category,rating,address,is_open`. `menu_items`: `id,restaurant_id,name,description,price,image_url,category,is_available,is_featured,created_at`. `orders`: `id,user_id,status,total,currency,stripe_payment_intent_id,receipt_url,paid_at,created_at`; `order_items`: `id,order_id,menu_item_id,name,unit_price,quantity`.
- Tablas de repartidores (existen en el proyecto remoto, pero **no hay SQL versionado** en el repo; si recreas el proyecto hay que crearlas a mano): `couriers` (`id` = auth user, `full_name,phone,vehicle_type,plate,status,is_online`), `courier_documents` (`courier_id,doc_type,file_path,status,uploaded_at`, único por `courier_id,doc_type` para el upsert) y `deliveries` (`id,courier_id,order_id,restaurant_name,dropoff_address,distance_km,earnings,tip,status,completed_at`). También hace falta el bucket de Storage `courier-documents`.
- Existe `public.profiles` (`id,full_name,phone,avatar_url`), pero la app **no la usa**: nombre y teléfono se guardan en `auth.users.user_metadata` con `updateUser` y se leen de ahí. Actualizar `profiles` no cambia el perfil en la app.
- `supabase/orders.sql` se aplica **una sola vez a mano** en el SQL Editor del dashboard. RLS: el cliente autenticado solo puede leer sus propios pedidos/items; los insert/update los hacen las Edge Functions con service role.
- `supabase/functions/create-payment-intent` y `confirm-payment` son funciones Deno (`npm:@supabase/supabase-js@2`) que requieren el secret `STRIPE_SECRET_KEY`; `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta Supabase. Ambas ya están desplegadas y `ACTIVE`; si las editas, vuelve a desplegarlas. No hay migraciones versionadas (`list_migrations` vacío), ni `supabase/config.toml`, ni CLI local: usa el dashboard (o instala la CLI) en vez de asumir un `supabase start`.
- Las filas son snake_case; las consultas de menú usan `select('*, restaurants(name)')`, por eso `MenuItem.restaurantName` viene del mapa anidado `restaurants`. El recibo usa `select('*, order_items(*)')` de forma equivalente.
- MCP de Supabase remoto configurado en `opencode.jsonc` para el project ref de la app (`read_only=true`, OAuth). Úsalo para inspeccionar esquema/RLS, advisors y logs; no apliques migraciones ni cambios sin confirmación.

## Convenciones

- `lib/screens` = páginas, `lib/widgets` = tarjetas/campos reutilizables, `lib/models` = clases simples que mapean filas (sin codegen). Mantén el estado compartido en providers; el estado local de pantalla es solo UI transitoria (p. ej. cantidad).
- No edites a mano archivos generados de Flutter: `ios/Flutter/Generated.xcconfig`, `*/flutter/generated_plugin*`, `android/**/GeneratedPluginRegistrant.java`.
- `analysis_options.yaml` excluye las carpetas de plataforma, así que `flutter analyze` solo cubre el Dart de `lib/` y `test/`.
- Skills locales en `.agents/skills/` (fijadas en `skills-lock.json`): carga `supabase` para tareas de Supabase y `supabase-postgres-best-practices` antes de tocar esquema, RLS, índices o migraciones.

<!-- CODEGRAPH_START -->
## CodeGraph

En repositorios indexados por CodeGraph (existe un directorio `.codegraph/` en la raíz del repo), usa CodeGraph ANTES de grep/find o de leer archivos cuando necesites entender o localizar código:

- **Herramienta MCP** (cuando esté disponible): `codegraph_explore` responde la mayoría de preguntas de código en una sola llamada: el código fuente literal de los símbolos relevantes, las rutas de llamada entre ellos y un resumen del radio de impacto, incluyendo saltos de despacho dinámico que grep no puede seguir. Nombra un archivo o símbolo en la consulta para leer su código fuente actual con números de línea. Si aparece listada pero diferida, cárgala por nombre con la búsqueda de herramientas.
- **Shell** (siempre funciona): `codegraph explore "<nombres de símbolos o pregunta>"` imprime lo mismo.

Si no hay un directorio `.codegraph/`, ignora CodeGraph por completo: indexar es decisión del usuario.
<!-- CODEGRAPH_END -->
