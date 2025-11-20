import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert' as convert; // para utf8.encode

class UsuarioBloqueadoScreen extends StatefulWidget {
  const UsuarioBloqueadoScreen({super.key});

  @override
  State<UsuarioBloqueadoScreen> createState() => _UsuarioBloqueadoScreenState();
}

class _UsuarioBloqueadoScreenState extends State<UsuarioBloqueadoScreen> {
  Map<String, dynamic>? configData;
  bool loading = true;
  String error = "";
  Map<String, dynamic> user = {};

  // Credenciales sandbox PayU Colombia
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
      final response = await http.post(
        Uri.parse('https://alquilav.com/api/api.php?action=get_config_general'),
      );

      final jsonData = json.decode(response.body);
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
    final String cadena = "$apiKey~$merchantId~$referenceCode~$amount~$currency";
    final bytes = convert.utf8.encode(cadena);
    final firma = md5.convert(bytes).toString();
    return firma;
  }

  /// Abrir enlace externo
  Future<void> _abrirEnlace(String url) async {
    print("[DEBUG] Intentando abrir enlace: $url");

    try {
      final uri = Uri.parse(url);
      print("[DEBUG] URI parseado correctamente: $uri");

      final canLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
      print("[DEBUG] Resultado de launchUrl: $canLaunch");

      if (!canLaunch) {
        print("[ERROR] No se pudo abrir el enlace: $url");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el enlace: $url')),
        );
      } else {
        print("[DEBUG] Enlace abierto con éxito");
      }
    } catch (e, stackTrace) {
      print("[EXCEPCIÓN] Ocurrió un error al abrir el enlace: $e");
      print("[STACKTRACE] $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el enlace')),
      );
    }
  }


  Widget _buildPaymentMethod(String title, dynamic enabled, dynamic cuenta, {VoidCallback? onTap}) {
    final isEnabled = enabled == 1 || enabled == '1';
    final account = cuenta?.toString() ?? 'No disponible';

    if (!isEnabled) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.payment, color: Colors.green),
      title: Text(title),
      subtitle: Text("Cuenta: $account"),
      trailing: onTap != null
          ? ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        child: const Text("Pagar", style: TextStyle(color: Colors.white)),
      )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Acceso Restringido")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(child: Text(error))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Has superado el límite de cancelaciones.",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Para continuar usando la app, debes pagar una multa o contactar soporte.",
            ),
            const SizedBox(height: 20),

            // Multa y métodos de pago
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Multa al cliente:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      "\$${configData?['multa_cliente']?.toString() ?? '0'} COP",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    const Text("Métodos de pago disponibles:",
                        style: TextStyle(fontWeight: FontWeight.bold)),

                    // PayU sandbox
                    _buildPaymentMethod(
                      "PayU (Sandbox)",
                      configData?['payu_habilitado'],
                      configData?['payu_cuenta'],
                      onTap: () async {
                        // 4️⃣ Cargar datos de usuario si es necesario
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        String? userData = prefs.getString('user');
                        if (userData != null) {
                          user = json.decode(userData);
                        }
                        final userid = user['id'];

                        // 1️⃣ Obtener multa desde config
                        final multa = configData?['multa_cliente']?.toString() ?? '0';

                        // 2️⃣ Crear referencia única
                        final referenceCode = "PayU-$userid-${DateTime.now().millisecondsSinceEpoch}";

                        // 3️⃣ Generar firma EXACTAMENTE igual que en PHP
                        String apiKey = configData?['payu_api_key'] ?? ''; // Tu API Key real de PayU
                        String merchantId = configData?['payu_merchant_id'] ?? '';
                        String currency = "COP";
                        String signatureRaw = "$apiKey~$merchantId~$referenceCode~$multa~$currency";

                        var bytes = utf8.encode(signatureRaw);
                        var digest = md5.convert(bytes);
                        String signature = digest.toString();


                        // 5️⃣ Obtener valores de configuración
                        final accountId = configData?['payu_account_id'] ?? '';
                        final checkoutUrl =  "https://pay.alquilav.com/pay.php?"; //configData?['payu_checkout_url'] ?? '';
                        final responseUrl = configData?['payu_response_url'] ?? '';
                        final confirmationUrl = configData?['payu_confirmation_url'] ?? '';
                        final emailPay = configData?['email_pay'] ?? '';

                        // 6️⃣ Construir URL PayU
                        final payuUrl = "$checkoutUrl"
                            "?merchantId=$merchantId"
                            "&accountId=$accountId"
                            "&description=Pago+de+Multa"
                            "&referenceCode=$referenceCode"
                            "&amount=$multa"
                            "&tax=0"
                            "&taxReturnBase=0"
                            "&currency=$currency"
                            "&signature=$signature"
                            "&test=1"
                            "&buyerEmail=$emailPay"
                            "&responseUrl=$responseUrl"
                            "&confirmationUrl=$confirmationUrl";

                        // 7️⃣ Abrir enlace
                        _abrirEnlace(payuUrl);
                      },
                    ),

                    // Otros métodos
                    _buildPaymentMethod("Bancolombia",
                        configData?['bancolombia_habilitado'], configData?['bancolombia_cuenta']),
                    _buildPaymentMethod("Nequi",
                        configData?['nequi_habilitado'], configData?['nequi_cuenta']),
                    _buildPaymentMethod("Daviplata",
                        configData?['daviplata_habilitado'], configData?['daviplata_cuenta']),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Soporte
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Soporte",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text("Correo"),
                      subtitle: Text(
                        configData?['correo_contacto']?.toString().trim().isNotEmpty == true
                            ? configData!['correo_contacto']
                            : 'N/A',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.chat),
                      title: const Text("WhatsApp"),
                      subtitle: Text(
                        configData?['whatsapp_contacto']?.toString().trim().isNotEmpty == true
                            ? configData!['whatsapp_contacto']
                            : 'N/A',
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
