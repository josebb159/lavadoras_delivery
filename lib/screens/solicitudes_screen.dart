import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/solicitudes_provider.dart';
import '../models/solicitud_model.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({Key? key}) : super(key: key);

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  bool _isSwitchLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final solicitudesProvider = Provider.of<SolicitudesProvider>(
        context,
        listen: false,
      );

      if (authProvider.user != null) {
        solicitudesProvider.startPolling(authProvider.user!.id);
        authProvider.checkDriverStatus();
      }
    });
  }

  @override
  void dispose() {
    Provider.of<SolicitudesProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final solicitudesProvider = Provider.of<SolicitudesProvider>(
      context,
      listen: false,
    );

    if (authProvider.user != null) {
      await solicitudesProvider.fetchSolicitudes(
        authProvider.user!.id,
        showLoading: true, // Show loading on manual refresh
      );
    }
  }

  void _aceptarSolicitud(Solicitud solicitud) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final solicitudesProvider = Provider.of<SolicitudesProvider>(
      context,
      listen: false,
    );

    if (authProvider.user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Aceptar Servicio'),
            content: Text(
              '¿Deseas aceptar este servicio para ${solicitud.nombreCliente}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0090FF),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final result = await solicitudesProvider.aceptarSolicitud(
        authProvider.user!.id,
        solicitud.id,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message']}'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to service detail
        Navigator.pushNamed(context, '/servicio', arguments: solicitud.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${result['message']}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getTipoServicio(String tariffType) {
    switch (tariffType.toLowerCase()) {
      case 'normal':
        return 'Normal';
      case '24_hours':
      case '24horas':
        return '24 Horas';
      case 'nocturnal':
      case 'nocturno':
        return 'Nocturno';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes Disponibles'),
        backgroundColor: const Color(0xFF0090FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return Row(
                children: [
                  Text(
                    auth.driverStatus == 1 ? 'En servicio' : 'En reposo',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (_isSwitchLoading)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else
                    Switch(
                      value: auth.driverStatus == 1,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.lightGreenAccent,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey[300],
                      onChanged: (value) async {
                        setState(() {
                          _isSwitchLoading = true;
                        });
                        await auth.toggleDriverStatus(value);
                        if (mounted) {
                          setState(() {
                            _isSwitchLoading = false;
                          });
                        }
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Consumer<SolicitudesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.solicitudes.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.solicitudes.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.solicitudes.length,
                  itemBuilder: (context, index) {
                    final solicitud = provider.solicitudes[index];
                    return _buildSolicitudCard(solicitud, provider);
                  },
                ),
              );
            },
          ),
          // Loading overlay
          Consumer<SolicitudesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.solicitudes.isNotEmpty) {
                return Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Procesando...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay solicitudes disponibles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las nuevas solicitudes aparecerán aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(
    Solicitud solicitud,
    SolicitudesProvider provider,
  ) {
    final distancia = provider.getDistanciaTexto(solicitud.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0090FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service,
                    color: Color(0xFF0090FF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solicitud.nombreCliente,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            solicitud.telefonoCliente,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (distancia != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.green[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distancia,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Details
            _buildDetailRow(
              Icons.location_on_outlined,
              'Dirección',
              solicitud.direccionCliente,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.local_laundry_service_outlined,
              'Tipo',
              solicitud.tipoLavadora,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.access_time,
              'Tiempo',
              '${solicitud.tiempoAlquiler} horas (${_getTipoServicio(solicitud.tariffType)})',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.attach_money,
              'Total',
              '\$${solicitud.totalAmount}',
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _aceptarSolicitud(solicitud),
                icon: const Icon(Icons.check),
                label: const Text('Aceptar Servicio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0090FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
