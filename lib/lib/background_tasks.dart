// background_tasks.dart

import 'package:lavadora_app/services/api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> checkServicioPendiente(String uid) async {
  final data = {'user_id': uid};
  try {
    final jsonResponse = await ApiService().post('servicio_pendiente', data);
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
  } catch (e) {
    print("Error en servicio pendiente: $e");
  }
}

Future<void> checkPendienteRecoger(String uid) async {
  final data = {'user_id': uid};
  try {
    final jsonResponse = await ApiService().post('pendiente_recoger', data);
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
