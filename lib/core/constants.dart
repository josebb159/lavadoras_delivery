class AppConstants {
  static const String mainDomain = 'https://alquilav.com';
  // Base URL
  static const String baseUrl = '$mainDomain/api/api.php';

  // API Actions - Authentication
  static const String actionLogin = 'login';
  static const String actionLoginGoogle = 'login_google';
  static const String actionRegister = 'register';
  static const String actionSaveFcm = 'save_fcm';

  // API Actions - Data
  static const String actionGetBanner = 'get_banner';
  static const String actionLavadorasAsignadas = 'lavadoras_asignadas';
  static const String actionRecaudado = 'recaudado';

  // API Actions - Services
  static const String actionServicioPendiente = 'servicio_pendiente';
  static const String actionPendienteRecoger = 'pendiente_recoger';
  static const String actionCheckCancelacion = 'check_cancelacion_permitida';

  // API Actions - Location
  static const String actionUpdateUbicacion = 'update_ubicacion_domiciliario';

  // API Actions - Terms
  static const String actionTerminos = 'terminos_delivery';

  // API Actions - Delivery Confirmation
  static const String actionConfirmarEntrega = 'confirmar_entrega_lavadora';

  // Validation Constants
  static const int minPasswordLength = 8;
  static const int minPasswordLengthSimple = 6;
  static const int minNameLength = 2;
  static const int phoneLength = 10;
  static const int maxNameLength = 100;
  static const int maxAddressLength = 255;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration locationUpdateInterval = Duration(seconds: 10);
}
