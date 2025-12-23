import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lavadora_app/services/api_service.dart';

class PagosPayUScreen extends StatefulWidget {
  const PagosPayUScreen() : super();

  @override
  State<PagosPayUScreen> createState() => _PagosPayUScreenState();
}

class _PagosPayUScreenState extends State<PagosPayUScreen> {
  List<dynamic> pagos = [];
  bool isLoading = true;
  Map<String, dynamic> user = {};
  Future<void> getPagosPayU() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      user = json.decode(userData);
    }
    try {
      print("📡 Consultando pagos PayU del usuario ${user['id']}");

      final jsonData = await ApiService().post('get_pagos_payu', {
        'id_usuario': user['id'],
      });

      if (jsonData['status'] == 'ok') {
        setState(() {
          pagos = jsonData['pagos'] ?? [];
          isLoading = false;
        });
      } else {
        print("⚠️ Error de API: ${jsonData['message']}");
        setState(() => isLoading = false);
      }
    } catch (e, stacktrace) {
      print("💥 Error cargando pagos PayU: $e");
      print("🧵 Stacktrace: $stacktrace");
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    getPagosPayU();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pagos PayU")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : pagos.isEmpty
              ? const Center(child: Text("No tienes pagos registrados en PayU"))
              : ListView.builder(
                itemCount: pagos.length,
                itemBuilder: (context, index) {
                  final pago = pagos[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.payment, color: Colors.green),
                      title: Text("Referencia: ${pago['reference_code']}"),
                      subtitle: Text(
                        "💲 Valor: ${pago['amount']} ${pago['currency']}\n"
                        "📌 Estado: ${pago['estado']}\n"
                        "🔑 Transacción: ${pago['transaction_id'] ?? 'N/A'}\n"
                        "💳 Método: ${pago['metodo_pago'] ?? 'N/A'}\n"
                        "📅 Fecha: ${pago['fecha_pago']}",
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}
