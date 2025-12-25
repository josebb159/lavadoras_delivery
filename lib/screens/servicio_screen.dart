import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:lavadora_app/screens/chat.dart';

import 'package:lavadora_app/services/api_service.dart';
import 'package:lavadora_app/services/notification_service.dart';

class MisServiciosPendiente extends StatefulWidget {
  final int idAlquiler;
  const MisServiciosPendiente({Key? key, required this.idAlquiler})
    : super(key: key);

  @override
  _MisServiciosPendienteState createState() => _MisServiciosPendienteState();
}

class _MisServiciosPendienteState extends State<MisServiciosPendiente> {
  Map<String, dynamic> user = {};
  String userId = '';
  String conductorId = '';
  String user_id = '';
  bool isLoading = false;
  // Datos del servicio
  String clienteNombre = '';
  String clienteDireccion = '';
  String clienteTelefono = '';
  String tipoLavadora = '';
  String descripcionLavadora = '';
  bool servicioAceptado = false;
  String statusServicio = '1'; // Track service status
  String valorServicio = '0'; // Service total amount
  Set<Polyline> _polylines = {};
  String distancia = "";
  String duracion = "";
  // Variables para motivos de cancelación
  List<dynamic> motivosList = [];
  int? motivoSeleccionado;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Timer? _ubicacionTimer;
  Timer? _locationTimer; // Timer for periodic location updates
  Timer? _serviceRefreshTimer; // Timer for periodic service detail refresh

  LatLng origen = const LatLng(0, 0);
  LatLng destino = const LatLng(0, 0);

  late GoogleMapController mapController;
  late BitmapDescriptor origenIcon;
  late BitmapDescriptor destinoIcon;

