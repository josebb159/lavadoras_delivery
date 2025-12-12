import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../models/lavadora_model.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
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

  // Public method for notification handling to call
  void update_system(String userId) {
    Provider.of<HomeProvider>(context, listen: false).loadData(userId);
  }

  void _logout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildDrawer(AuthProvider authProvider) {
    final user = authProvider.user;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.nombre ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.miscellaneous_services),
            title: const Text('Mis Servicios'),
            onTap: () => Navigator.pushNamed(context, '/mis_servicios'),
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Pagos PayU'),
            onTap: () => Navigator.pushNamed(context, '/pagosyu'),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Pagos'),
            onTap: () => Navigator.pushNamed(context, '/pagos'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Recargar'),
            onTap: () => Navigator.pushNamed(context, '/recarga'),
          ),
          ListTile(
            leading: const Icon(Icons.local_laundry_service),
            title: const Text('Lavadoras'),
            onTap: () => Navigator.pushNamed(context, '/lavadora'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Mi Cuenta'),
            onTap: () => Navigator.pushNamed(context, '/mi_cuenta'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Salir'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Listado de Lavadoras')),
      drawer: _buildDrawer(authProvider),
      body: Consumer<HomeProvider>(
        builder: (context, homeProvider, child) {
          if (homeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (homeProvider.bannerUrl != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Image.network(
                    homeProvider.bannerUrl!,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.broken_image,
                          size: 100,
                          color: Colors.grey,
                        ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Valor recaudado:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\$${homeProvider.valorRecaudado}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount:
                      homeProvider.lavadoras.isEmpty
                          ? 1
                          : homeProvider.lavadoras.length,
                  itemBuilder: (context, index) {
                    if (homeProvider.lavadoras.isEmpty) {
                      return const Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text('No hay lavadoras asignadas'),
                          subtitle: Text(
                            'Actualmente no tienes lavadoras asignadas',
                          ),
                          tileColor: Colors.grey,
                          leading: Icon(Icons.info, color: Colors.grey),
                        ),
                      );
                    }

                    final lavadora = homeProvider.lavadoras[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text('Lavadora ${lavadora.codigo}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Descripción: ${lavadora.descripcion}'),
                            Text('Codigo: ${lavadora.codigo}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('\$${lavadora.precio}'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    lavadora.estado == 'disponible'
                                        ? Colors.green[100]
                                        : Colors.orange[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                lavadora.estado,
                                style: TextStyle(
                                  color:
                                      lavadora.estado == 'alquilada'
                                          ? Colors.green[800]
                                          : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        leading: const Icon(
                          Icons.local_laundry_service,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
