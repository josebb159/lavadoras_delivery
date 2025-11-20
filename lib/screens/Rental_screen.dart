import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

class RentalScreen extends StatefulWidget {
  const RentalScreen({Key? key}) : super(key: key);

  @override
  _RentalScreenState createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> {
  bool isLoading = true;
  Map<String, dynamic> user = {};
  int availableMachines = 0;
  int rentalHours = 1;
  int pricePerHour = 1000;
  int id_lavadora =0;
  late TextEditingController addressController;
  Position? currentPosition;
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    _checkAvailableMachines();
  }

  Future<void> _checkAvailableMachines() async {
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.comhttps://alquilav.com/api/api.php?action=available_machines'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitud': currentPosition?.latitude,
          'longitud': currentPosition?.longitude,
        }),
      );

      final responseData = json.decode(response.body);
      print('Respuesta JSON: $responseData');
      if (responseData['status'] == 'ok') {
        availableMachines = int.parse(responseData['disponibles'].toString());

        if (availableMachines == 0) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay lavadoras disponibles.')),
            );
          }
        } else {
          id_lavadora =  int.parse(responseData['id_lavadora'].toString());
          pricePerHour =  int.parse(responseData['tarifa'].toString());
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? userData = prefs.getString('user');
          if (userData != null) {
            user = json.decode(userData);
            addressController = TextEditingController(text: user['direccion'] ?? '');
            await _getCurrentLocation();
            setState(() {
              isLoading = false;
            });
          }
        }
      }else if(responseData['status'] == 'error') {
        throw Exception(responseData['message']);

      }else {
        throw Exception('Error al consultar disponibilidad');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    // Pedir permisos de ubicación en tiempo de ejecución



    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _rentMachine() async {
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.comhttps://alquilav.com/api/api.php?action=rent_machine'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user['id'],
          'tiempo': rentalHours,
          'direccion': addressController.text,
          'latitud': currentPosition?.latitude,
          'longitud': currentPosition?.longitude,
          'id_lavadora': id_lavadora
        }),
      );
      print('Respuesta cruda: ${response.body}');
      final responseData = json.decode(response.body);

      if (responseData['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alquiler exitoso')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Error al alquilar');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alquilar Lavadora'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de entrega',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SizedBox(
                height: 200,
                child: currentPosition == null
                    ? const Center(child: Text('Ubicación no disponible'))
                    : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('currentLocation'),
                      position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                    ),
                  },
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Tiempo de alquiler (horas)', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (rentalHours > 1) {
                              setState(() {
                                rentalHours--;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove_circle, size: 32),
                          color: Colors.redAccent,
                        ),
                        Text(
                          rentalHours.toString(),
                          style: const TextStyle(fontSize: 24),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              rentalHours++;
                            });
                          },
                          icon: const Icon(Icons.add_circle, size: 32),
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: \$${rentalHours * pricePerHour}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _rentMachine,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('CONFIRMAR ALQUILER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
