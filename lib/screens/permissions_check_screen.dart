import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PermissionsCheckScreen extends StatefulWidget {
  const PermissionsCheckScreen({Key? key}) : super(key: key);

  @override
  State<PermissionsCheckScreen> createState() => _PermissionsCheckScreenState();
}

class _PermissionsCheckScreenState extends State<PermissionsCheckScreen> {
  bool _isCheckingPermissions = false;
  bool _locationGranted = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isCheckingPermissions = true;
    });

    // Check location permission
    final locationStatus = await Permission.location.status;
    _locationGranted = locationStatus.isGranted;

    // Check notification permission
    final notificationSettings =
        await FirebaseMessaging.instance.getNotificationSettings();
    _notificationGranted =
        notificationSettings.authorizationStatus ==
        AuthorizationStatus.authorized;

    setState(() {
      _isCheckingPermissions = false;
    });

    // If both permissions are granted, navigate to home
    if (_locationGranted && _notificationGranted) {
      _navigateToHome();
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    setState(() {
      _locationGranted = status.isGranted;
    });

    if (_locationGranted && _notificationGranted) {
      _navigateToHome();
    }
  }

  Future<void> _requestNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    setState(() {
      _notificationGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
    });

    if (_locationGranted && _notificationGranted) {
      _navigateToHome();
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    // Re-check permissions after user returns from settings
    Future.delayed(const Duration(seconds: 1), () {
      _checkPermissions();
    });
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child:
              _isCheckingPermissions
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Icon/Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.security,
                            size: 80,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        const Text(
                          'Permisos Necesarios',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          'Para brindarte el mejor servicio, necesitamos que actives los siguientes permisos:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Location Permission Card
                        _buildPermissionCard(
                          icon: Icons.location_on,
                          title: 'Ubicación',
                          description:
                              'Necesaria para rastrear entregas y optimizar rutas',
                          isGranted: _locationGranted,
                          onTap: _requestLocationPermission,
                        ),
                        const SizedBox(height: 16),

                        // Notification Permission Card
                        _buildPermissionCard(
                          icon: Icons.notifications,
                          title: 'Notificaciones',
                          description:
                              'Para recibir actualizaciones de servicios en tiempo real',
                          isGranted: _notificationGranted,
                          onTap: _requestNotificationPermission,
                        ),
                        const SizedBox(height: 40),

                        // Continue Button (only if both granted)
                        if (_locationGranted && _notificationGranted)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _navigateToHome,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Continuar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Settings Button (if permissions denied)
                        if (!_locationGranted || !_notificationGranted)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _openAppSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.settings),
                                      SizedBox(width: 8),
                                      Text(
                                        'Abrir Configuración',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Si los permisos fueron denegados, ábrelos desde la configuración del sistema',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isGranted ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isGranted
                            ? Colors.green.withOpacity(0.1)
                            : Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color:
                        isGranted
                            ? Colors.green
                            : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // Status Icon
                Icon(
                  isGranted ? Icons.check_circle : Icons.cancel,
                  color: isGranted ? Colors.green : Colors.grey[400],
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
