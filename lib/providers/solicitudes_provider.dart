import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/solicitud_model.dart';
import '../services/api_service.dart';

class SolicitudesProvider with ChangeNotifier {
  List<Solicitud> _solicitudes = [];
  bool _isLoading = false;
  Timer? _pollingTimer;
  final ApiService _apiService = ApiService();
  Position? _currentPosition;

  List<Solicitud> get solicitudes => _solicitudes;
  bool get isLoading => _isLoading;
  int get pendingCount => _solicitudes.length;

  // Start polling for new requests
  void startPolling(String userId) {
    // Fetch immediately
    fetchSolicitudes(userId);

    // Then poll every 10 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchSolicitudes(userId);
    });
  }

  // Stop polling when leaving screen
  void stopPolling() {
    _pollingTimer?.cancel();
  }

  /// Fetch nearby services based on delivery person's location
  Future<void> fetchSolicitudes(
    String userId, {
    bool showLoading = false,
  }) async {
    // Only show loading on manual refresh, not on automatic polling
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // Get current location
      _currentPosition = await _getCurrentLocation();

      if (_currentPosition == null) {
        print('⚠️ No se pudo obtener la ubicación');
        _solicitudes = [];
        if (showLoading) {
          _isLoading = false;
          notifyListeners();
        }
        return;
      }

      final data = {
        'user_id': userId,
        'latitud': _currentPosition!.latitude,
        'longitud': _currentPosition!.longitude,
        'radio_km': 10, // 10 km radius
      };

      print(
        '📍 Buscando servicios cercanos desde: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );

      final response = await _apiService.post('get_servicios_cercanos', data);

      if (response['status'] == 'ok') {
        final serviciosList = response['servicios'] as List? ?? [];
        final total = response['total'] ?? 0;
        final radioKm = response['radio_km'] ?? 10;

        print('✅ Encontrados $total servicios en radio de $radioKm km');

        _solicitudes =
            serviciosList.map((json) {
              return Solicitud(
                idAlquiler: int.parse(json['id_alquiler'].toString()),
                clienteId: json['user_id'].toString(),
                nombreCliente: json['nombre_cliente'] ?? 'Cliente',
                telefonoCliente: json['telefono_cliente'] ?? '',
                direccionCliente: json['direccion_cliente'] ?? '',
                tipoLavadora: json['tipo_lavadora'] ?? '',
                tiempoAlquiler:
                    int.tryParse(json['tiempo_alquiler'].toString()) ?? 0,
                latitud: double.tryParse(json['latitud'].toString()) ?? 0.0,
                longitud: double.tryParse(json['longitud'].toString()) ?? 0.0,
                total: double.tryParse(json['total'].toString()) ?? 0.0,
                metodoPago: json['metodo_pago'] ?? 'efectivo',
                fechaInicio: json['fecha_inicio'] ?? '',
                distanciaKm: double.tryParse(json['distancia_km'].toString()),
              );
            }).toList();

        print('📋 ${_solicitudes.length} solicitudes cargadas');
      } else {
        print('⚠️ Error en respuesta: ${response['message'] ?? 'Unknown'}');
        _solicitudes = [];
      }
    } catch (e) {
      print('❌ Error fetching solicitudes: $e');
      _solicitudes = [];
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> aceptarSolicitud(
    String userId,
    String idAlquiler,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('aceptar_servicio', {
        'user_id': userId,
        'id_alquiler': idAlquiler,
      });

      _isLoading = false;

      if (response['status'] == 'ok') {
        // Remove from list
        _solicitudes.removeWhere((s) => s.id == idAlquiler);
        notifyListeners();
        return {
          'success': true,
          'message': response['message'] ?? 'Servicio aceptado',
        };
      } else {
        notifyListeners();
        return {
          'success': false,
          'message': response['message'] ?? 'Error al aceptar servicio',
        };
      }
    } catch (e) {
      print('Error aceptando servicio: $e');
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error de conexión. Intenta nuevamente.',
      };
    }
  }

  Future<bool> rechazarSolicitud(String userId, String idAlquiler) async {
    try {
      // Try to call rechazar_servicio API if it exists
      final response = await _apiService.post('rechazar_servicio', {
        'user_id': userId,
        'id_alquiler': idAlquiler,
      });

      if (response['status'] == 'ok') {
        // Remove from list
        _solicitudes.removeWhere((s) => s.id == idAlquiler);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // If API doesn't exist, just remove from local list
      print('rechazar_servicio no disponible, removiendo localmente');
      _solicitudes.removeWhere((s) => s.id == idAlquiler);
      notifyListeners();
      return true;
    }
  }

  String? getDistanciaTexto(String solicitudId) {
    if (_currentPosition == null) return null;

    final solicitud = _solicitudes.firstWhere(
      (s) => s.id == solicitudId,
      orElse: () => _solicitudes.first,
    );

    // If distance is already calculated by API, use it
    if (solicitud.distanciaKm != null) {
      return solicitud.getDistanciaTexto(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    return solicitud.getDistanciaTexto(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
