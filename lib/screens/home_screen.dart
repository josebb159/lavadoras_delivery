import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../models/lavadora_model.dart';
import 'login_screen.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../providers/solicitudes_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _locationTimer;
  Timer? _banCheckTimer;
  double _valorMinimo = 0;
  bool _showLowBalanceWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startLocationUpdates();
    _startSolicitudesPolling();
    _startBanCheckPolling();
    _checkMinimumBalance();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _banCheckTimer?.cancel();
    Provider.of<SolicitudesProvider>(context, listen: false).stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    if (authProvider.user != null) {
      homeProvider.loadData(authProvider.user!.id);
    }
  }

  void _startSolicitudesPolling() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final solicitudesProvider = Provider.of<SolicitudesProvider>(
      context,
      listen: false,
    );

    if (authProvider.user != null) {
      solicitudesProvider.startPolling(authProvider.user!.id);
    }
  }

  // Public method for notification handling to call
  void update_system(String userId) {
    Provider.of<HomeProvider>(context, listen: false).loadData(userId);
  }

  void _logout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _onRefresh() async {
    _loadData();
    await _checkMinimumBalance();
  }

  void _startLocationUpdates() {
    // Send immediately
    _sendLocation();
    // Then every 3 minutes
    _locationTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _sendLocation();
    });
  }

  Future<void> _sendLocation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final data = {
        'id_usuario': user.id,
        'latitud': position.latitude,
        'longitud': position.longitude,
      };

      print('📍 Enviando ubicación: $data');
      print('📍 Enviando ubicación: $data');
      final response = await ApiService().post(
        'update_ubicacion_domiciliario',
        data,
      );

      if (response['status'] == 'ok') {
        print('✅ Ubicación actualizada correctamente');
      } else {
        print('⚠️ Error actualizando ubicación: ${response['message']}');
      }
    } catch (e) {
      print('Error enviando ubicación: $e');
    }
  }

  void _startBanCheckPolling() {
    // Check immediately
    _checkBanStatus();
    // Then every 5 minutes
    _banCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkBanStatus();
    });
  }

  Future<void> _checkBanStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      final userId = int.tryParse(user.id) ?? 0;
      if (userId == 0) return;

      final response = await ApiService().checkUserBanStatus(userId);

      if (response['status'] == 'ok') {
        final isBanned = response['banned'] == true || response['banned'] == 1;

        if (isBanned) {
          print('⚠️ Usuario bloqueado detectado, redirigiendo...');
          // Cancel timers before navigation
          _locationTimer?.cancel();
          _banCheckTimer?.cancel();

          // Navigate to blocked user screen
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/usuario_bloqueado');
          }
        }
      }
    } catch (e) {
      print('Error verificando estado de bloqueo: $e');
    }
  }

  Future<void> _checkMinimumBalance() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      // Get minimum value from config
      final configResponse = await ApiService().getValorMinimo();

      print('🔍 DEBUG - Respuesta del API get_valor_minimo:');
      print('   Status: ${configResponse['status']}');
      print('   valor_minimo (raw): ${configResponse['valor_minimo']}');
      print(
        '   valor_minimo (type): ${configResponse['valor_minimo'].runtimeType}',
      );

      if (configResponse['status'] == 'ok') {
        _valorMinimo =
            double.tryParse(
              configResponse['valor_minimo']?.toString() ?? '0',
            ) ??
            0;

        // Get current balance
        final valorRecaudadoString = homeProvider.valorRecaudado;
        final valorRecaudado = double.tryParse(valorRecaudadoString) ?? 0;

        print('🔍 DEBUG - Valores de comparación:');
        print('   valorRecaudado (string): "$valorRecaudadoString"');
        print('   valorRecaudado (double): $valorRecaudado');
        print('   valorRecaudado (type): ${valorRecaudado.runtimeType}');
        print('   _valorMinimo (double): $_valorMinimo');
        print('   _valorMinimo (type): ${_valorMinimo.runtimeType}');
        print(
          '   Comparación (valorRecaudado < _valorMinimo): ${valorRecaudado < _valorMinimo}',
        );
        print('   Diferencia: ${valorRecaudado - _valorMinimo}');

        // Check if balance is below minimum
        setState(() {
          _showLowBalanceWarning = valorRecaudado < _valorMinimo;
        });

        if (_showLowBalanceWarning) {
          print('⚠️ Saldo insuficiente: \$$valorRecaudado < \$$_valorMinimo');
        } else {
          print('✅ Saldo suficiente: \$$valorRecaudado >= \$$_valorMinimo');
        }
      }
    } catch (e) {
      print('Error verificando saldo mínimo: $e');
    }
  }

  Widget _buildDrawer(AuthProvider authProvider) {
    final user = authProvider.user;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),
            accountName: Text(
              user?.nombre ?? 'Usuario',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.miscellaneous_services,
            title: 'Mis Servicios',
            route: '/mis_servicios',
          ),
          _buildDrawerItem(
            icon: Icons.payment,
            title: 'Pagos PayU',
            route: '/pagosyu',
          ),
          _buildDrawerItem(
            icon: Icons.attach_money,
            title: 'Pagos',
            route: '/pagos',
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_wallet,
            title: 'Recargar',
            route: '/recarga',
          ),
          _buildDrawerItem(
            icon: Icons.local_laundry_service,
            title: 'Lavadoras',
            route: '/lavadora',
          ),
          _buildDrawerItem(
            icon: Icons.person,
            title: 'Mi Cuenta',
            route: '/mi_cuenta',
          ),
          _buildDrawerItem(
            icon: Icons.support_agent,
            title: 'Soporte',
            route: '/soporte',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Salir', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _buildBanner(String? bannerUrl) {
    if (bannerUrl == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          bannerUrl,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String valorRecaudado) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valor Recaudado',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$$valorRecaudado',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLavadoraCard(Lavadora lavadora) {
    final bool isDisponible = lavadora.isDisponible;
    final bool isAlquilada = lavadora.isAlquilada;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),

                // Title and Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lavadora.codigo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0090FF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lavadora.descripcion,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDisponible ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDisponible
                              ? Colors.green[300]!
                              : Colors.orange[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    lavadora.estado.toUpperCase(),
                    style: TextStyle(
                      color:
                          isDisponible ? Colors.green[800] : Colors.orange[800],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Client Info (if rented)
          if (isAlquilada && lavadora.clienteActual != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Cliente: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      lavadora.clienteActual!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Pricing Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Tarifas de Servicio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pricing Grid
                Row(
                  children: [
                    // Normal Price
                    Expanded(
                      child: _buildPriceItem(
                        'Normal',
                        lavadora.precioNormal,
                        Icons.wb_sunny_outlined,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 24 Hours Price
                    Expanded(
                      child: _buildPriceItem(
                        '24 Horas',
                        lavadora.precio24Horas,
                        Icons.access_time,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nocturnal Price
                    Expanded(
                      child: _buildPriceItem(
                        'Nocturno',
                        lavadora.precioNocturno,
                        Icons.nightlight_round,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem(
    String label,
    double price,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '\$${price.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_laundry_service_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay lavadoras asignadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Actualmente no tienes lavadoras asignadas',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Lavadoras'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<SolicitudesProvider>(
            builder: (context, solicitudesProvider, child) {
              final count = solicitudesProvider.pendingCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed:
                        () => Navigator.pushNamed(context, '/solicitudes'),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(authProvider),
      body: Consumer<HomeProvider>(
        builder: (context, homeProvider, child) {
          if (homeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              children: [
                _buildBanner(homeProvider.bannerUrl),

                // Low Balance Warning Banner
                if (_showLowBalanceWarning)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[700]!, Colors.orange[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '⚠️ Saldo Insuficiente',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Necesitas al menos \$${_valorMinimo.toStringAsFixed(0)} para aceptar servicios',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                () => Navigator.pushNamed(context, '/recarga'),
                            icon: const Icon(Icons.account_balance_wallet),
                            label: const Text('Recargar Ahora'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.orange[700],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildBalanceCard(homeProvider.valorRecaudado),
                const SizedBox(height: 8),
                if (homeProvider.lavadoras.isEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _buildEmptyState(),
                  )
                else
                  ...homeProvider.lavadoras
                      .map((lavadora) => _buildLavadoraCard(lavadora))
                      .toList(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<SolicitudesProvider>(
        builder: (context, solicitudesProvider, child) {
          final count = solicitudesProvider.pendingCount;
          if (count == 0) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/solicitudes'),
            backgroundColor: const Color(0xFF0090FF),
            icon: const Icon(Icons.local_shipping),
            label: Text('$count ${count == 1 ? "Solicitud" : "Solicitudes"}'),
          );
        },
      ),
    );
  }
}
