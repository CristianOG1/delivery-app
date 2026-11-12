# delivery_app — Notas para agentes

App Flutter de delivery con Riverpod + Supabase + Stripe. Todo el texto de UI y los comentarios del código están en español; mantén ese idioma en lo nuevo. El `README.md` sigue siendo la plantilla por defecto de Flutter y no describe la app; no lo uses como referencia.

## Comandos

- `flutter pub get` — instala dependencias (Flutter 3.47.5 / Dart 3.13.4 instalados).
- `flutter run -d windows` (o `-d chrome`, `-d <device>`) — requiere acceso de red al proyecto remoto de Supabase; no hay backend local. El cobro con Stripe solo funciona en Android/iOS.
- `flutter analyze` — termina con código 1 por un solo aviso info: `anonKey` deprecado en `lib/core/supabase_client.dart:20`. Si en Windows aparece `Building with plugins requires symlink support` (p. ej. tras un `flutter pub get` con plugins), habilita el Modo para desarrolladores (`start ms-settings:developers`) o usa `dart analyze lib test`.
- `flutter test` — **ahora mismo falla y no sirve como gate**: `test/widget_test.dart` es la plantilla vieja del contador y monta `MyApp` sin `ProviderScope`/Supabase. Reescribe las pruebas con `ProviderScope` + overrides de providers en lugar de agregar más pruebas encima de eso.
- Una sola prueba: `flutter test test/widget_test.dart --plain-name "<nombre de la prueba>"`.
- `flutter build apk --release` — ver la sección "Build del APK" más abajo (salida, requisitos y firma).
- `codegraph sync` actualiza el índice `.codegraph/` tras editar código; `codegraph init` solo hace falta si el índice no existe. `.codegraph/` ya está creado y en `.gitignore`.
- No hay CI, pre-commit, build_runner ni codegen; ejecuta analyze/tests manualmente.

## Build del APK (Android)

