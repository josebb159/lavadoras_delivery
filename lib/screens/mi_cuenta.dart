import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lavadora_app/services/api_service.dart';

import 'dart:convert';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({Key? key}) : super(key: key);

  @override
  _MiCuentaScreenState createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _nombreController = TextEditingController();
  TextEditingController _apellidoController = TextEditingController();
  TextEditingController _telefonoController = TextEditingController();
  TextEditingController _direccionController = TextEditingController();

  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      setState(() {
        user = json.decode(userData);
        _nombreController.text = user?['nombre'] ?? '';
        _apellidoController.text = user?['apellido'] ?? '';
        _telefonoController.text = user?['telefono'] ?? '';
        _direccionController.text = user?['direccion'] ?? '';
      });
    }
  }

  void _mostrarDialogoCambioPassword(BuildContext context) {
    final TextEditingController nuevaPassController = TextEditingController();
    final TextEditingController confirmarPassController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cambiar contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nuevaPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmarPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final nuevaPass = nuevaPassController.text.trim();
                final confirmarPass = confirmarPassController.text.trim();

                if (nuevaPass.isEmpty || confirmarPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor llena ambos campos'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (nuevaPass != confirmarPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Las contraseñas no coinciden'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final data = {
                  'id': user?['id'].toString(),
                  'password': nuevaPass,
                };

                try {
                  final responseData = await ApiService().post(
                    'update_password_config',
                    data,
                  );

                  if (responseData['status'] == 'ok') {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contraseña actualizada exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error: ${responseData['message'] ?? 'No se pudo cambiar la contraseña'}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al conectar con el servidor: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: const Color(0xFF0090FF),
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        "id": user?['id'].toString(),
        "nombre": _nombreController.text,
        "apellido": _apellidoController.text,
        "telefono": _telefonoController.text,
        "direccion": _direccionController.text,
      };

      try {
        final responseData = await ApiService().post('edit_user', updatedData);
        if (responseData['status'] == 'ok') {
          // Actualizar SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          user?['nombre'] = _nombreController.text;
          user?['apellido'] = _apellidoController.text;
          user?['telefono'] = _telefonoController.text;
          user?['direccion'] = _direccionController.text;
          prefs.setString('user', json.encode(user));

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos actualizados correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${responseData['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocurrió un error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
        backgroundColor: const Color(0xFF0090FF),
        elevation: 0,
      ),
      body:
          user == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0090FF),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Text(
                              (user?['nombre'] ?? 'X')[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0090FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${user?['nombre'] ?? ''} ${user?['apellido'] ?? ''}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user?['correo'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form Section
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildTextField(
                              controller: _nombreController,
                              label: 'Nombre',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu nombre';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _apellidoController,
                              label: 'Apellido',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu apellido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _telefonoController,
                              label: 'Teléfono',
                              icon: Icons.phone_android,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _direccionController,
                              label: 'Dirección',
                              icon: Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 30),

                            // Action Buttons
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveChanges,
                                icon: const Icon(Icons.save),
                                label: const Text(
                                  'Guardar cambios',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: const Color(0xFF0090FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _mostrarDialogoCambioPassword(context);
                                },
                                icon: const Icon(Icons.lock_reset),
                                label: const Text(
                                  'Cambiar contraseña',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  foregroundColor: const Color(0xFF0090FF),
                                  side: const BorderSide(
                                    color: Color(0xFF0090FF),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0090FF)),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0090FF), width: 1.5),
        ),
      ),
    );
  }
}
