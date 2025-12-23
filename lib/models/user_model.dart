class User {
  final String id;
  final String nombre;
  final String apellido; // Added
  final String email;
  final String? telefono;
  final String? direccion; // Added
  final String? usuario; // Added
  final String?
  rol; // Keeping for compatibility, though likely null/unused if not mapped
  final String? rol_id; // Added
  final String? conductor_negocio;
  final String? monedero; // Added
  final double? latitud; // Added
  final double? longitud; // Added
  final String? fcm; // Added
  final String? status; // Added
  final String? activo; // Added
  final String? fecha_creacion; // Added

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    this.telefono,
    this.direccion,
    this.usuario,
    this.rol,
    this.rol_id,
    this.conductor_negocio,
    this.monedero,
    this.latitud,
    this.longitud,
    this.fcm,
    this.status,
    this.activo,
    this.fecha_creacion,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      // Map 'correo' from DB to 'email', fallback to 'email' if present
      email: json['correo'] ?? json['email'] ?? '',
      telefono: json['telefono'],
      direccion: json['direccion'],
      usuario: json['usuario'],
      rol: json['rol'],
      rol_id: json['rol_id']?.toString(),
      conductor_negocio: json['conductor_negocio']?.toString(),
      monedero: json['monedero']?.toString(),
      latitud:
          json['latitud'] != null
              ? double.tryParse(json['latitud'].toString())
              : null,
      longitud:
          json['longitud'] != null
              ? double.tryParse(json['longitud'].toString())
              : null,
      fcm: json['fcm'],
      status: json['status']?.toString(),
      activo: json['activo']?.toString(),
      fecha_creacion: json['fecha_creacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'correo':
          email, // Save as 'correo' to match DB naming convention in prefs if desired, or 'email'. App uses 'user["correo"]' in header?
      'email': email, // Keeping 'email' too just in case
      'telefono': telefono,
      'direccion': direccion,
      'usuario': usuario,
      'rol': rol,
      'rol_id': rol_id,
      'conductor_negocio': conductor_negocio,
      'monedero': monedero,
      'latitud': latitud,
      'longitud': longitud,
      'fcm': fcm,
      'status': status,
      'activo': activo,
      'fecha_creacion': fecha_creacion,
    };
  }
}