  @override
  void initState() {
    super.initState();
    _loadIcons().then((_) {
      _loadUserData();
    });

    enviarUbicacionPeriodicamente();

    // Start periodic service refresh every 30 seconds
    _serviceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      print('🔄 Actualizando detalles del servicio...');
      _detailService();
    });
    //_obtenerUsuarioYUbicacion();
  }

  Future<void> _obtenerUsuarioYUbicacion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData == null) {
      print("❌ No se encontró información del usuario");
      return;
    }

    final user = jsonDecode(userData);
    userId = user['id'].toString(); // Ajusta si la clave es diferente

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("❌ Permiso de ubicación denegado");
      return;
    }

    _iniciarEnvioUbicacion(); // empieza a enviar y actualizar mapa
  }

  void _iniciarEnvioUbicacion() {
    _ubicacionTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await ApiService().post('update_ubicacion_domiciliario', {
          'user_id': userId,
          'latitud': position.latitude.toString(),
          'longitud': position.longitude.toString(),
        });

        setState(() {
          _markers.removeWhere((m) => m.markerId == const MarkerId("origen"));
          _markers.add(
            Marker(
              markerId: const MarkerId("origen"),
              position: LatLng(position.latitude, position.longitude),
              icon: origenIcon,
            ),
          );
        });

        print('✅ Ubicación enviada correctamente');
        _actualizarMapa(position.latitude, position.longitude);
      } catch (e) {
        print('⚠️ Error al obtener/enviar ubicación: $e');
      }
    });
  }

  void _actualizarMapa(double lat, double lng) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 16),
        ),
      );
      print('✅ actualiza mapa');
      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId("destino"),
            position: destino,
            infoWindow: const InfoWindow(title: "Cliente"),
            icon: destinoIcon,
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId("origen"),
            position: LatLng(lat, lng),
            infoWindow: const InfoWindow(title: "Domiciliario"),
            icon: origenIcon,
          ),
        );
      });
    }
  }

  Future<void> _loadIcons() async {
    origenIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/origen.png',
    );
    destinoIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/destino.png',
    );
  }

  @override
  void dispose() {
    _ubicacionTimer?.cancel();
    _locationTimer?.cancel(); // Cancel the second timer as well
    _serviceRefreshTimer?.cancel(); // Cancel service refresh timer
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> enviarUbicacionPeriodicamente() async {
    // Cancel previous timer if exists
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await ApiService().post('update_ubicacion_domiciliario', {
          'user_id': userId,
          'latitud': position.latitude.toString(),
          'longitud': position.longitude.toString(),
        });

        // Hora actual sin intl
        final now = DateTime.now();
        final hora =
            "${now.hour.toString().padLeft(2, '0')}:"
            "${now.minute.toString().padLeft(2, '0')}:"
            "${now.second.toString().padLeft(2, '0')}";

        setState(() {
          _markers.removeWhere((m) => m.markerId == const MarkerId("origen"));
          _markers.add(
            Marker(
              markerId: const MarkerId("origen"),
              position: LatLng(position.latitude, position.longitude),
              icon: origenIcon,
            ),
          );
        });

        print(
          '[$hora] ✅ Ubicación enviada correctamente: '
          'Lat: ${position.latitude}, Lng: ${position.longitude}',
        );
      } catch (e) {
        final now = DateTime.now();
        final hora =
            "${now.hour.toString().padLeft(2, '0')}:"
            "${now.minute.toString().padLeft(2, '0')}:"
            "${now.second.toString().padLeft(2, '0')}";
        print('[$hora] ⚠️ Error al obtener/enviar ubicación: $e');
      }
    });
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      setState(() {
        user = json.decode(userData);
        userId = user['id'].toString();
        _detailService();
      });
    }
  }

  Future<void> _openWhatsApp() async {
    if (clienteTelefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay número de teléfono disponible")),
      );
      return;
    }

    final phone = clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = phone.startsWith('57') ? phone : '57$phone';

    final Uri uri = Uri.parse(
      "whatsapp://send?phone=$fullPhone&text=${Uri.encodeComponent("hola")}",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("WhatsApp no está instalado o no se puede abrir."),
        ),
      );
    }
  }

  Future<void> _getRouteInfo() async {
    final String apiKey =
        "AIzaSyBz3zJ1d-TOXPhpp5t1ZNaKhWai5aVdVpc"; // Reemplaza con tu API Key
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origen.latitude},${origen.longitude}&destination=${destino.latitude},${destino.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polyline = route['overview_polyline']['points'];

        final polylinePoints = PolylinePoints().decodePolyline(polyline);
        final List<LatLng> polylineCoords =
            polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId("ruta"),
              points: polylineCoords,
              color: Colors.blue,
              width: 5,
            ),
          };

          distancia = route['legs'][0]['distance']['text'];
          duracion = route['legs'][0]['duration']['text'];
        });
      }
    } else {
      print("Error al obtener la ruta: ${response.body}");
    }
  }

  Future<void> entregar() async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });

    try {
      final nombreDomiciliario = user['nombre'] ?? 'Domiciliario';

      // Use different endpoint based on service status
      if (statusServicio == '3') {
        // Status 3 (Por Retirar) - Use recoger endpoint
        final data = {
          'id_alquiler': widget.idAlquiler,
          'user_id': userId,
          'total': int.tryParse(valorServicio) ?? 0,
        };

        print('📦 Recogiendo lavadora con data: $data');
        await ApiService().post('recoger', data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lavadora recogida con éxito")),
        );

        // Send pickup notification to client
        await NotificationService().notificarLavadoraRecogida(
          clienteId: user_id,
          nombreDomiciliario: nombreDomiciliario,
          idAlquiler: widget.idAlquiler,
        );
      } else {
        // Status 2 (En Curso) - Use entregar_servicio endpoint
        final data = {'id_alquiler': widget.idAlquiler, 'user_id': userId};

        print('🚚 Entregando lavadora con data: $data');
        await ApiService().post('entregar_servicio', data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Entrega realizada con éxito")),
        );

        // Send delivery notification to client
        await NotificationService().notificarLavadoraEntregada(
          clienteId: user_id,
          nombreDomiciliario: nombreDomiciliario,
          idAlquiler: widget.idAlquiler,
        );
      }

      // Reload service details to show updated status
      await _detailService();
    } catch (e) {
      print("Error en la operación: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            statusServicio == '3'
                ? "Error al recoger la lavadora"
                : "Error en la solicitud de entrega",
          ),
        ),
      );
    } finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  Future<void> confirmarEntrega() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = {
        'user_id': int.parse(userId),
        'id_alquiler': widget.idAlquiler,
      };

      print('📦 Confirmando entrega con data: $data');
      final response = await ApiService().post(
        'confirmar_entrega_lavadora',
        data,
      );

      if (response['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Entrega confirmada exitosamente")),
        );

        // Send notification to client
        final nombreDomiciliario = user['nombre'] ?? 'Domiciliario';
        await NotificationService().notificarLavadoraEntregada(
          clienteId: user_id,
          nombreDomiciliario: nombreDomiciliario,
          idAlquiler: widget.idAlquiler,
        );

        // Reload service details to show updated status
        await _detailService();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response['message']}")),
        );
      }
    } catch (e) {
      print("Error confirmando entrega: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al confirmar la entrega")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> cancelar(int idMotivo) async {
    final data = {
      'id_alquiler': widget.idAlquiler,
      'user_id': userId,
      'motivo': idMotivo,
    };

    try {
      final responseData = await ApiService().post('cancelar_servicio', data);

      if (responseData['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Servicio cancelado con éxito")),
        );

        // Send cancellation notification to client
        final motivoDescripcion =
            motivosList.firstWhere(
              (m) => m['id'] == idMotivo,
              orElse: () => {'descripcion': 'No especificado'},
            )['descripcion'];

        await NotificationService().notificarServicioCancelado(
          clienteId: user_id,
          idAlquiler: widget.idAlquiler,
          motivoDescripcion: motivoDescripcion,
        );

        // Reload service details to show updated status
        await _detailService();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al cancelar: ${responseData['message']}"),
          ),
        );
      }
    } catch (e) {
      print("Error en la cancelación: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error en la solicitud de cancelación")),
      );
    }
  }

  Future<void> obtenerMotivos() async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });

    try {
      final responseData = await ApiService().post('get_motivos', {});
      if (responseData['status'] == 'ok') {
        final motivosParseados =
            (responseData['motivos'] as List).map((motivo) {
              return {
                'id': int.parse(motivo['id'].toString()),
                'descripcion': motivo['descripcion'],
              };
            }).toList();

        setState(() {
          motivosList = motivosParseados;
        });
      }
    } catch (e) {
      print("Error en buscar motivos: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al cargar los motivos de cancelación"),
        ),
      );
    } finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  Future<void> _mostrarModalMotivos() async {
    try {
      await obtenerMotivos();

      if (motivosList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No hay motivos disponibles para cancelación"),
          ),
        );
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Selecciona el motivo de cancelación",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: motivosList.length,
                        itemBuilder: (context, index) {
                          final motivo = motivosList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: RadioListTile<int>(
                              title: Text(motivo['descripcion']),
                              value: motivo['id'],
                              groupValue: motivoSeleccionado,
                              onChanged: (int? value) {
                                setModalState(() {
                                  motivoSeleccionado = value;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed:
                          motivoSeleccionado != null
                              ? () {
                                Navigator.pop(context);
                                cancelar(motivoSeleccionado!);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Enviar",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al mostrar los motivos")),
      );
    }
  }

  Future<void> _detailService() async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });

    final data = {
      'id_alquiler': widget.idAlquiler,
      'user_id': userId, // aseguramos que nunca sea null
    };

    print("📤 Enviando a API: $data");

    try {
      final responseData = await ApiService().post('get_detail_service', data);

      if (responseData['status'] == 'ok') {
        final servicio = responseData['servicio'];
        print("✅ Servicio recibido: $servicio");

        setState(() {
          clienteNombre = servicio['nombre'] ?? '';
          clienteDireccion = servicio['direccion'] ?? '';
          clienteTelefono = servicio['telefono'] ?? '';
          tipoLavadora = servicio['type'] ?? '';
          descripcionLavadora = servicio['codigo'] ?? '';
          conductorId = servicio['conductor_id']?.toString() ?? '0';
          user_id = servicio['user_id']?.toString() ?? '0';
          valorServicio = servicio['valor_servicio']?.toString() ?? '0';

          // Get and store service status
          statusServicio = servicio['status_servicio']?.toString() ?? '1';

          print('👤 Usuario API: $user_id');
          print('🚗 Conductor ID: $conductorId');
          print('📊 Status Servicio: $statusServicio');
          print('💰 Valor Servicio: $valorServicio');

          origen = LatLng(
            double.tryParse(servicio['lat_delivery']?.toString() ?? '0') ?? 0,
            double.tryParse(servicio['long_delivery']?.toString() ?? '0') ?? 0,
          );
          destino = LatLng(
            double.tryParse(servicio['lat_client']?.toString() ?? '0') ?? 0,
            double.tryParse(servicio['long_client']?.toString() ?? '0') ?? 0,
          );

          // Service is accepted if:
          // 1. Current user is the assigned conductor, OR
          // 2. Service status is 2 (En Curso), 3 (Por Retirar), or 4 (Finalizado)
          if ((userId == conductorId && conductorId != '0') ||
              statusServicio == '2' ||
              statusServicio == '3' ||
              statusServicio == '4') {
            servicioAceptado = true;
            print('✅ Servicio marcado como aceptado');
          } else {
            print('⚠️ Servicio NO aceptado aún');
          }
        });

        await _getRouteInfo();
      } else {
        print("⚠️ API devolvió status != ok: ${responseData['status']}");
      }
    } catch (e, stack) {
      print('🔥 Error en la solicitud a la API: $e');
      print(stack);
    } finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  Future<void> _aceptService() async {
    final data = {'id_alquiler': widget.idAlquiler, 'user_id': userId};

    try {
      await ApiService().post('aceptar_servicio', data);
      setState(() {
        servicioAceptado = true;
        conductorId = userId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Servicio aceptado correctamente")),
      );

      // Send notification to client
      final nombreDomiciliario = user['nombre'] ?? 'Domiciliario';
      await NotificationService().notificarServicioAceptado(
        clienteId: user_id,
        nombreDomiciliario: nombreDomiciliario,
        idAlquiler: widget.idAlquiler,
      );
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Entrega de Lavadora"),
        backgroundColor: Colors.indigo,
      ),
      body:
          isLoading
              ? Container(
                color: Colors.white,
                child: const Center(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'Procesando...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : Column(
                children: [
                  // Enhanced Map Section
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: GoogleMap(
                            onMapCreated: (controller) {
                              _mapController = controller;
                              // Disable unnecessary features to reduce API calls
                              controller.setMapStyle(
                                null,
                              ); // Use default style (no custom styling API calls)
                            },
                            initialCameraPosition: CameraPosition(
                              target:
                                  origen.latitude == 0
                                      ? const LatLng(7.894769, -72.507820)
                                      : origen,
                              zoom: 14,
                            ),
                            markers: _markers,
                            polylines: _polylines,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            // Cost optimization settings
                            compassEnabled: false, // Disable compass
                            rotateGesturesEnabled: false, // Disable rotation
                            tiltGesturesEnabled: false, // Disable tilt (3D)
                            buildingsEnabled: false, // Disable 3D buildings
                            indoorViewEnabled: false, // Disable indoor maps
                            trafficEnabled: false, // Disable traffic layer
                            liteModeEnabled:
                                false, // Keep interactive for navigation
                            // Reduce map interactions to minimize tile requests
                            minMaxZoomPreference: const MinMaxZoomPreference(
                              10,
                              18,
                            ),
                          ),
                        ),
                      ),

                      // Map Controls Overlay
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Column(
                          children: [
                            // Center on my location button
                            FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: () async {
                                try {
                                  Position position =
                                      await Geolocator.getCurrentPosition();
                                  _mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: LatLng(
                                          position.latitude,
                                          position.longitude,
                                        ),
                                        zoom: 16,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  print('Error getting location: $e');
                                }
                              },
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF0090FF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Zoom to fit route
                            FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: () {
                                if (origen.latitude != 0 &&
                                    destino.latitude != 0) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngBounds(
                                      LatLngBounds(
                                        southwest: LatLng(
                                          origen.latitude < destino.latitude
                                              ? origen.latitude
                                              : destino.latitude,
                                          origen.longitude < destino.longitude
                                              ? origen.longitude
                                              : destino.longitude,
                                        ),
                                        northeast: LatLng(
                                          origen.latitude > destino.latitude
                                              ? origen.latitude
                                              : destino.latitude,
                                          origen.longitude > destino.longitude
                                              ? origen.longitude
                                              : destino.longitude,
                                        ),
                                      ),
                                      100,
                                    ),
                                  );
                                }
                              },
                              child: const Icon(
                                Icons.zoom_out_map,
                                color: Color(0xFF0090FF),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Navigate button at bottom
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (destino.latitude != 0 &&
                                destino.longitude != 0) {
                              final url = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=${destino.latitude},${destino.longitude}&travelmode=driving',
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.navigation, size: 20),
                          label: const Text(
                            'Abrir en Google Maps',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0090FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Distance and Time Card
                  if (distancia.isNotEmpty && duracion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0090FF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Color(0xFF0090FF),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.straighten,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          distancia,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          duracion,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Contenido
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Client Info Card
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF0090FF,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFF0090FF),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Datos del Cliente",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0090FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(
                                    Icons.account_circle,
                                    "Nombre",
                                    clienteNombre,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    Icons.location_on,
                                    "Dirección",
                                    clienteDireccion,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    Icons.phone,
                                    "Teléfono",
                                    clienteTelefono,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Washer Info Card
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.local_laundry_service,
                                          color: Colors.green,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Lavadora Asignada",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(
                                    Icons.category,
                                    "Tipo",
                                    tipoLavadora,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    Icons.qr_code,
                                    "Código",
                                    descripcionLavadora,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons Section
                  SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Check if service is completed (status 4)
                          if (statusServicio == '4') ...[
                            // Service completed - Show completion message only
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Servicio Finalizado",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Este servicio ha sido completado exitosamente",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (servicioAceptado ||
                              userId == conductorId) ...[
                            // Status-based button display
                            // Status 1: Aceptado - Show delivery button
                            // Status 2: En Curso - Only chat and cancel (washer in use)
                            // Status 3: Por Retirar - Show pickup button
                            if (statusServicio == '2') ...[
                              // Status 2 - En Curso (lavadora ya entregada, en uso)
                              // Solo mostrar Chat y Cancelar
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ChatScreen(
                                              rentalId: widget.idAlquiler,
                                              deliveryId:
                                                  int.tryParse(user_id) ?? 0,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble, size: 18),
                                  label: const Text(
                                    "Chat con Cliente",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0090FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _mostrarModalMotivos,
                                  icon: const Icon(Icons.cancel, size: 20),
                                  label: const Text(
                                    "Cancelar Servicio",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (statusServicio == '6') ...[
                              // Status 6 - En proceso de entrega (domiciliario va en camino)
                              // Mostrar botón "Confirmar Entrega"
                              Row(
                                children: [
                                  // Confirmar Entrega Button
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: confirmarEntrega,
                                      icon: const Icon(
                                        Icons.check_circle,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        "Confirmar Entrega",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Chat Button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ChatScreen(
                                                  rentalId: widget.idAlquiler,
                                                  deliveryId:
                                                      int.tryParse(user_id) ??
                                                      0,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.chat_bubble,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        "Chat",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0090FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Cancel Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _mostrarModalMotivos,
                                  icon: const Icon(Icons.cancel, size: 20),
                                  label: const Text(
                                    "Cancelar Servicio",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Status 1 or 3 - Show action button + chat
                              // Primary Actions Row
                              Row(
                                children: [
                                  // Main Action Button (Entregar or Recoger)
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: entregar,
                                      icon: Icon(
                                        statusServicio == '3'
                                            ? Icons.shopping_bag
                                            : Icons.check_circle,
                                        size: 20,
                                      ),
                                      label: Text(
                                        statusServicio == '3'
                                            ? "Recoger Lavadora"
                                            : "Realizar Entrega",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            statusServicio == '3'
                                                ? Colors.orange
                                                : Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Chat Button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ChatScreen(
                                                  rentalId: widget.idAlquiler,
                                                  deliveryId:
                                                      int.tryParse(user_id) ??
                                                      0,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.chat_bubble,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        "Chat",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0090FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Cancel Button (only for status 1, not 3 or 4)
                              if (statusServicio != '3' &&
                                  statusServicio != '4') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _mostrarModalMotivos,
                                    icon: const Icon(Icons.cancel, size: 20),
                                    label: const Text(
                                      "Cancelar Servicio",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                        color: Colors.red,
                                        width: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ] else ...[
                            // Accept Button (when not accepted yet)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _aceptService,
                                icon: const Icon(Icons.check_circle, size: 22),
                                label: const Text(
                                  "Aceptar Servicio",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Botón Aceptar / Cancelar
                ],
              ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
