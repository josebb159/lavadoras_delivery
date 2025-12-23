import 'api_service.dart';

/// Service for handling notification registration
class NotificationService {
  final ApiService _apiService = ApiService();

  /// Registers a notification for a user
  ///
  /// This method sends notifications asynchronously and does not throw errors
  /// to avoid interrupting the main application flow.
  Future<void> registrarNotificacion({
    required String userId,
    required String tipoUsuario,
    required String titulo,
    required String mensaje,
    String? tipoNotificacion,
    int? idRelacionado,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'tipo_usuario': tipoUsuario,
        'titulo': titulo,
        'mensaje': mensaje,
        if (tipoNotificacion != null) 'tipo_notificacion': tipoNotificacion,
        if (idRelacionado != null) 'id_relacionado': idRelacionado,
      };

      print('📬 Enviando notificación: $tipoNotificacion para user $userId');

      final response = await _apiService.post('registrar_notificacion', data);

      if (response['status'] == 'ok') {
        print('✅ Notificación registrada: ID ${response['id_notificacion']}');
      } else {
        print('⚠️ Error al registrar notificación: ${response['message']}');
      }
    } catch (e) {
      // Silent fail - don't interrupt main flow
      print('❌ Error enviando notificación: $e');
    }
  }

  /// Sends notification when service is accepted
  Future<void> notificarServicioAceptado({
    required String clienteId,
    required String nombreDomiciliario,
    required int idAlquiler,
  }) async {
    await registrarNotificacion(
      userId: clienteId,
      tipoUsuario: 'cliente',
      titulo: 'Servicio Aceptado',
      mensaje: '$nombreDomiciliario ha aceptado tu servicio',
      tipoNotificacion: 'servicio_aceptado',
      idRelacionado: idAlquiler,
    );
  }

  /// Sends notification when washer is delivered
  Future<void> notificarLavadoraEntregada({
    required String clienteId,
    required String nombreDomiciliario,
    required int idAlquiler,
  }) async {
    await registrarNotificacion(
      userId: clienteId,
      tipoUsuario: 'cliente',
      titulo: 'Lavadora Entregada',
      mensaje: 'Tu lavadora ha sido entregada por $nombreDomiciliario',
      tipoNotificacion: 'servicio_entregado',
      idRelacionado: idAlquiler,
    );
  }

  /// Sends notification when washer is picked up
  Future<void> notificarLavadoraRecogida({
    required String clienteId,
    required String nombreDomiciliario,
    required int idAlquiler,
  }) async {
    await registrarNotificacion(
      userId: clienteId,
      tipoUsuario: 'cliente',
      titulo: 'Lavadora Recogida',
      mensaje:
          '$nombreDomiciliario ha recogido la lavadora. Servicio finalizado',
      tipoNotificacion: 'servicio_recogido',
      idRelacionado: idAlquiler,
    );
  }

  /// Sends notification when service is cancelled
  Future<void> notificarServicioCancelado({
    required String clienteId,
    required int idAlquiler,
    String? motivoDescripcion,
  }) async {
    final mensaje =
        motivoDescripcion != null
            ? 'Tu servicio ha sido cancelado. Motivo: $motivoDescripcion'
            : 'Tu servicio ha sido cancelado';

    await registrarNotificacion(
      userId: clienteId,
      tipoUsuario: 'cliente',
      titulo: 'Servicio Cancelado',
      mensaje: mensaje,
      tipoNotificacion: 'servicio_cancelado',
      idRelacionado: idAlquiler,
    );
  }
}
