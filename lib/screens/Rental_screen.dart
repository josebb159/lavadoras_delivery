import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lavadora_app/services/api_service.dart';

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
  int id_lavadora = 0;
  late TextEditingController addressController;
  Position? currentPosition;
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    _checkAvailableMachines();
  }

  Future<void> _checkAvailableMachines() async {
    print('\n🔍 CHECKING AVAILABLE MACHINES');
    print(
      '📍 Current Position: ${currentPosition?.latitude}, ${currentPosition?.longitude}',
    );

    try {
      final responseData = await ApiService().post('available_machines', {
        'latitud': currentPosition?.latitude,
        'longitud': currentPosition?.longitude,
      });

      print('\n📊 PROCESSING AVAILABLE MACHINES RESPONSE');
      print('Status: ${responseData['status']}');

      if (responseData['status'] == 'ok') {
        availableMachines = int.parse(responseData['disponibles'].toString());
        print('✅ Available machines: $availableMachines');

        if (availableMachines == 0) {
          print('⚠️  No washing machines available');
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay lavadoras disponibles.')),
            );
          }
        } else {
          id_lavadora = int.parse(responseData['id_lavadora'].toString());
          pricePerHour = int.parse(responseData['tarifa'].toString());
          print('🧺 Assigned washing machine ID: $id_lavadora');
          print('💰 Price per hour: \$$pricePerHour');

          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? userData = prefs.getString('user');
          if (userData != null) {
            user = json.decode(userData);
            print('👤 User loaded: ${user['nombre']} (ID: ${user['id']})');
            print('📍 User address: ${user['direccion']}');

            addressController = TextEditingController(
              text: user['direccion'] ?? '',
            );
            await _getCurrentLocation();
            setState(() {
              isLoading = false;
            });
            print('✅ Screen initialized successfully');
          }
        }
      } else if (responseData['status'] == 'error') {
        print('❌ API Error: ${responseData['message']}');
        throw Exception(responseData['message']);
      } else {
        print('❌ Unexpected response status: ${responseData['status']}');
        throw Exception('Error al consultar disponibilidad');
      }
    } catch (e, stackTrace) {
      print('💥 ERROR in _checkAvailableMachines: $e');
      print(
        'Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    print('\n📍 GETTING CURRENT LOCATION');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('⚠️  Location service is disabled');
      await Geolocator.openLocationSettings();
      return;
    }

    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    print('✅ Location obtained:');
    print('   Latitude: ${currentPosition?.latitude}');
    print('   Longitude: ${currentPosition?.longitude}');
    print('   Accuracy: ${currentPosition?.accuracy}m');
  }

  void _rentMachine() async {
    print('\n🛒 INITIATING WASHING MACHINE RENTAL');
    print('=' * 60);
    print('👤 User ID: ${user['id']}');
    print('🧺 Washing Machine ID: $id_lavadora');
    print('⏰ Rental Hours: $rentalHours');
    print('💰 Total Cost: \$${rentalHours * pricePerHour}');
    print('📍 Delivery Address: ${addressController.text}');
    print(
      '🌍 GPS Coordinates: ${currentPosition?.latitude}, ${currentPosition?.longitude}',
    );
    print('=' * 60);

    try {
      final requestData = {
        'user_id': user['id'],
        'tiempo': rentalHours,
        'direccion': addressController.text,
        'latitud': currentPosition?.latitude,
        'longitud': currentPosition?.longitude,
        'id_lavadora': id_lavadora,
      };

      print('📤 Sending rental request...');
      final responseData = await ApiService().post('rent_machine', requestData);

      print('\n📊 RENTAL RESPONSE ANALYSIS');
      print('Status: ${responseData['status']}');

      if (responseData['status'] == 'ok') {
        print('✅ RENTAL SUCCESSFUL!');
        if (responseData.containsKey('service_id')) {
          print('🆔 Service ID: ${responseData['service_id']}');
        }
        if (responseData.containsKey('message')) {
          print('📝 Message: ${responseData['message']}');
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alquiler exitoso')));
        Navigator.pop(context);
      } else {
        print('❌ RENTAL FAILED');
        print('Error message: ${responseData['message'] ?? 'Unknown error'}');
        throw Exception(responseData['message'] ?? 'Error al alquilar');
      }
    } catch (e, stackTrace) {
      print('💥 RENTAL ERROR: $e');
      print(
        'Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 200,
                child:
                    currentPosition == null
                        ? const Center(child: Text('Ubicación no disponible'))
                        : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              currentPosition!.latitude,
                              currentPosition!.longitude,
                            ),
                            zoom: 16,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('currentLocation'),
                              position: LatLng(
                                currentPosition!.latitude,
                                currentPosition!.longitude,
                              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Tiempo de alquiler (horas)',
                      style: TextStyle(fontSize: 18),
                    ),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