- `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`; `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (Play Store). `flutter build apk --debug` para iterar. Último build verificado: 64.2 MB, ~3 min.
- Aviso de Gradle que hay que vigilar: `file_picker` aplica el Kotlin Gradle Plugin (KGP) y Flutter avisa que **las versiones futuras dejarán de compilar** hasta que ese plugin migre a Built-in Kotlin. Si el build falla de golpe tras actualizar Flutter, es por esto (sube `file_picker` a la versión que ya use Built-in Kotlin).
- Requisito en Windows: **Modo para desarrolladores** activado (`start ms-settings:developers`), porque los plugins necesitan symlinks; si no, falla con `Building with plugins requires symlink support`.
- Toolchain fijado en el repo: Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Java 17 (`compileOptions` y `jvmTarget`), `android.newDsl=false`.
- Requisitos de `flutter_stripe` (rompen el build o el pago si los tocas): `MainActivity` debe extender `FlutterFragmentActivity`, los temas de `android/app/src/main/res/values/styles.xml` y `values-night/styles.xml` deben heredar de `Theme.AppCompat.*`, y `android/build.gradle.kts` desactiva `lintVitalAnalyzeRelease` de `stripe_android` (intencional, no lo borres).
- Firma: `buildTypes.release` usa la **clave de debug** (`signingConfig = signingConfigs.getByName("debug")`), así que el APK sirve para instalar/probar pero **no** para Play Store. Para publicar: crea un keystore, guarda `key.properties` y `*.jks` (ya ignorados por `android/.gitignore`) y configura el `signingConfig` de release.
- El build compila igual sin `MAPS_API_KEY`: el manifest queda con la key vacía y solo el mapa se ve en blanco.
- `google_maps_flutter` no está configurado en iOS (`ios/Runner/AppDelegate.swift` no llama a `GMSServices.provideAPIKey`): el mapa queda en blanco en iOS hasta añadirlo.

## Secretos y claves

- **API key de Google Maps**: vive en `android/local.properties` (`MAPS_API_KEY=...`, ignorado por git) y se inyecta al manifest como placeholder `${MAPS_API_KEY}` (`android/app/build.gradle.kts`). **No la escribas en `AndroidManifest.xml`**: ese archivo está versionado y la filtraría. Para CI, usa la variable de entorno `MAPS_API_KEY`.
- **Stripe**: en `lib/core/stripe_config.dart` solo va la publishable key (`pk_test_...`, es pública). La secreta (`sk_test_...`) vive solo en los secrets de las Edge Functions de Supabase.
- **Supabase**: `lib/core/supabase_client.dart` tiene la URL y la publishable/anon key (públicas). La `service_role` solo existe dentro de las Edge Functions.
- No hay `.env` en el proyecto ni carga de `.env` en el código. Si agregas uno, git ya lo ignora (`.env` está en `.gitignore`) y no lo leas desde Dart salvo con `--dart-define`.
- La API key de Maps estuvo pegada a mano en `AndroidManifest.xml` en el working tree (nunca llegó a comitearse, pero estuvo expuesta localmente). Si crees que se filtró, rótala en Google Cloud Console y restringe "Maps SDK for Android" por package name + SHA-1.

## Arquitectura

- Entrypoint `lib/main.dart`: `SupabaseConfig.initialize()` → inicializa Stripe (solo Android/iOS y si hay clave) → `ProviderScope` → `MyApp` → `AuthGate`, que muestra `LoginScreen` o `HomeScreen` según el stream de auth. No hay paquete de routing; la navegación es `Navigator.push` + `MaterialPageRoute`.
- `lib/core/supabase_client.dart` tiene hardcodeados la URL y la publishable key de Supabase y expone un cliente global `supabase`. La mención de `--dart-define` en su comentario es aspiracional: esos valores no se leen. Los providers asumen que `initialize()` ya corrió; leer `supabase` antes lanza excepción.
- `lib/core/stripe_config.dart` ya tiene configurada una publishable key de prueba (`pk_test_...`); no la cambies por una secreta. El cobro solo se habilita en Android/iOS y requiere que las Edge Functions estén desplegadas con `STRIPE_SECRET_KEY`; si la key falta o es inválida, la pantalla de pago solo muestra un aviso.
- `lib/providers/`: `auth_provider` (stream de auth + mutaciones con `AsyncNotifier`), `catalog_provider` (`FutureProvider`s de `restaurants`/`menu_items`, búsqueda filtrada en cliente), `cart_provider` (`StateNotifier`, **solo en memoria**), `checkout_provider` (`AutoDisposeAsyncNotifier` que orquesta el pago), `courier_provider` (perfil de repartidor, documentos y viajes).
- Repartidores: se entra desde el icono de moto en el AppBar de `HomeScreen`. `CourierController` lee `couriers` por `id = auth.uid` y se recarga al iniciar/cerrar sesión; `setOnline(true)` falla si `status != 'approved'`. El registro es en 2 pasos (datos/vehículo y luego documentos); sube a Storage en `${userId}/${docType}.${ext}` y hace upsert en `courier_documents` (jpg/jpeg/png/pdf, máx. 5 MB). No hay UI de aprobación: los `status` (`pending|approved|rejected`) se cambian fuera de la app.
- Flujo de pago (`checkout_provider`): carrito → Edge Function `create-payment-intent` (crea `orders`/`order_items` en estado `pending` y calcula el total con precios de la BD; la app solo manda ids y cantidades) → PaymentSheet nativo de Stripe → Edge Function `confirm-payment` (verifica el cobro con Stripe, compara el monto y marca `paid`, devolviendo el recibo). El carrito se vacía solo tras confirmar.
- Tracking de pedidos: "Mis pedidos" se abre desde el icono de recibo del AppBar de `HomeScreen` → `lib/screens/my_orders_screen.dart`; cada pedido abre `lib/screens/order_tracking_screen.dart` (mapa con `google_maps_flutter`) y `lib/providers/tracking_provider.dart` lee `orders` con `select('*, order_items(*), order_tracking(*)')` + suscripción Realtime a `order_tracking`. `tracking_models.dart` simula el avance del repartidor y usa un punto de respaldo (CDMX) si el restaurante no tiene `lat`/`lng`. La lista filtra `status != 'pending'` (los pagos no confirmados no aparecen).
- `lib/screens/checkout_screen.dart` escucha `checkoutControllerProvider` y navega a `ReceiptScreen` con `pushReplacement` cuando el pago termina; un pago cancelado vuelve a `null` sin error. Si cambias el estado del controller, conserva esa transición `loading → data/error`.
- Android: `MainActivity` debe extender `FlutterFragmentActivity` (no `FlutterActivity`) para que funcione la hoja de Stripe. `android/build.gradle.kts` desactiva `lintVitalAnalyzeRelease` de `stripe_android`; es intencional, no lo borres.

## Backend Supabase

- El catálogo y las tablas de repartidores viven fuera del repo; los pedidos y el tracking sí tienen SQL (`supabase/orders.sql`, `supabase/tracking.sql`). Tablas: `profiles`, `restaurants`, `menu_items`, `couriers`, `courier_documents`, `deliveries`, `orders`, `order_items` y `order_tracking`.
- **Trampa del trigger de tracking**: `public.orders_create_tracking()` se dispara `AFTER UPDATE OF status ON orders WHEN status='paid'`, o sea **dentro** del `UPDATE` que hace `confirm-payment`. Si el trigger falla, el UPDATE se revierte, la función devuelve 500 ("Error interno al confirmar el pago"), el pedido se queda en `pending` **aunque Stripe ya haya cobrado**. Revisa los logs con `query_logs` (source `function_edge_logs` / `postgres_logs`): el síntoma típico es `42883 operator does not exist: uuid = text` (pasaba porque `order_items.menu_item_id` era `text` y `menu_items.id` es `uuid`). **Ya está corregido** en la BD: `order_items.menu_item_id` es `uuid` con FK a `menu_items(id)` y el trigger castea el join (`supabase/fix_order_items_menu_item_uuid.sql` documenta el arreglo). Revisa siempre `orders` en `pending` con `stripe_payment_intent_id` para detectar cobros que no se confirmaron.
- `restaurants.lat`/`lng` ya tienen valores de prueba (CDMX); si los cambias, actualiza también `order_tracking.restaurant_lat/lng` (se copiaron al crearse el seguimiento). Sin coordenadas, el tracking usa el punto de respaldo de `tracking_models.dart`.
- `restaurants`: `id,name,description,image_url,category,rating,address,is_open`. `menu_items`: `id,restaurant_id,name,description,price,image_url,category,is_available,is_featured,created_at`. `orders`: `id,user_id,status,total,currency,stripe_payment_intent_id,receipt_url,paid_at,created_at`; `order_items`: `id,order_id,menu_item_id,name,unit_price,quantity`.
- Tablas de repartidores (existen en el proyecto remoto, pero **no hay SQL versionado** en el repo; si recreas el proyecto hay que crearlas a mano): `couriers` (`id` = auth user, `full_name,phone,vehicle_type,plate,status,is_online`), `courier_documents` (`courier_id,doc_type,file_path,status,uploaded_at`, único por `courier_id,doc_type` para el upsert) y `deliveries` (`id,courier_id,order_id,restaurant_name,dropoff_address,distance_km,earnings,tip,status,completed_at`). También hace falta el bucket de Storage `courier-documents`.
- Existe `public.profiles` (`id,full_name,phone,avatar_url`), pero la app **no la usa**: nombre y teléfono se guardan en `auth.users.user_metadata` con `updateUser` y se leen de ahí. Actualizar `profiles` no cambia el perfil en la app.
- `supabase/orders.sql` se aplica **una sola vez a mano** en el SQL Editor del dashboard. RLS: el cliente autenticado solo puede leer sus propios pedidos/items; los insert/update los hacen las Edge Functions con service role.
- `supabase/functions/create-payment-intent` y `confirm-payment` son funciones Deno (`npm:@supabase/supabase-js@2`) que requieren el secret `STRIPE_SECRET_KEY`; `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta Supabase. Ambas ya están desplegadas y `ACTIVE`; si las editas, vuelve a desplegarlas. No hay migraciones versionadas (`list_migrations` vacío), ni `supabase/config.toml`, ni CLI local: usa el dashboard (o instala la CLI) en vez de asumir un `supabase start`.
- Las filas son snake_case; las consultas de menú usan `select('*, restaurants(name)')`, por eso `MenuItem.restaurantName` viene del mapa anidado `restaurants`. El recibo usa `select('*, order_items(*)')` de forma equivalente.
- MCP de Supabase remoto configurado en `opencode.jsonc` para el project ref de la app (OAuth, **sin `read_only`**, así que `execute_sql` también aplica DDL). Úsalo para inspeccionar esquema/RLS, advisors y logs, y para aplicar SQL; pide confirmación antes de modificar la BD. Si cambias la URL del MCP hay que re-autenticarlo y reiniciar la sesión para que las herramientas vuelvan a estar disponibles.

