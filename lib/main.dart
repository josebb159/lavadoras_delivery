import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/Rental_screen.dart';
import 'screens/mis_servicios_screen.dart';
import 'screens/mi_cuenta.dart';
import 'screens/servicio_screen.dart';
import 'screens/recarga.dart';
import 'screens/pagos_screen.dart';
import 'screens/pagos_payu_screen.dart';
import 'screens/lavadoras.dart';
import 'package:workmanager/workmanager.dart';
import 'lib/background_tasks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/solicitudes_provider.dart';
import 'screens/solicitudes_screen.dart';
import 'core/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

// Canal de notificación (Android)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notificaciones Importantes',
  description: 'Este canal se usa para notificaciones críticas.',
  importance: Importance.high,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("📦 Mensaje en segundo plano: ${message.data}");

  final action = message.data['type'] ?? '';
  final idServicio = message.data['id_servicio'] ?? '';

  // 🔹 Título y cuerpo personalizados
  String title;
  String body;

  switch (action) {
    case 'update_rental':
      title = "Actualización de estado";
      body =
          idServicio.isNotEmpty
              ? "Tu servicio #$idServicio ha cambiado de estado."
              : "Tu servicio ha cambiado de estado.";
      break;

    case 'open_mis_servicios':
      title = "Servicios";
      body = "Accede a tus servicios activos.";
      break;

    case 'logout':
      title = "Sesión finalizada";
      body = "Se cerró tu sesión por seguridad.";
      break;

    default:
      title = "Lavadora App";
      body = "Tienes una nueva notificación.";
  }

  // 🔹 Mostrar notificación local
  flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: "id_servicio=$idServicio&type=$action",
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Solicitar permisos
  await FirebaseMessaging.instance.requestPermission();

  // ✅ Configuración para iOS (mostrar alertas en foreground)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ Inicializar notificaciones locales
  const androidInitSettings = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  const initSettings = InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload != null) {
        final data = Uri.splitQueryString(payload);
        final action = data['type'];
        final id = data['id_servicio'];

        if (action == 'update_rental' && id != null) {
          navigatorKey.currentState?.pushNamed('/mis_servicios');
        } else if (action == 'logout') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/login',
            (r) => false,
          );
        }
      }
    },
  );

  // ✅ Crear canal de notificaciones en Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // ✅ Notificación recibida en foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 Notificación recibida: ${message.data}");

    final action = message.data['type'];
    final userId = message.data['user_id'];
    String title = "Lavadora App";
    String body = "Nueva notificación";

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    Map<String, dynamic> user = {};

    if (userData != null) {
      user = json.decode(userData);
    }
    print("📦 Datos encontrados en 'user': $user");
    if (action != null) {
      switch (action) {
        case 'update_rental':
          title = "Actualización de estado";
          body = "Tu servicio ha cambiado de estado.";
          // ⚡ Aviso dentro de la app
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "📢 Actualización de estado: Tu servicio ha cambiado.",
                ),
                duration: Duration(seconds: 4),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }

          if (user['id'] != null && homeScreenKey.currentState != null) {
            print("📩 entro en update_rental notification");
            homeScreenKey.currentState!.update_system(user['id'].toString());
          }
          break;

        case 'asignacion':
          title = "Asignación";
          body = "Se asigno una lavadora.";
          // ⚡ Aviso dentro de la app
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("📢 Se asigno una lavadora."),
                duration: Duration(seconds: 4),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }

          if (user['id'] != null && homeScreenKey.currentState != null) {
            print("📩 entro en update_rental notification");
            homeScreenKey.currentState!.update_system(user['id'].toString());
          }
          break;

        case 'devuelta_bodega':
          title = "Devuelta a bodega";
          body = "La lavadora fue devuelta a bodega";
          // ⚡ Aviso dentro de la app
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("📢 La lavadora fue devuelta a bodega."),
                duration: Duration(seconds: 4),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }

          if (user['id'] != null && homeScreenKey.currentState != null) {
            print("📩 entro en update_rental notification");
            homeScreenKey.currentState!.update_system(user['id'].toString());
          }
          break;
        case 'recarga':
          title = "Recarga";
          body = "Se ha recalizado una recarga.";
          // ⚡ Aviso dentro de la app
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("📢 Se ha realizado una recarga."),
                duration: Duration(seconds: 4),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }

          if (user['id'] != null && homeScreenKey.currentState != null) {
            print("📩 entro en recarga");
            homeScreenKey.currentState!.update_system(user['id'].toString());
          }
          break;

        case 'open_mis_servicios':
          navigatorKey.currentState?.pushNamed('/mis_servicios');
          break;

        case 'logout':
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/login',
            (r) => false,
          );
          break;

        default:
          print("⚠️ Acción desconocida: $action");
      }
      // 🔹 Mostrar notificación local
      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: "type=$action",
      );
    }
  });

  // ✅ App abierta desde cerrada (cuando el usuario toca la notificación)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final id = initialMessage.data['id_servicio'];
    if (id != null) {
      Future.delayed(Duration.zero, () {
        navigatorKey.currentState?.pushNamed('/mis_servicios');
      });
    }
  }

  // ✅ App abierta desde background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final id = message.data['id_servicio'];
    if (id != null) {
      navigatorKey.currentState?.pushNamed('/mis_servicios');
    }
  });

  // ✅ Handler en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SolicitudesProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey:
          navigatorKey, // 👈 Necesario para navegación desde notificaciones
      title: 'Lavadora',
      theme: AppTheme.lightTheme, // Aplicar tema Material 3
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(key: homeScreenKey),
        '/register': (context) => RegisterScreen(),
        '/pagos': (context) => PagosScreen(),
        '/pagosyu': (context) => PagosPayUScreen(),
        '/rental': (context) => const RentalScreen(),
        '/mis_servicios': (context) => MisServiciosScreen(),
        '/mi_cuenta': (context) => MiCuentaScreen(),
        '/recarga': (context) => RecargaScreen(),
        '/lavadora': (context) => MisLavadorasScreen(),
        '/solicitudes': (context) => const SolicitudesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/servicio') {
          final idAlquiler = settings.arguments as String;
          return MaterialPageRoute(
            builder:
                (context) =>
                    MisServiciosPendiente(idAlquiler: int.parse(idAlquiler)),
          );
        }
        return null;
      },
    );
  }
}
