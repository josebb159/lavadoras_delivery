import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';  // Esto es necesario para trabajar con JSON en Flutter

class RegisterScreen extends StatefulWidget {
  final bool isGoogleLogin;

  const RegisterScreen({Key? key, this.isGoogleLogin = false}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}



class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _isGoogleLogin = false;
  String googleToken = '';
  bool _acceptedTerms = false;
  String _termsText = '';
  @override
  @override
  void initState() {
    super.initState();
    _loadTerms();
  }



  Future<void> _loadTerms() async {
    try {
      final response = await http.get(
        Uri.parse('https://alquilav.com/api/api.php?action=terminos_delivery'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'ok') {
          final terminosData = responseData['terminos'];
          setState(() {
            _termsText = '${terminosData['terminos_delivery']}\n\n${terminosData['terminos_uso_delivery']}';
          });
        } else {
          setState(() {
            _termsText = 'No hay términos disponibles.';
          });
        }
      } else {
        setState(() {
          _termsText = 'Error al cargar los términos.';
        });
      }
    } catch (e) {
      setState(() {
        _termsText = 'Error de conexión al cargar términos.';
      });
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
    if (arguments != null && arguments['googleLogin'] == true) {
      // Establecer el correo recibido en el campo de correo
      emailController.text = arguments['email'];
      googleToken = arguments['googleToken'] ?? '';
      print('Enviando datos a la API: $googleToken');
      // Deshabilitar los campos de usuario y contraseña
      usernameController.text = ''; // Limpiar el campo de usuario
      passwordController.text = ''; // Limpiar el campo de contraseña
      confirmPasswordController.text = ''; // Limpiar el campo de confirmación
      _isGoogleLogin = true; // <--- AQUÍ
    }
  }
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();  // Cierra el dialogo
              },
            ),
          ],
        );
      },
    );
  }

  bool isLoading = false;

  Future<void> _register() async {
    if (!_acceptedTerms) {
      _showError('Debe aceptar los términos y condiciones');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    setState(() => isLoading = true);

    final data = {
      'nombre': nameController.text.trim(),
      'apellido': lastNameController.text.trim(),
      'telefono': phoneController.text.trim(),
      'direccion': addressController.text.trim(),
      'correo': emailController.text.trim(),
      if (!_isGoogleLogin) ...{
        'usuario': usernameController.text.trim(),
        'password': passwordController.text.trim(),
      } else ...{
        'usuario': '',
        'password': '',
        'google_token': googleToken
      }
    };

    // Log de los datos que estamos enviando
    print('Enviando datos a la API: $data');

    try {
      final response = await http.post(
        Uri.parse('https://alquilav.comhttps://alquilav.com/api/api.php?action=register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      // Imprimir la respuesta completa para depuración
      print('Respuesta completa: ${response.body}');
      print('Cabecera de la respuesta: ${response.headers}');
      print('Código de respuesta: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          print('Respuesta JSON: $responseData');

          if (responseData['status'] == 'ok') {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            _showErrorDialog(responseData['message']);
          }
        } catch (e) {
          _showError('Error al procesar la respuesta: $e');
        }
      } else {
        _showError('Error al registrar al usuario.');
      }
    } catch (e) {
      _showError('Error al registrar al usuario.');
      print('Error al enviar solicitud: $e');
    }
 finally {
      setState(() => isLoading = false);
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // NOMBRE
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // APELLIDO
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Apellido',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // TELEFONO
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // DIRECCION
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // EMAIL
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // USUARIO (Solo si no es registro de Google)
                if (!_isGoogleLogin) ...[
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!_isGoogleLogin) ...[
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!_isGoogleLogin) ...[
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],


                CheckboxListTile(
                  title: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Términos y Condiciones'),
                            content: SingleChildScrollView(child: Text(_termsText)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text(
                      'Acepto los términos y condiciones',
                      style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                    ),
                  ),
                  value: _acceptedTerms,
                  onChanged: (bool? value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
                ),

                // BUTTON REGISTER
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0090FF),
                      foregroundColor: Colors.white, // <-- Letras blancas
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Registrarse', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