## Convenciones

- `lib/screens` = páginas, `lib/widgets` = tarjetas/campos reutilizables, `lib/models` = clases simples que mapean filas (sin codegen). Mantén el estado compartido en providers; el estado local de pantalla es solo UI transitoria (p. ej. cantidad).
- No edites a mano archivos generados de Flutter: `ios/Flutter/Generated.xcconfig`, `*/flutter/generated_plugin*`, `android/**/GeneratedPluginRegistrant.java`.
- `analysis_options.yaml` excluye las carpetas de plataforma, así que `flutter analyze` solo cubre el Dart de `lib/` y `test/`.
- Skills locales en `.agents/skills/` (fijadas en `skills-lock.json`): carga `supabase` para tareas de Supabase y `supabase-postgres-best-practices` antes de tocar esquema, RLS, índices o migraciones.
- El proyecto es Flutter puro: `package.json`, `pnpm-lock.yaml` y `node_modules/` en la raíz son residuo del instalador de skills (`npx skills add`) y no se usan para nada (no hay JS en el repo).

<!-- CODEGRAPH_START -->
## CodeGraph

En repositorios indexados por CodeGraph (existe un directorio `.codegraph/` en la raíz del repo), usa CodeGraph ANTES de grep/find o de leer archivos cuando necesites entender o localizar código:

- **Herramienta MCP** (cuando esté disponible): `codegraph_explore` responde la mayoría de preguntas de código en una sola llamada: el código fuente literal de los símbolos relevantes, las rutas de llamada entre ellos y un resumen del radio de impacto, incluyendo saltos de despacho dinámico que grep no puede seguir. Nombra un archivo o símbolo en la consulta para leer su código fuente actual con números de línea. Si aparece listada pero diferida, cárgala por nombre con la búsqueda de herramientas.
- **Shell** (siempre funciona): `codegraph explore "<nombres de símbolos o pregunta>"` imprime lo mismo.

Si no hay un directorio `.codegraph/`, ignora CodeGraph por completo: indexar es decisión del usuario.
<!-- CODEGRAPH_END -->
