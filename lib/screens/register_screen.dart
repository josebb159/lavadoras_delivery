import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/validators.dart';
import '../core/constants.dart';

class RegisterScreen extends StatefulWidget {
  final bool isGoogleLogin;

  const RegisterScreen({Key? key, this.isGoogleLogin = false})
    : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isGoogleLogin = false;
  String googleToken = '';
  bool _acceptedTerms = false;
  String _termsText = '';
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  @override
  void dispose() {
    nameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadTerms() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}?action=${AppConstants.actionTerminos}',
        ),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'ok') {
          final terminosData = responseData['terminos'];
          setState(() {
            _termsText =
                '${terminosData['terminos_delivery']}\n\n${terminosData['terminos_uso_delivery']}';
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
      emailController.text = arguments['email'];
      googleToken = arguments['googleToken'] ?? '';
      usernameController.text = '';
      passwordController.text = '';
      confirmPasswordController.text = '';
      _isGoogleLogin = true;
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
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _register() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedTerms) {
      _showError('Debe aceptar los términos y condiciones');
      return;
    }

    // Prevent double submission
    if (isLoading) return;

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
        'google_token': googleToken,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}?action=${AppConstants.actionRegister}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);

          if (responseData['status'] == 'ok') {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            _showErrorDialog(responseData['message'] ?? 'Error al registrar');
          }
        } catch (e) {
          _showError('Error al procesar la respuesta: $e');
        }
      } else {
        _showError('Error al registrar al usuario.');
      }
    } catch (e) {
      _showError('Error de conexión. Intenta nuevamente.');
      print('Error al enviar solicitud: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTermsDialog() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        backgroundColor: const Color(0xFF0090FF),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Nombre
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  validator:
                      (value) => FormValidators.validateMinLength(
                        value,
                        AppConstants.minNameLength,
                        'Nombre',
                      ),
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Apellido
                TextFormField(
                  controller: lastNameController,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  validator:
                      (value) => FormValidators.validateMinLength(
                        value,
                        AppConstants.minNameLength,
                        'Apellido',
                      ),
                  decoration: InputDecoration(
                    labelText: 'Apellido',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Teléfono
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  validator: FormValidators.validatePhone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    hintText: '3XX XXX XXXX',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Dirección
                TextFormField(
                  controller: addressController,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  validator:
                      (value) =>
                          FormValidators.validateRequired(value, 'Dirección'),
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading || _isGoogleLogin,
                  validator: FormValidators.validateEmail,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Usuario (Solo si no es Google Login)
                if (!_isGoogleLogin) ...[
                  TextFormField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                    validator:
                        (value) => FormValidators.validateMinLength(
                          value,
                          3,
                          'Usuario',
                        ),
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: const Icon(Icons.account_circle_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Contraseña (Solo si no es Google Login)
                if (!_isGoogleLogin) ...[
                  TextFormField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                    validator: FormValidators.validatePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      helperText: 'Mínimo 8 caracteres, 1 mayúscula, 1 número',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Confirmar Contraseña (Solo si no es Google Login)
                if (!_isGoogleLogin) ...[
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    validator:
                        (value) => FormValidators.validatePasswordConfirmation(
                          value,
                          passwordController.text,
                        ),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Términos y Condiciones Checkbox
                Card(
                  elevation: 0,
                  color: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _acceptedTerms ? Colors.blue : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: GestureDetector(
                      onTap: _showTermsDialog,
                      child: const Text(
                        'Acepto los términos y condiciones',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    value: _acceptedTerms,
                    onChanged:
                        isLoading
                            ? null
                            : (bool? value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                              });
                            },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 24),

                // Botón Registrar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (isLoading || !_acceptedTerms) ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0090FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Registrarse',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
