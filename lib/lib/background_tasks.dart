// background_tasks.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> checkServicioPendiente(String uid) async {
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

        await flutterLocalNotificationsPlugin.show(
          1,
          "Servicio Pendiente",
          "Tienes un servicio pendiente",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'canal_id',
              'Canal de Notificaciones',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
          ),
        );
      }
    }
  } catch (e) {
    print("Error en servicio pendiente: $e");
  }
}

Future<void> checkPendienteRecoger(String uid) async {
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

        await flutterLocalNotificationsPlugin.show(
          1,
          'Servicio Pendiente',
          'Tienes un servicio pendiente por recoger',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'canal_id',
              'Canal de Notificaciones',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
          ),
        );
      }
    }
  } catch (e) {
    print("Error en servicio pendiente: $e");
  }
}

/// Esta función la llama Workmanager en segundo plano
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final uid = inputData?['user_id'];
    if (uid == null) return Future.value(false);

    switch (task) {
      case 'servicioPendiente':
        await checkServicioPendiente(uid);
        break;
      case 'pendienteRecoger':
        await checkPendienteRecoger(uid);
        break;
    }

    return Future.value(true);
  });
}
