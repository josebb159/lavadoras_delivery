import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MisLavadorasScreen extends StatefulWidget {
  const MisLavadorasScreen({Key? key}) : super(key: key);

  @override
  _MisLavadorasScreenState createState() => _MisLavadorasScreenState();
}

class _MisLavadorasScreenState extends State<MisLavadorasScreen> {
  bool isLoading = true;
  List<dynamic> lavadoras = [];
  Map<String, dynamic> user = {};

  @override
  void initState() {
    super.initState();
    _getLavadoras();
  }

  Future<void> _getLavadoras() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      user = json.decode(userData);
    }

    final data = {'id_negocio': user['conductor_negocio']};

    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=lavadoras_de_negocio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            lavadoras = res['disponibles'];
          });
        } else {
          setState(() {
            lavadoras = [];
          });
        }
      }
    } catch (e) {
      print('Error al obtener lavadoras: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cambiarEstadoLavadora(Map<String, dynamic> lavadora) async {
    final nuevoEstado = lavadora['en'] == 'bodega' ? 'delivery' : 'bodega';
    final data = {
      'id_lavadora': lavadora['id'],
      'id_domiciliario': user['id'],
      'en': nuevoEstado
    };

    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=asignar_lavadora'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      final res = json.decode(response.body);
      if (res['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lavadora actualizada a "$nuevoEstado"')),
        );
        _getLavadoras(); // Refrescar lista
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${res['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar estado: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lavadoras de mi negocio'),
        backgroundColor: Color(0xFF0090FF),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : lavadoras.isEmpty
          ? const Center(child: Text('No hay lavadoras registradas'))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: lavadoras.length,
        itemBuilder: (context, index) {
          final lavadora = lavadoras[index];
          final estaEnBodega = lavadora['en'] == 'bodega';

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lavadora['codigo'] ?? 'Lavadora sin código',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0090FF),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Estado: ${lavadora['en']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _cambiarEstadoLavadora(lavadora),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      estaEnBodega ? Colors.green : Colors.orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      estaEnBodega ? '📦 Cargar' : '🏠 Devolver',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
