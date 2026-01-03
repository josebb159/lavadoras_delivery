import 'package:flutter/material.dart';
import 'package:lavadora_app/services/api_service.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MisServiciosScreen extends StatefulWidget {
  const MisServiciosScreen({Key? key}) : super(key: key);

  @override
  _MisServiciosScreenState createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen> {
  bool isLoading = true;
  List<dynamic> activeRentals = [];
  Map<String, dynamic> user = {};

  @override
  void initState() {
    super.initState();
    _getActiveRental();
  }

  Future<void> _getActiveRental() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      user = json.decode(userData);
    }

    final data = {'user_id': user['id']};

    try {
      final responseData = await ApiService().post(
        'get_rental_all_delivery',
        data,
      );
      if (responseData['status'] == 'ok') {
        List rentals = responseData['rentals'];
        activeRentals = rentals.toList();

        // Ordenar por ID descendente (más recientes primero)
        activeRentals.sort((a, b) {
          int idA = int.tryParse(a['id'].toString()) ?? 0;
          int idB = int.tryParse(b['id'].toString()) ?? 0;
          return idB.compareTo(idA); // Orden descendente
        });
      }
    } catch (e) {
      print('Error al obtener los detalles del alquiler: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _getActiveRental();
  }

  void _navigateToDetail(dynamic rental) {
    Navigator.pushNamed(
      context,
      '/servicio',
      arguments: rental['id'].toString(),
    );
  }

  String _getStatusText(dynamic rental) {
    final status = rental['status_servicio']?.toString() ?? '1';
    switch (status) {
      case '1':
        return 'Pendiente';
      case '2':
        return 'En Curso';
      case '3':
        return 'Por Retirar';
      case '4':
        return 'Finalizado';
      case '5':
        return 'Cancelado';
      case '6':
        return 'En camino';
      default:
        return 'Desconocido';
    }
  }

  Color _getStatusColor(dynamic rental) {
    final status = rental['status_servicio']?.toString() ?? '1';
    switch (status) {
      case '1':
        return Colors.orange;
      case '2':
        return Colors.blue;
      case '3':
        return Colors.purple;
      case '4':
        return Colors.green;
      case '5':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Servicios'),
        backgroundColor: const Color(0xFF0090FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : activeRentals.isNotEmpty
              ? RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeRentals.length,
                  itemBuilder: (context, index) {
                    final rental = activeRentals[index];
                    return _buildServiceCard(rental);
                  },
                ),
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes servicios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildServiceCard(dynamic rental) {
    final statusColor = _getStatusColor(rental);
    final statusText = _getStatusText(rental);

    // Calcular valores
    final tiempoAlquiler =
        int.tryParse(rental['tiempo_alquiler']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(rental['total']?.toString() ?? '0') ?? 0;
    final valorPorHora = tiempoAlquiler > 0 ? total / tiempoAlquiler : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToDetail(rental),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Status
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Servicio #${rental['id']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0090FF),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pricing Section - Highlighted
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0090FF).withOpacity(0.1),
                    const Color(0xFF0090FF).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0090FF).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Valor por hora
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Valor por hora:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${valorPorHora.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0090FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Cálculo: tiempo × valor
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calculate,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$tiempoAlquiler hrs × \$${valorPorHora.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0090FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Service Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Fecha Inicio',
                    rental['start_time'] ?? 'N/A',
                  ),
                  const SizedBox(height: 12),
                  if (rental['fecha_fin'] != null &&
                      rental['fecha_fin'].toString().isNotEmpty) ...[
                    _buildDetailRow(
                      Icons.event_available,
                      'Fecha Fin',
                      rental['fecha_fin'],
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildDetailRow(
                    Icons.timer,
                    'Tiempo',
                    '$tiempoAlquiler horas',
                  ),
                  const SizedBox(height: 12),
                  if (rental['tipo_lavadora'] != null &&
                      rental['tipo_lavadora'].toString().isNotEmpty) ...[
                    _buildDetailRow(
                      Icons.local_laundry_service,
                      'Tipo',
                      rental['tipo_lavadora'],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (rental['metodo_pago'] != null)
                    _buildDetailRow(
                      Icons.payment,
                      'Pago',
                      rental['metodo_pago'].toString().toUpperCase(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(),
            ),
            const SizedBox(height: 8),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToDetail(rental),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Ver Detalles'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0090FF),
                        side: const BorderSide(color: Color(0xFF0090FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
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
