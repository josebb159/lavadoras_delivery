import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lavadora_app/screens/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:lavadora_app/screens/chat.dart';
class RecogerScreen extends StatefulWidget {
  final int idAlquiler;
  const RecogerScreen({Key? key, required this.idAlquiler}) : super(key: key);

  @override
  _RecogerScreenState createState() => _RecogerScreenState();
}

class _RecogerScreenState extends State<RecogerScreen> {
  Map<String, dynamic> user = {};
  String userId = '';
  String conductorId = '';
  String user_id = '';
  // Datos del servicio
  String clienteNombre = '';
  String clienteDireccion = '';
  String clienteTelefono = '';
  String tipoLavadora = '';
  String descripcionLavadora = '';
  double total = 0;
  bool servicioAceptado = false;
  Set<Polyline> _polylines = {};
  String distancia = "";
  String duracion = "";
  bool isLoading = false;
  // Variables para motivos de cancelación
  List<dynamic> motivosList = [];
  int? motivoSeleccionado;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Timer? _ubicacionTimer;


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

    //enviarUbicacionPeriodicamente();
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

    //_iniciarEnvioUbicacion(); // empieza a enviar y actualizar mapa
  }

  void _iniciarEnvioUbicacion() {
    _ubicacionTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final response = await http.post(
          Uri.parse('https://alquilav.com/api/api.php?action=update_ubicacion_domiciliario'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({

            'user_id': userId,
            'latitud': position.latitude.toString(),
            'longitud': position.longitude.toString(),
          }),
        );

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


        if (response.statusCode == 200) {
          print('✅ Ubicación enviada correctamente');
          _actualizarMapa(position.latitude, position.longitude);
        } else {
          print('❌ Error al enviar ubicación: ${response.statusCode}');
        }
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
    super.dispose();
  }
  Future<void> enviarUbicacionPeriodicamente( ) async {
    Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final response = await http.post(
          Uri.parse('https://alquilav.com/api/api.php?action=update_ubicacion_domiciliario'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'latitud': position.latitude.toString(),
            'longitud': position.longitude.toString(),
          }),
        );

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


        if (response.statusCode == 200) {
          print('✅ Ubicación enviada correctamente');
        } else {
          print('❌ Error al enviar ubicación: ${response.statusCode}');
        }
      } catch (e) {
        print('⚠️ Error al obtener/enviar ubicación: $e');
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

    final Uri uri = Uri.parse("whatsapp://send?phone=$fullPhone&text=${Uri.encodeComponent("hola")}");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("WhatsApp no está instalado o no se puede abrir.")),
      );
    }
  }

  Future<void> _getRouteInfo() async {
    final String apiKey = "AIzaSyBz3zJ1d-TOXPhpp5t1ZNaKhWai5aVdVpc"; // Reemplaza con tu API Key
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origen.latitude},${origen.longitude}&destination=${destino.latitude},${destino.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polyline = route['overview_polyline']['points'];

        final polylinePoints = PolylinePoints().decodePolyline(polyline);
        final List<LatLng> polylineCoords = polylinePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId("ruta"),
              points: polylineCoords,
              color: Colors.blue,
              width: 5,
            )
          };

          distancia = route['legs'][0]['distance']['text'];
          duracion = route['legs'][0]['duration']['text'];
        });
      }
    } else {
      print("Error al obtener la ruta: ${response.body}");
    }
  }



  Future<void> _detailService() async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });

    final data = {'id_alquiler': widget.idAlquiler, 'user_id': userId,};
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=get_detail_service_finish'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          final servicio = responseData['servicio'];
          setState(() {
            clienteNombre = servicio['nombre'] ?? '';
            clienteDireccion = servicio['direccion'] ?? '';
            clienteTelefono = servicio['telefono'] ?? '';
            tipoLavadora = servicio['type'] ?? '';
            descripcionLavadora = servicio['codigo'] ?? '';
            conductorId = servicio['conductor_id'].toString();
            user_id = servicio['user_id']?.toString() ?? '0';

            var fechaInicio = DateTime.parse(servicio['fecha_inicio'].toString());
            var fechaFin = DateTime.parse(servicio['fecha_fin'].toString());
            var precio = double.parse(servicio['precio'].toString());
            print('❌ fechaInicion: ${fechaInicio}');
            print('❌ fechaFin: ${fechaFin}');
            print('❌ precio: ${precio}');

            final duracion = fechaFin.difference(fechaInicio).inMinutes;
            print('❌ duracion: ${duracion}');

             total = duracion * precio;
            print('❌ total: ${total}');
            origen = LatLng(
              double.tryParse(servicio['lat_delivery'] ?? '0') ?? 0,
              double.tryParse(servicio['long_delivery'] ?? '0') ?? 0,
            );
            destino = LatLng(
              double.tryParse(servicio['lat_client'] ?? '0') ?? 0,
              double.tryParse(servicio['long_client'] ?? '0') ?? 0,
            );

            if (userId == conductorId && conductorId != '0') {
              servicioAceptado = true;
            }
          });
          await _getRouteInfo();
        }
      }
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  Future<void> _recoger() async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });

    final data = {'id_alquiler': widget.idAlquiler, 'user_id': userId, 'total': total};
    print('❌ userId: ${total}');
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=recoger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      print('📥 Código de respuesta: ${response.statusCode}');
      print('📥 Respuesta body: ${response.body}'); //

      if (response.statusCode == 200) {
        setState(() {
          servicioAceptado = true;
          conductorId = userId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lavadora recogida")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
        );

      }
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recoger Lavadora"),
        backgroundColor: Colors.indigo,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Mapa
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: GoogleMap(
                onMapCreated: (controller) {
                  _mapController  = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: origen.latitude == 0 ? const LatLng(7.894769, -72.507820) : origen,
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
              ),
            ),

          ),
          if (distancia.isNotEmpty && duracion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Distancia: $distancia\nTiempo estimado: $duracion",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("📦 Datos del Cliente",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("👤 Nombre: $clienteNombre"),
                          Text("🏠 Dirección: $clienteDireccion"),
                          Row(
                            children: [
                              Text("📞 Teléfono: $clienteTelefono"),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                onPressed: clienteTelefono.isNotEmpty ? _openWhatsApp : null,
                                tooltip: 'Contactar por WhatsApp',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("🧺 Lavadora Asignada",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("🔧 Tipo: $tipoLavadora"),
                          Text("📏 Código: $descripcionLavadora"),
                          Text("💵 Total a cobrar: COP \$${total.toStringAsFixed(2)}")
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón Aceptar / Cancelar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        print("Presionaste el botón");
                        _recoger();
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor:  Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Recoger y cobrar",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              rentalId: widget.idAlquiler,
                              deliveryId: int.tryParse(user_id) ?? 0,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Chat",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}