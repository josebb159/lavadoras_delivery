import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'package:lavadora_app/screens/servicio_screen.dart';
import 'package:lavadora_app/screens/pagos_screen.dart';
import 'package:lavadora_app/screens/recoger_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic> user = {};
  bool isLoading = false;
  Map<String, dynamic> rental = {};
  bool hasservice = false;
  bool rentalFinished = false;
  Map<String, dynamic> conductorUbicacion = {};
  List<Map<String, dynamic>> lavadoras = [];
  String valorRecaudado = '0';
  late Timer ubicacionTimer;
  bool vistaServiciosAbierta = false;
  String? bannerUrl;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _getBanner();
   // _saveFcmToken();

   // _ServicioPendiente(user['id']);
  //  _PendienteRecoger(user['id']);
  //  _getLavadorasAsignadas(user['id']);
  //  _get_recaudado(user['id']);
  //  _get_servicio_solicitud_domicialiario(user['id']);
    if (user.isNotEmpty) {
    final userId = user['id']; // asegúrate de que esté disponible
    //registrarTareasBackground(userId);
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> update_system(String userId) async {
    _loadUserData();
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // la app volvió a primer plano
      _ejecutarFunciones();
    }
  }

  void _ejecutarFunciones() {
    _loadUserData();
    //  _getBanner();
    // _saveFcmToken();

    //  _ServicioPendiente(user['id']);
 //   _PendienteRecoger(user['id']);
 //   _getLavadorasAsignadas(user['id']);
 //   _get_recaudado(user['id']);
 //   _get_servicio_solicitud_domicialiario(user['id']);
  }



  Future<void> _saveFcmToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Obtener token de FCM
    String? token = await messaging.getToken();
    try {
      final res = await http.post(
        Uri.parse(
            'https://alquilav.com/api/api.php?action=save_fcm'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user['id'],
          'token': token,
        }),
      );

      print("📡 Status code: ${res.statusCode}");
      print("📡 Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        print("✅ Data decodificada: $data");

        if (data['status'] == 'ok') {
          print("🎉 Token guardado correctamente en el servidor");
        } else {
          print("⚠️ El servidor respondió con error: ${data['status']}");
        }
      } else {
        print("❌ Error HTTP: ${res.statusCode}");
      }
    } catch (e, stack) {
      print("❌ Error guardando token FCM: $e");
      print(stack);
    }
  }









  void registrarTareasBackground(String userId) {
    Workmanager().registerPeriodicTask(
      'tarea_pendiente',
      'servicioPendiente',
      frequency: const Duration(minutes: 15),
      inputData: {'user_id': '123'},
    );

    Workmanager().registerPeriodicTask(
      'tarea_recoger',
      'pendienteRecoger',
      frequency: const Duration(minutes: 15),
      inputData: {'user_id': '123'},
    );

  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('ic_notification'); // SIN .png

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }



  Future<void> _mostrarNotificacion(String titulo, String mensaje) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_id',
      'Canal de Notificaciones',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification', // 👈 Agregado aquí
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // ID de la notificación
      titulo,
      mensaje,
      platformDetails,
    );
  }

  /*
  @override
  void dispose() {
    ubicacionTimer.cancel();
    super.dispose();
  }
*/
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData != null) {
      // decodificamos primero
      final decodedUser = json.decode(userData);
      final id = decodedUser['id'];

      print("usuario_id $id");

      // aquí puedes correr las tareas asíncronas sin setState
      _saveFcmToken();
      await verificarCancelacionPermitida(context, id);
      _ServicioPendiente(id);
      _PendienteRecoger(id);
      _getLavadorasAsignadas(id);
       _get_recaudado(id);
      // _get_servicio_solicitud_domicialiario(id);
      // updateUbicacionDomiciliario(id.toString());

      // ahora sí actualizas el estado
      setState(() {
        user = decodedUser;
      });
    }
  }




  Future<void> updateUbicacionDomiciliario(String uid) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          print('Permiso de ubicación denegado');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final data = {
        'user_id': uid,
        'latitud': position.latitude.toString(),
        'longitud': position.longitude.toString(),
      };

      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=update_ubicacion_domiciliario'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        print('Ubicación actualizada correctamente');
      } else {
        print('Error al actualizar ubicación: ${response.statusCode}');
      }
    } catch (e) {
      print('Excepción al actualizar ubicación: $e');
    }
  }

  Future<void> _getBanner() async {
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=get_banner'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}), // si no requiere parámetros
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'ok') {
          setState(() {
            bannerUrl = responseData['banner'];
          });
        }
      }
    } catch (e) {
      print('Error al obtener banner: $e');
    }
  }


  Future<void> verificarCancelacionPermitida(BuildContext context, String userId) async {
    final data = {'user_id': userId};

    try {
      final response = await http.post(
        Uri.parse(
            'https://alquilav.com/api/api.php?action=check_cancelacion_permitida'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'denegado') {
          // 🚫 Navegar a otra pantalla si el usuario está bloqueado
        //  Navigator.of(context).pushReplacementNamed('/UsuarioBloqueadoScreen');
        } else {
          // ✅ Todo bien, continuar normalmente
          print("Cancelación permitida. Puedes continuar.");
        }
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('🛑 Error en la solicitud: $e');
    }
  }

  Future<void> _get_servicio_solicitud_domicialiario(String uid) async {
    print('Busca get_servicio_solicitud_domicialiario');
    final data = {'user_id': uid};
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=get_servicio_solicitud_domicialiario'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'ok' && jsonResponse['servicio'] != null) {
          final servicio = jsonResponse['servicio'];
          final int idAlquiler = int.parse(servicio['id'].toString());

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MisServiciosPendiente(idAlquiler: idAlquiler),
            ),
          );
        }
      } else {
        print('Error en respuesta API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }
  }

  Future<void> _get_recaudado(String uid) async {
    print('Busca recaudo');
    final data = {'user_id': uid};
    print('❌ userId: ${uid}');
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=recaudado'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print(response.body);

        if (jsonResponse['status'] == 'ok' &&
            jsonResponse['recaudado'] != null) {
          setState(() {
            valorRecaudado = jsonResponse['recaudado'].toString();
          });

          print('❌ valorRecaudado: ${valorRecaudado}');
        } else {
          print('Error en respuesta API: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }
  }


  Future<void> _ServicioPendiente(String uid) async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });
    print('Busca servicio pendiente');

    final data = {'user_id': uid};
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=servicio_pendiente'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'ok' && jsonResponse['servicio'] != null) {
          final servicio = jsonResponse['servicio'];
          final int idAlquiler = int.parse(servicio['id'].toString());


          // Mostrar la notificación
          await _mostrarNotificacion(
            'Servicio Pendiente',
            'Tienes un servicio pendiente por realizar',
          );
          vistaServiciosAbierta = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MisServiciosPendiente(idAlquiler: idAlquiler),
            ),
          ).then((_) {
            // Cuando se cierre la vista, se permite volver a abrirla
            vistaServiciosAbierta = false;
          });
        }
      } else {
        print('Error en respuesta API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }
    finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  Future<void> _PendienteRecoger(String uid) async {
    print('Busca lavadora por recoger');
    final data = {'user_id': uid};
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=pendiente_recoger'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'ok' && jsonResponse['servicio'] != null) {
          final servicio = jsonResponse['servicio'];
          final int idAlquiler = int.parse(servicio['id'].toString());

          // Mostrar la notificación
          await _mostrarNotificacion(
            'Servicio Pendiente',
            'Tienes un servicio pendiente por recoger',
          );
          vistaServiciosAbierta = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecogerScreen(idAlquiler: idAlquiler),
            ),
          ).then((_) {
            // Cuando se cierre la vista, se permite volver a abrirla
            vistaServiciosAbierta = false;
          });
        }
      } else {
        print('Error en respuesta API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la solicitud a la API: $e');
    }
  }


  Future<void> _getLavadorasAsignadas(String userId) async {
    print('Busca lavadoras asignadas');
    setState(() {
      isLoading = true;
    });

    final data = {'user_id': userId};
    try {
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=lavadoras_asignadas'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print(response.body);
        if (responseData['status'] == 'ok') {
          List<dynamic> asignadas = responseData['asignadas'];

          double total = 0;
          for (var lavadora in asignadas) {
            total += double.tryParse(lavadora['precio']?.toString() ?? '0') ?? 0;
          }

          setState(() {
            lavadoras = asignadas.map((lavadora) {
              return {
                'id': lavadora['id'],
                'codigo': lavadora['codigo'],
                'descripcion': lavadora['type'],
                'estado': lavadora['status'] ?? 'disponible',
                'precio': lavadora['precio']?.toString() ?? '0',
                'codigo': lavadora['codigo'] ?? '',
              };
            }).toList();

          /*  valorRecaudado = total.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
            ); */
            //valorRecaudado ="0";
            isLoading = false;
          });
        } else {
          setState(() {
            lavadoras = [];
           // valorRecaudado = '0';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error al obtener las lavadoras asignadas: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                SizedBox(height: 10),
                Text(
                  user['nombre'] ?? 'Usuario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['email'] ?? '',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
    ListTile(
    leading: Icon(Icons.miscellaneous_services), // mejor para "Servicios"
    title: Text('Mis Servicios'),
    onTap: () {
    Navigator.pushNamed(context, '/mis_servicios');
    },
    ),
    ListTile(
    leading: Icon(Icons.payment), // ícono de pago (PayU)
    title: Text('Pagos PayU'),
    onTap: () {
    Navigator.pushNamed(context, '/pagosyu');
    },
    ),
    ListTile(
    leading: Icon(Icons.attach_money), // otro estilo de pagos
    title: Text('Pagos'),
    onTap: () {
    Navigator.pushNamed(context, '/pagos');
    },
    ),
    ListTile(
    leading: Icon(Icons.account_balance_wallet), // recarga -> billetera
    title: Text('Recargar'),
    onTap: () {
    Navigator.pushNamed(context, '/recarga');
    },
    ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet), // recarga -> billetera
            title: Text('Lavadoras'),
            onTap: () {
              Navigator.pushNamed(context, '/lavadora');
            },
          ),
    ListTile(
    leading: Icon(Icons.person), // perfil / cuenta personal
    title: Text('Mi Cuenta'),
    onTap: () {
    Navigator.pushNamed(context, '/mi_cuenta');
    },
    ),

          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text('Salir'),
            onTap: () {
              _logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Lavadoras'),
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (bannerUrl != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Image.network(
                bannerUrl!,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Valor recaudado:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$$valorRecaudado',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: lavadoras.isEmpty ? 1 : lavadoras.length,
              itemBuilder: (context, index) {
                if (lavadoras.isEmpty) {
                  return const Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text('No hay lavadoras asignadas'),
                      subtitle: Text('Actualmente no tienes lavadoras asignadas'),
                      tileColor: Colors.grey,
                      leading: Icon(Icons.info, color: Colors.grey),
                    ),
                  );
                }

                final lavadora = lavadoras[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('Lavadora ${lavadora['codigo']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Descripción: ${lavadora['descripcion']}'),
                        Text('Codigo: ${lavadora['codigo']}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('\$${lavadora['precio']}'),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: lavadora['estado'] == 'disponible'
                                ? Colors.green[100]
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            lavadora['estado'],

                            style: TextStyle(
                              color: lavadora['estado'] == 'alquilada'
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    leading: const Icon(Icons.local_laundry_service, size: 40),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}