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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startLocationUpdates();
    _startSolicitudesPolling();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_laundry_service,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),

            // Middle Content (Title + Details)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lavadora ${lavadora.codigo}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lavadora.descripcion,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Código: ${lavadora.codigo}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  // Show client if rented
                  if (isAlquilada && lavadora.clienteActual != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Cliente: ${lavadora.clienteActual}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Trailing Content (Price + Status)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${lavadora.precio}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
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
                      width: 1,
                    ),
                  ),
                  child: Text(
                    lavadora.estado,
                    style: TextStyle(
                      color:
                          isDisponible ? Colors.green[800] : Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
