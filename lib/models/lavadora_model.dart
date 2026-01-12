class Lavadora {
  final String id;
  final String codigo;
  final String descripcion;
  final String estado;
  final double precio;
  final String? clienteActual;
  final double precioNormal;
  final double precio24Horas;
  final double precioNocturno;

  Lavadora({
    required this.id,
    required this.codigo,
    required this.descripcion,
    required this.estado,
    required this.precio,
    this.clienteActual,
    required this.precioNormal,
    required this.precio24Horas,
    required this.precioNocturno,
  });

  factory Lavadora.fromJson(Map<String, dynamic> json) {
    return Lavadora(
      id: json['id'].toString(),
      codigo: json['codigo'] ?? '',
      descripcion: json['type'] ?? '',
      estado: json['status'] ?? 'disponible',
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      clienteActual: json['cliente_actual'],
      precioNormal:
          double.tryParse(json['precio_normal']?.toString() ?? '0') ?? 0.0,
      precio24Horas:
          double.tryParse(json['precio_24horas']?.toString() ?? '0') ?? 0.0,
      precioNocturno:
          double.tryParse(json['precio_nocturno']?.toString() ?? '0') ?? 0.0,
    );
  }

  bool get isAlquilada => estado.toLowerCase() == 'alquilada';
  bool get isDisponible => estado.toLowerCase() == 'disponible';
}
