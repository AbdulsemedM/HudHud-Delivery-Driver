import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../constants/application_status.dart';
import 'secure_storage_service.dart';

/// Typed failure from the rider application endpoints.
class DriverApplicationException implements Exception {
  DriverApplicationException(
    this.message, {
    this.code,
    this.statusCode,
    this.fieldErrors = const <String, List<String>>{},
  });

  final String message;
  final String? code;
  final int? statusCode;

  /// Laravel's 422 `errors` map, so the form can mark the offending fields
  /// instead of showing one generic message at the top.
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => message;
}

/// What the rider still has to provide, and the values already on file.
class DriverApplication {
  const DriverApplication({
    required this.state,
    required this.missing,
    required this.vehicleTypes,
    required this.motorVehicleTypes,
    this.name,
    this.vehicleType,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleYear,
    this.vehiclePlateNumber,
    this.driverLicenseNumber,
    this.serviceAreas = const <String>[],
    this.hasProfilePicture = false,
    this.statusReason,
  });

  /// One of [ApplicationStatus]'s values, already normalised.
  final String state;

  /// API field names still required, e.g. `vehicle_type`, `profile_picture`.
  final List<String> missing;

  final List<String> vehicleTypes;

  /// The subset of [vehicleTypes] that must bring a licence, plate and year.
  final List<String> motorVehicleTypes;

  final String? name;
  final String? vehicleType;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final int? vehicleYear;
  final String? vehiclePlateNumber;
  final String? driverLicenseNumber;
  final List<String> serviceAreas;
  final bool hasProfilePicture;
  final String? statusReason;

  /// Falls back to "everything but a bicycle" when the server sends no list,
  /// rather than silently dropping the licence and plate for every vehicle.
  bool requiresMotorDocuments(String? type) {
    if (type == null) return false;
    if (motorVehicleTypes.isEmpty) return type != 'bicycle';
    return motorVehicleTypes.contains(type);
  }

  static List<String> _strings(dynamic raw) => raw is List
      ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : const <String>[];

  factory DriverApplication.fromJson(Map<String, dynamic> data) {
    final application =
        Map<String, dynamic>.from(data['application'] as Map? ?? const {});

    return DriverApplication(
      state: ApplicationStatus.fromDriverBlock(data) ??
          ApplicationStatus.onboardingRequired,
      missing: _strings(data['missing']),
      vehicleTypes: _strings(data['vehicle_types']),
      motorVehicleTypes: _strings(data['motor_vehicle_types']),
      name: application['name']?.toString(),
      vehicleType: application['vehicle_type']?.toString(),
      vehicleMake: application['vehicle_make']?.toString(),
      vehicleModel: application['vehicle_model']?.toString(),
      vehicleColor: application['vehicle_color']?.toString(),
      vehicleYear: int.tryParse(application['vehicle_year']?.toString() ?? ''),
      vehiclePlateNumber: application['vehicle_plate_number']?.toString(),
      driverLicenseNumber: application['driver_license_number']?.toString(),
      serviceAreas: _strings(application['service_areas']),
      hasProfilePicture: application['has_profile_picture'] == true,
      statusReason: data['status_reason']?.toString(),
    );
  }
}

/// The rider application that passwordless sign-in never asks for.
///
/// A rider who signs in with an SMS code gets an account created from the
/// phone number alone — pending, with no name, vehicle, licence or photo. This
/// is how the app collects those and puts the rider in front of a reviewer.
///
/// Uses `http` directly with a Bearer from secure storage, the same shape as
/// `ApiService`'s multipart uploads, because the submission carries a photo.
class DriverApplicationService {
  DriverApplicationService({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  final SecureStorageService _secureStorage;

  Future<Map<String, String>> _headers() async {
    final token = await _secureStorage.getToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// What to show, and whatever the rider already provided.
  Future<DriverApplication> fetch() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.driverApplicationUrl), headers: await _headers())
          .timeout(const Duration(seconds: 30));

      final body = _decode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return DriverApplication.fromJson(
          Map<String, dynamic>.from(body['data'] as Map? ?? const {}),
        );
      }

      throw DriverApplicationException(
        body['message']?.toString() ?? 'Could not load your application.',
        code: body['code']?.toString(),
        statusCode: response.statusCode,
      );
    } on DriverApplicationException {
      rethrow;
    } catch (_) {
      throw DriverApplicationException(
        'Could not reach HudHud. Check your connection and try again.',
        code: 'NETWORK',
      );
    }
  }

  /// Submit for review. Never approves — only an admin does that.
  Future<DriverApplication> submit({
    required String name,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required String vehicleColor,
    required List<String> serviceAreas,
    String? driverLicenseNumber,
    String? vehiclePlateNumber,
    int? vehicleYear,
    File? profilePicture,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.driverApplicationUrl),
      );
      request.headers.addAll(await _headers());

      request.fields['name'] = name;
      request.fields['vehicle_type'] = vehicleType;
      request.fields['vehicle_make'] = vehicleMake;
      request.fields['vehicle_model'] = vehicleModel;
      request.fields['vehicle_color'] = vehicleColor;
      if (driverLicenseNumber != null && driverLicenseNumber.isNotEmpty) {
        request.fields['driver_license_number'] = driverLicenseNumber;
      }
      if (vehiclePlateNumber != null && vehiclePlateNumber.isNotEmpty) {
        request.fields['vehicle_plate_number'] = vehiclePlateNumber;
      }
      if (vehicleYear != null) {
        request.fields['vehicle_year'] = vehicleYear.toString();
      }
      // Laravel reads an array from repeated `service_areas[]` fields.
      for (var i = 0; i < serviceAreas.length; i++) {
        request.fields['service_areas[$i]'] = serviceAreas[i];
      }
      if (profilePicture != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_picture', profilePicture.path),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final body = _decode(response.body);

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          body['success'] == true) {
        final data = Map<String, dynamic>.from(body['data'] as Map? ?? const {});

        // Keep the stored status in step, so the app's existing gate sends the
        // rider to the pending screen from here on rather than back to a form
        // they have already filled in.
        final status = ApplicationStatus.fromDriverBlock(data);
        if (status != null) {
          await _secureStorage.saveApplicationStatus(status);
          await _secureStorage.saveStatusReason(data['status_reason']?.toString());
        }

        return DriverApplication.fromJson(data);
      }

      throw DriverApplicationException(
        body['message']?.toString() ?? 'Could not submit your application.',
        code: body['code']?.toString(),
        statusCode: response.statusCode,
        fieldErrors: _fieldErrors(body['errors']),
      );
    } on DriverApplicationException {
      rethrow;
    } catch (_) {
      throw DriverApplicationException(
        'Could not reach HudHud. Check your connection and try again.',
        code: 'NETWORK',
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, List<String>> _fieldErrors(dynamic raw) {
    if (raw is! Map) return const <String, List<String>>{};
    final out = <String, List<String>>{};
    raw.forEach((key, value) {
      out[key.toString()] = value is List
          ? value.map((e) => e.toString()).toList()
          : <String>[value.toString()];
    });
    return out;
  }
}
