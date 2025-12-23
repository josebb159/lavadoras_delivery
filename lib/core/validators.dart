/// Validadores de formularios reutilizables para toda la aplicación
class FormValidators {
  /// Valida que un campo no esté vacío
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  /// Valida formato de email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo electrónico es requerido';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Ingresa un correo electrónico válido';
    }

    return null;
  }

  /// Valida contraseña con requisitos de seguridad
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }

    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    // Al menos una mayúscula
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'La contraseña debe contener al menos una mayúscula';
    }

    // Al menos un número
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'La contraseña debe contener al menos un número';
    }

    return null;
  }

  /// Valida contraseña simple (para login, menos estricta)
  static String? validatePasswordSimple(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }

    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    return null;
  }

  /// Valida confirmación de contraseña
  static String? validatePasswordConfirmation(
    String? value,
    String originalPassword,
  ) {
    if (value == null || value.isEmpty) {
      return 'Debes confirmar tu contraseña';
    }

    if (value != originalPassword) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  /// Valida número de teléfono (formato colombiano: 10 dígitos)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es requerido';
    }

    // Remover espacios y caracteres especiales
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.length != 10) {
      return 'El teléfono debe tener 10 dígitos';
    }

    if (!cleanPhone.startsWith(RegExp(r'3[0-9]'))) {
      return 'Ingresa un número de celular válido';
    }

    return null;
  }

  /// Valida longitud mínima
  static String? validateMinLength(
    String? value,
    int minLength,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }

    if (value.trim().length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }

    return null;
  }

  /// Valida longitud máxima
  static String? validateMaxLength(
    String? value,
    int maxLength,
    String fieldName,
  ) {
    if (value != null && value.trim().length > maxLength) {
      return '$fieldName no puede tener más de $maxLength caracteres';
    }

    return null;
  }

  /// Valida que sea un número válido
  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }

    if (double.tryParse(value.trim()) == null) {
      return '$fieldName debe ser un número válido';
    }

    return null;
  }

  /// Valida monto mínimo
  static String? validateMinAmount(
    String? value,
    double minAmount,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return '$fieldName debe ser un número válido';
    }

    if (amount < minAmount) {
      return '$fieldName debe ser al menos \$${minAmount.toStringAsFixed(0)}';
    }

    return null;
  }
}
