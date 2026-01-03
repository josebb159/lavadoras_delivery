import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lavadora_app/services/api_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final int rentalId; // id_alquiler
  final int deliveryId; // id_domiciliario

  const ChatScreen({Key? key, required this.rentalId, required this.deliveryId})
    : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List chatMessages = [];
  TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? user;
  Timer? _pollingTimer;
  bool isLoading = false;
  int clientId = 0; // 🔹 ID del cliente (destinatario)

  @override
  void initState() {
    super.initState();
    clientId = widget.deliveryId; // Inicializar con el valor del widget
    _loadUser();
    getChatMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Cargar usuario guardado en SharedPreferences
  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      setState(() {
        user = json.decode(userData);
      });

      // 🔹 Si no tenemos el ID del cliente (ej. notificación), lo buscamos
      if (clientId == 0) {
        _fetchRentalInfo();
      }
    }
  }

  // Obtener info del alquiler para saber el ID del cliente
  Future<void> _fetchRentalInfo() async {
    try {
      final data = {'id_alquiler': widget.rentalId, 'user_id': user!['id']};
      final response = await ApiService().post('get_detail_service', data);
      if (response['status'] == 'ok') {
        final servicio = response['servicio'];
        setState(() {
          clientId = int.tryParse(servicio['user_id'].toString()) ?? 0;
        });
        print("✅ Cliente ID recuperado: $clientId");
      }
    } catch (e) {
      print("❌ Error recuperando info del alquiler: $e");
    }
  }

  // Iniciar polling cada 3 segundos
  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      getChatMessages();
    });
  }

  // Obtener mensajes desde API
  Future<void> getChatMessages() async {
    setState(() {
      isLoading = true; // 🔹 Activa la pantalla de carga
    });

    try {
      final jsonData = await ApiService().post('get_chat_messages', {
        'id_alquiler': widget.rentalId,
      });

      if (jsonData['status'] == 'ok') {
        final mensajes =
            jsonData['mensajes'] ?? []; // 👈 usar la clave correcta

        print("✅ Mensajes recibidos: ${mensajes.length}");

        setState(() {
          chatMessages = mensajes;
        });

        // Marcar mensajes como leídos
        ApiService().markChatRead(widget.rentalId, 'domiciliario');
      } else {
        print("⚠️ Respuesta de API con error: ${jsonData['status']}");
      }
    } catch (e, stacktrace) {
      print("💥 Error cargando mensajes: $e");
      print("🧵 Stacktrace: $stacktrace");
    } finally {
      setState(() {
        isLoading = false; // 🔹 Desactiva la pantalla de carga
      });
    }
  }

  // Enviar mensaje
  Future<void> sendChatMessage(String mensaje) async {
    if (user == null || mensaje.trim().isEmpty) {
      print("⚠️ Usuario no definido o mensaje vacío.");
      return;
    }

    try {
      final payload = {
        'id_alquiler': widget.rentalId,
        'id_usuario': clientId, // 🔹 Usar clientId dinámico
        'id_domiciliario': user!['id'],
        'mensaje': mensaje,
        'tipo': 'domiciliario', // siempre usuario desde la app cliente
      };

      final jsonData = await ApiService().post('send_chat_message', payload);

      if (jsonData['status'] == 'ok') {
        print("✅ Mensaje enviado correctamente.");
        _messageController.clear();
        getChatMessages(); // refrescar mensajes
      } else {
        print("⚠️ Error en respuesta API: ${jsonData['status']}");
      }
    } catch (e, stacktrace) {
      print("💥 Error enviando mensaje: $e");
      print("🧵 Stacktrace: $stacktrace");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat con el Cliente"),
        backgroundColor: Colors.blue,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      reverse: false,
                      itemCount: chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = chatMessages[index];
                        final isUser = msg['remitente'] == 'domiciliario';
                        return Align(
                          alignment:
                              isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.all(10),
                            margin: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isUser ? Colors.blue[200] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['mensaje'],
                                  style: TextStyle(fontSize: 16),
                                ),
                                if (isUser) ...[
                                  SizedBox(height: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color:
                                        (int.tryParse(
                                                      msg['leido'].toString(),
                                                    ) ??
                                                    0) ==
                                                1
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(height: 1),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: "Escribe un mensaje...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.blue),
                          onPressed:
                              () => sendChatMessage(_messageController.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
