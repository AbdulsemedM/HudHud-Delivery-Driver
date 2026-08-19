import 'dart:io';

/// Vehicle types accepted by the registration API.
enum VehicleType {
  bicycle('bicycle', 'Bicycle'),
  motorcycle('motorcycle', 'Motorcycle'),
  car('car', 'Car');

  const VehicleType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VehicleType? fromApiValue(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase();
    if (normalized == 'motorbike') return VehicleType.motorcycle;
    for (final type in VehicleType.values) {
      if (type.apiValue == normalized) return type;
    }
    return null;
  }
}

/// Account fields collected on screen 1 before vehicle details are added.
class DriverAccountData {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;

  const DriverAccountData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
  });

  String get name => '$firstName $lastName'.trim();
}

/// Full driver registration payload for multipart submission.
class DriverRegistrationData {
  static const allowedPhotoExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const maxPhotoBytes = 5 * 1024 * 1024;
  static const minVehicleYear = 1990;

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;
  final VehicleType vehicleType;
  final File profilePicture;
  final String? driverLicenseNumber;
  final String? vehiclePlateNumber;
  final String vehicleMake;
  final String vehicleModel;
  final int? vehicleYear;
  final String vehicleColor;
  final List<String> serviceAreas;
  final String? deviceToken;

  const DriverRegistrationData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.vehicleType,
    required this.profilePicture,
    this.driverLicenseNumber,
    this.vehiclePlateNumber,
    required this.vehicleMake,
    required this.vehicleModel,
    this.vehicleYear,
    required this.vehicleColor,
    required this.serviceAreas,
    this.deviceToken,
  });

  factory DriverRegistrationData.fromAccount({
    required DriverAccountData account,
    required VehicleType vehicleType,
    required File profilePicture,
    String? driverLicenseNumber,
    String? vehiclePlateNumber,
    required String vehicleMake,
    required String vehicleModel,
    int? vehicleYear,
    required String vehicleColor,
    required List<String> serviceAreas,
    String? deviceToken,
  }) {
    return DriverRegistrationData(
      firstName: account.firstName,
      lastName: account.lastName,
      email: account.email,
      phone: account.phone,
      password: account.password,
      passwordConfirmation: account.passwordConfirmation,
      vehicleType: vehicleType,
      profilePicture: profilePicture,
      driverLicenseNumber: driverLicenseNumber,
      vehiclePlateNumber: vehiclePlateNumber,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleColor: vehicleColor,
      serviceAreas: serviceAreas,
      deviceToken: deviceToken,
    );
  }

  String get name => '$firstName $lastName'.trim();

  bool get isMotorVehicle => vehicleType != VehicleType.bicycle;

  static int get maxVehicleYear => DateTime.now().year + 1;

  static List<String> serviceAreasFromInput(String input) {
    final seen = <String>{};
    final areas = <String>[];
    for (final part in input.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) areas.add(trimmed);
    }
    return areas;
  }

  static String? photoValidationError(File file) {
    final name = file.path.split(RegExp(r'[\\/]')).last.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    if (!allowedPhotoExtensions.contains(ext)) {
      return 'Supported formats are JPG, JPEG, PNG and WebP.';
    }
    final size = file.lengthSync();
    if (size > maxPhotoBytes) {
      return 'Photo size must not exceed 5 MB.';
    }
    return null;
  }

  /// Client-side validation keyed by form field names.
  Map<String, String> validate() {
    final errors = <String, String>{};

    if (firstName.trim().isEmpty) {
      errors['first_name'] = 'First name is required.';
    }
    if (lastName.trim().isEmpty) {
      errors['last_name'] = 'Last name is required.';
    }
    if (name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 2) {
      errors['name'] = 'Please enter your first and last name.';
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty ||
        !normalizedEmail.contains('@') ||
        !normalizedEmail.contains('.')) {
      errors['email'] = 'Please enter a valid email address.';
    }

    if (phone.trim().isEmpty) {
      errors['phone'] = 'Phone number is required.';
    }

    if (password.length < 6) {
      errors['password'] = 'Password must be at least 6 characters.';
    }
    if (passwordConfirmation != password) {
      errors['password_confirmation'] = 'Passwords do not match.';
    }

    final photoError = photoValidationError(profilePicture);
    if (photoError != null) {
      errors['profile_picture'] = photoError;
    }

    if (isMotorVehicle) {
      if ((driverLicenseNumber ?? '').trim().isEmpty) {
        errors['driver_license_number'] =
            'Driver license number is required.';
      }
      if ((vehiclePlateNumber ?? '').trim().isEmpty) {
        errors['vehicle_plate_number'] = 'Vehicle plate number is required.';
      }
      if (vehicleYear == null) {
        errors['vehicle_year'] = 'Please enter a valid vehicle year.';
      }
    }

    if (vehicleMake.trim().isEmpty) {
      errors['vehicle_make'] = 'Make is required.';
    }
    if (vehicleModel.trim().isEmpty) {
      errors['vehicle_model'] = 'Model is required.';
    }

    if (vehicleYear != null &&
        (vehicleYear! < minVehicleYear || vehicleYear! > maxVehicleYear)) {
      errors['vehicle_year'] = 'Please enter a valid vehicle year.';
    }

    if (vehicleColor.trim().isEmpty) {
      errors['vehicle_color'] = 'Color is required.';
    }

    if (serviceAreas.isEmpty) {
      errors['service_areas'] = 'Please enter at least one service area.';
    }

    return errors;
  }

  /// Multipart text fields; omits bicycle-only-skipped and empty values.
  Map<String, String> toMultipartFields() {
    final fields = <String, String>{
      'name': name,
      'email': email.trim().toLowerCase(),
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'vehicle_type': vehicleType.apiValue,
      'vehicle_make': vehicleMake.trim(),
      'vehicle_model': vehicleModel.trim(),
      'vehicle_color': vehicleColor.trim(),
    };

    if (vehicleYear != null) {
      fields['vehicle_year'] = vehicleYear.toString();
    }

    if (isMotorVehicle) {
      fields['driver_license_number'] = driverLicenseNumber!.trim();
      fields['vehicle_plate_number'] = vehiclePlateNumber!.trim();
    }

    for (var i = 0; i < serviceAreas.length; i++) {
      fields['service_areas[$i]'] = serviceAreas[i].trim();
    }

    final token = deviceToken?.trim();
    if (token != null && token.isNotEmpty) {
      fields['device_token'] = token;
    }

    return fields;
  }
}

