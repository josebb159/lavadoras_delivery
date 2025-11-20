import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MisServiciosScreen extends StatefulWidget {
  const MisServiciosScreen({Key? key}) : super(key: key);

  @override
  _MisServiciosScreenState createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen> {
  bool isLoading = true;
  List<dynamic> activeRentals = []; // Ahora es una lista
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
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=get_rental_all_delivery'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          List rentals = responseData['rentals'];
          activeRentals = rentals.toList();
        }
      }
    } catch (e) {
      print('Error al obtener los detalles del alquiler: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Servicios'),
        backgroundColor: Color(0xFF0090FF),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeRentals.isNotEmpty
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: activeRentals.length,
          itemBuilder: (context, index) {
            final rental = activeRentals[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalles del Alquiler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0090FF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF0090FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Fecha Solicitada: ${rental['start_time'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Color(0xFF0090FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tiempo de Alquiler: ${rental['tiempo_alquiler'] ?? '0'} horas',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Color(0xFF0090FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Valor del Servicio: \$${rental['valor_servicio'] ?? '0'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      )
          : const Center(child: Text('No tienes alquileres finalizados')),
    );
  }
}
