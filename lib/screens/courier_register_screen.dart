import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/courier_models.dart';
import '../providers/courier_provider.dart';

/// Registro de repartidores en dos pasos:
/// 1) formulario de datos personales y del vehículo,
/// 2) carga de licencia, identificación y seguro.
class CourierRegisterScreen extends ConsumerStatefulWidget {
  const CourierRegisterScreen({super.key});

  @override
  ConsumerState<CourierRegisterScreen> createState() =>
      _CourierRegisterScreenState();
}

class _CourierRegisterScreenState extends ConsumerState<CourierRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  String _vehiculo = 'moto';
  bool _enviando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await ref.read(courierProvider.notifier).register(
            fullName: _nombreCtrl.text,
            phone: _telefonoCtrl.text,
            vehicleType: _vehiculo,
            plate: _placaCtrl.text,
          );
    } catch (e) {
      _mostrarError('No se pudo registrar: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final courier = ref.watch(courierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registro de repartidor')),
      body: courier.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (perfil) =>
            perfil == null ? _formulario() : _SeccionDocumentos(perfil: perfil),
      ),
    );
  }

  Widget _formulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paso 1 de 2: tus datos',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Escribe tu nombre completo'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (10 dígitos)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final digitos = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digitos.length == 10 ? null : 'Escribe un teléfono de 10 dígitos';
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vehiculo,
              decoration: const InputDecoration(
                labelText: 'Tipo de vehículo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'bicicleta', child: Text('Bicicleta')),
                DropdownMenuItem(value: 'moto', child: Text('Motocicleta')),
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
              ],
              onChanged: (v) => setState(() => _vehiculo = v ?? 'moto'),
            ),
            if (_vehiculo != 'bicicleta') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _placaCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Escribe la placa del vehículo'
                    : null,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _enviando ? null : _registrar,
              child: _enviando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paso 2: documentos requeridos y estado de la revisión.
class _SeccionDocumentos extends ConsumerStatefulWidget {
  final Courier perfil;

  const _SeccionDocumentos({required this.perfil});

  @override
  ConsumerState<_SeccionDocumentos> createState() => _SeccionDocumentosState();
}

class _SeccionDocumentosState extends ConsumerState<_SeccionDocumentos> {
  static const _maxBytes = 5 * 1024 * 1024; // 5 MB
  final Set<String> _subiendo = {};

  Future<void> _subir(String tipo) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;

    final archivo = resultado.files.first;
    if (archivo.size > _maxBytes) {
      _mensaje('El archivo pesa más de 5 MB');
      return;
    }

    setState(() => _subiendo.add(tipo));
    try {
      await ref.read(courierDocumentsProvider.notifier).upload(tipo, archivo);
      _mensaje('${CourierDocType.label(tipo)} enviado a revisión');
    } catch (e) {
      _mensaje('No se pudo subir el archivo: $e');
    } finally {
      if (mounted) setState(() => _subiendo.remove(tipo));
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(courierDocumentsProvider);
    final perfil = ref.watch(courierProvider).valueOrNull ?? widget.perfil;

    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (mapa) {
        final completos = CourierDocType.all.every(mapa.containsKey);
        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(courierProvider.notifier).refresh();
            ref.invalidate(courierDocumentsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Paso 2 de 2: documentos',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Sube una foto clara o un PDF (máx. 5 MB) de cada documento.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _BannerEstado(perfil: perfil, documentosCompletos: completos),
              const SizedBox(height: 16),
              for (final tipo in CourierDocType.all)
                _TarjetaDocumento(
                  tipo: tipo,
                  documento: mapa[tipo],
                  subiendo: _subiendo.contains(tipo),
                  onSubir: () => _subir(tipo),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BannerEstado extends StatelessWidget {
  final Courier perfil;
  final bool documentosCompletos;

  const _BannerEstado({required this.perfil, required this.documentosCompletos});

  @override
  Widget build(BuildContext context) {
    late final IconData icono;
    late final Color color;
    late final String texto;

    if (perfil.isApproved) {
      icono = Icons.verified;
      color = Colors.green;
      texto = '¡Tu cuenta está aprobada! Ya puedes conectarte.';
    } else if (perfil.status == 'rejected') {
      icono = Icons.error_outline;
      color = Colors.red;
      texto = 'Tu solicitud fue rechazada. Revisa tus documentos y vuelve a subirlos.';
    } else if (!documentosCompletos) {
      icono = Icons.upload_file;
      color = Colors.orange;
      texto = 'Sube los tres documentos para que revisemos tu solicitud.';
    } else {
      icono = Icons.hourglass_top;
      color = Colors.blue;
      texto = 'Tus documentos están en revisión. Desliza hacia abajo para actualizar.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _TarjetaDocumento extends StatelessWidget {
  final String tipo;
  final CourierDocument? documento;
  final bool subiendo;
  final VoidCallback onSubir;

  const _TarjetaDocumento({
    required this.tipo,
    required this.documento,
    required this.subiendo,
    required this.onSubir,
  });

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color) = switch (documento?.status) {
      null => ('Sin subir', Colors.grey),
      'approved' => ('Aprobado', Colors.green),
      'rejected' => ('Rechazado', Colors.red),
      _ => ('En revisión', Colors.orange),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          documento == null ? Icons.description_outlined : Icons.description,
          color: color,
        ),
        title: Text(CourierDocType.label(tipo)),
        subtitle: Text(etiqueta, style: TextStyle(color: color)),
        trailing: subiendo
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onSubir,
                child: Text(documento == null ? 'Subir' : 'Reemplazar'),
              ),
      ),
    );
  }
}
