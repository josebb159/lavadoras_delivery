import 'package:flutter/material.dart';
import 'package:lavadora_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert' as convert; // para utf8.encode

class RecargaScreen extends StatefulWidget {
  const RecargaScreen({super.key});

  @override
  State<RecargaScreen> createState() => _RecargaScreenState();
}

class _RecargaScreenState extends State<RecargaScreen> {
  Map<String, dynamic>? configData;
  bool loading = true;
  String error = "";
  Map<String, dynamic> user = {};
  final TextEditingController _montoController = TextEditingController();

  // Credenciales sandbox PayU Colombia (ejemplo)
  final String apiKey = "4Vj8eK4rloUd272L48hsrarnUA";
  final String merchantId = "508029";
  final String accountId = "512321";
  final String currency = "COP";

  @override
  void initState() {
    super.initState();
    fetchConfig();
  }

  Future<void> fetchConfig() async {
    try {
      final jsonData = await ApiService().post('get_config_general', {});
      if (jsonData['status'] == 'ok') {
        setState(() {
          configData = jsonData['config'];
          loading = false;
        });
      } else {
        setState(() {
          error = "No se pudo obtener la configuración.";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error de red: $e";
        loading = false;
      });
    }
  }

  /// Generar firma MD5 para PayU
  String generarFirma(String referenceCode, String amount) {
    final String cadena =
        "$apiKey~$merchantId~$referenceCode~$amount~$currency";
    final bytes = convert.utf8.encode(cadena);
    final firma = md5.convert(bytes).toString();
    return firma;
  }

  /// Abrir enlace externo
  Future<void> _abrirEnlace(String url) async {
    try {
      final uri = Uri.parse(url);
      final canLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!canLaunch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el enlace: $url')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al abrir el enlace')));
    }
  }

  void _iniciarRecarga() async {
    final montoIngresado = int.tryParse(_montoController.text.trim()) ?? 0;

    if (montoIngresado < 30000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El valor mínimo de recarga es 30,000 COP'),
        ),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      user = json.decode(userData);
    }
    final userid = user['id'] ?? '0';

    // 1️⃣ Crear referencia única
    final referenceCode =
        "Recarga-$userid-${DateTime.now().millisecondsSinceEpoch}";

    // 2️⃣ Generar firma
    String signature = generarFirma(referenceCode, montoIngresado.toString());

    // 3️⃣ Obtener valores de configuración
    final checkoutUrl = "https://pay.alquilav.com/regarga.php?";
    final responseUrl = configData?['payu_response_url'] ?? '';
    final confirmationUrl = configData?['payu_confirmation_url'] ?? '';
    final emailPay = configData?['email_pay'] ?? '';

    // 4️⃣ Construir URL PayU
    final payuUrl =
        "$checkoutUrl"
        "?merchantId=$merchantId"
        "&accountId=$accountId"
        "&description=Recarga+de+Saldo"
        "&referenceCode=$referenceCode"
        "&amount=$montoIngresado"
        "&tax=0"
        "&taxReturnBase=0"
        "&currency=$currency"
        "&signature=$signature"
        "&test=0"
        "&buyerEmail=$emailPay"
        "&responseUrl=$responseUrl"
        "&confirmationUrl=$confirmationUrl";

    _abrirEnlace(payuUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recargar Saldo")),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
              ? Center(child: Text(error))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recarga tu saldo",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _montoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Monto a recargar (mínimo 30,000 COP)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Método de pago disponible:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            ListTile(
                              leading: const Icon(
                                Icons.payment,
                                color: Colors.green,
                              ),
                              title: const Text("PayU (Sandbox)"),
                              subtitle: Text(
                                "Cuenta: ${configData?['payu_cuenta'] ?? 'N/A'}",
                              ),
                              trailing: ElevatedButton(
                                onPressed: _iniciarRecarga,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text(
                                  "Recargar",
                                  style: TextStyle(color: Colors.white),
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
}