/// Structured result from driver registration API.
class DriverRegistrationResult {
  final bool success;
  final int? statusCode;
  final String? message;
  final dynamic data;
  final Map<String, String> fieldErrors;
  final bool rateLimited;
  final bool unavailable;

  const DriverRegistrationResult({
    required this.success,
    this.statusCode,
    this.message,
    this.data,
    this.fieldErrors = const {},
    this.rateLimited = false,
    this.unavailable = false,
  });

  factory DriverRegistrationResult.success({
    required dynamic data,
    String? message,
  }) {
    return DriverRegistrationResult(
      success: true,
      statusCode: 201,
      data: data,
      message: message,
    );
  }

  factory DriverRegistrationResult.validationErrors({
    required Map<String, String> fieldErrors,
    String? message,
  }) {
    return DriverRegistrationResult(
      success: false,
      statusCode: 422,
      fieldErrors: fieldErrors,
      message: message ?? 'Validation failed.',
    );
  }

  factory DriverRegistrationResult.rateLimited({String? message}) {
    return DriverRegistrationResult(
      success: false,
      statusCode: 429,
      rateLimited: true,
      message: message ??
          'Too many registration attempts. Please wait a moment and try again.',
    );
  }

  factory DriverRegistrationResult.unavailable({String? message}) {
    return DriverRegistrationResult(
      success: false,
      statusCode: 503,
      unavailable: true,
      message: message ??
          'Driver registration is temporarily unavailable. Please try again.',
    );
  }

  factory DriverRegistrationResult.failure({
    int? statusCode,
    String? message,
  }) {
    return DriverRegistrationResult(
      success: false,
      statusCode: statusCode,
      message: message ?? 'Registration failed.',
    );
  }

  static Map<String, String> parseFieldErrors(dynamic responseData) {
    if (responseData is! Map) return {};
    final raw = responseData['errors'];
    if (raw is! Map) return {};

    final parsed = <String, String>{};
    raw.forEach((key, value) {
      final field = key.toString();
      if (value is List && value.isNotEmpty) {
        parsed[field] = value.first.toString();
      } else if (value != null) {
        parsed[field] = value.toString();
      }
    });
    return parsed;
  }
}
