class Lavadora {
  final String id;
  final String codigo;
  final String descripcion;
  final String estado;
  final double precio;

  Lavadora({
    required this.id,
    required this.codigo,
    required this.descripcion,
    required this.estado,
    required this.precio,
  });

  factory Lavadora.fromJson(Map<String, dynamic> json) {
    return Lavadora(
      id: json['id'].toString(),
      codigo: json['codigo'] ?? '',
      descripcion:
          json['type'] ?? '', // Mapped from 'type' as per original code
      estado: json['status'] ?? 'disponible',
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
    );
  }
}
