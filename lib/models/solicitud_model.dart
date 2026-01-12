import 'dart:math';

class Solicitud {
  final int idAlquiler;
  final String clienteId;
  final String nombreCliente;
  final String direccionCliente;
  final String telefonoCliente;
  final String tipoLavadora;
  final int tiempoAlquiler;
  final double latitud;
  final double longitud;
  final double total;
  final String metodoPago;
  final String fechaInicio;
  final String tariffType; // Tipo de tarifa: normal, 24_hours, nocturnal
  final double? distanciaKm; // Distance from API or calculated

  Solicitud({
    required this.idAlquiler,
    required this.clienteId,
    required this.nombreCliente,
    required this.direccionCliente,
    required this.telefonoCliente,
    required this.tipoLavadora,
    required this.tiempoAlquiler,
    required this.latitud,
    required this.longitud,
    required this.total,
    required this.metodoPago,
    required this.fechaInicio,
    this.tariffType = 'normal',
    this.distanciaKm,
  });

  // Compatibility getter for old code
  String get id => idAlquiler.toString();
  String get userId => clienteId;
  String get totalAmount => total.toString();

  factory Solicitud.fromJson(Map<String, dynamic> json) {
    return Solicitud(
      idAlquiler: int.parse(json['id_alquiler'].toString()),
      clienteId: json['user_id'].toString(),
      nombreCliente: json['nombre_cliente'] ?? '',
      direccionCliente: json['direccion_cliente'] ?? '',
      telefonoCliente: json['telefono_cliente'] ?? '',
      tipoLavadora: json['tipo_lavadora'] ?? '',
      tiempoAlquiler: int.tryParse(json['tiempo_alquiler'].toString()) ?? 0,
      latitud: double.tryParse(json['latitud'].toString()) ?? 0.0,
      longitud: double.tryParse(json['longitud'].toString()) ?? 0.0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      metodoPago: json['metodo_pago'] ?? 'efectivo',
      fechaInicio: json['fecha_inicio'] ?? '',
      tariffType: json['tariff_type'] ?? 'normal',
      distanciaKm: double.tryParse(json['distancia_km']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_alquiler': idAlquiler,
      'user_id': clienteId,
      'nombre_cliente': nombreCliente,
      'direccion_cliente': direccionCliente,
      'telefono_cliente': telefonoCliente,
      'tipo_lavadora': tipoLavadora,
      'tiempo_alquiler': tiempoAlquiler,
      'latitud': latitud,
      'longitud': longitud,
      'total': total,
      'metodo_pago': metodoPago,
      'fecha_inicio': fechaInicio,
      'tariff_type': tariffType,
      if (distanciaKm != null) 'distancia_km': distanciaKm,
    };
  }

  // Helper to calculate distance from driver's location
  double calcularDistancia(double driverLat, double driverLng) {
    // Simple Haversine formula
    const double earthRadius = 6371; // km

    double dLat = _toRadians(latitud - driverLat);
    double dLng = _toRadians(longitud - driverLng);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(driverLat)) *
            cos(_toRadians(latitud)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180;
  }

  String getDistanciaTexto(double driverLat, double driverLng) {
    double distancia = calcularDistancia(driverLat, driverLng);
    if (distancia < 1) {
      return '${(distancia * 1000).toStringAsFixed(0)} m';
    }
    return '${distancia.toStringAsFixed(1)} km';
  }
}
