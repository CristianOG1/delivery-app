import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/courier_provider.dart';
import 'courier_history_screen.dart';
import 'courier_register_screen.dart';

/// Panel principal del repartidor: botón conectado/desconectado,
/// ganancias de hoy y accesos a documentos e historial.
/// Si el usuario aún no es repartidor, muestra el registro.
class CourierDashboardScreen extends ConsumerStatefulWidget {
  const CourierDashboardScreen({super.key});

  @override
  ConsumerState<CourierDashboardScreen> createState() =>
      _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends ConsumerState<CourierDashboardScreen> {
  bool _cambiando = false;

  Future<void> _alternarConexion(bool conectar) async {
    setState(() => _cambiando = true);
    try {
      await ref.read(courierProvider.notifier).setOnline(conectar);
    } catch (e) {
      if (!mounted) return;
      final mensaje = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courier = ref.watch(courierProvider);

    return courier.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Repartidor')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (perfil) {
        if (perfil == null) return const CourierRegisterScreen();

        final conectado = perfil.isOnline;
        final resumen = ref.watch(earningsSummaryProvider);

        return Scaffold(
          appBar: AppBar(title: const Text('Panel de repartidor')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Hola, ${perfil.fullName}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              _EstadoCuenta(status: perfil.status),
              const SizedBox(height: 24),

              // Botón conectado / desconectado
              SizedBox(
                height: 72,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: conectado ? Colors.red : Colors.green,
                  ),
                  onPressed: (_cambiando || (!perfil.isApproved && !conectado))
                      ? null
                      : () => _alternarConexion(!conectado),
                  icon: _cambiando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(conectado ? Icons.power_settings_new : Icons.play_arrow),
                  label: Text(
                    conectado ? 'Desconectarme' : 'Conectarme',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  conectado
                      ? 'Estás conectado y recibirás pedidos'
                      : perfil.isApproved
                          ? 'Estás desconectado'
                          : 'Podrás conectarte cuando tu cuenta sea aprobada',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Ganancias de hoy
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: resumen.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('No se pudo cargar: $e'),
                    data: (r) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Dato(titulo: 'Hoy', valor: formatoMoneda(r.today.total)),
                        _Dato(titulo: 'Viajes hoy', valor: '${r.today.trips}'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Historial de viajes y ganancias'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CourierHistoryScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Mis documentos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _DocumentosScreen()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reutiliza la sección de documentos del registro (ya hay perfil, así que
/// `CourierRegisterScreen` muestra directamente el paso 2).
class _DocumentosScreen extends StatelessWidget {
  const _DocumentosScreen();

  @override
  Widget build(BuildContext context) => const CourierRegisterScreen();
}

class _EstadoCuenta extends StatelessWidget {
  final String status;

  const _EstadoCuenta({required this.status});

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (status) {
      'approved' => ('Cuenta aprobada', Colors.green),
      'rejected' => ('Solicitud rechazada', Colors.red),
      _ => ('Cuenta en revisión', Colors.orange),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(color: color)),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final String valor;

  const _Dato({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor, style: Theme.of(context).textTheme.headlineSmall),
        Text(titulo, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
