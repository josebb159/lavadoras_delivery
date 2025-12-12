class User {
  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  final String? rol;

  User({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.rol,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'],
      rol: json['rol'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'rol': rol,
    };
  }
}
