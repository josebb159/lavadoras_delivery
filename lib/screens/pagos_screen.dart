import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lavadora_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen() : super();

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  List<dynamic> pagos = [];
  Map<String, dynamic> user = {};
  bool isLoading = true;

  Future<void> getPagos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      user = json.decode(userData);
    }

    try {
      print("📡 Consultando pagos del usuario ${user['id']}");

      final jsonData = await ApiService().post('get_pagos_realizados', {
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
      print("💥 Error cargando pagos: $e");
      print("🧵 Stacktrace: $stacktrace");
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    getPagos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pagos Realizados")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : pagos.isEmpty
              ? const Center(child: Text("No tienes pagos registrados"))
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
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.blue,
                      ),
                      title: Text("Referencia: ${pago['referencia']}"),
                      subtitle: Text(
                        "💲 Valor: \$${pago['valor']}\n"
                        "📌 Método: ${pago['metodo_pago']}\n"
                        "📅 Fecha: ${pago['fecha']}\n",
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}
