// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class VehicleModel {
  final int? id;
  final String? driver_id;
  final String? vehicle_type_id;
  final String? make;
  final String? model;
  final int? year;
  final String? license_plate;
  final String? color;
  final String? is_active;
  final String? approved_at;
  final String? approved_by;
  final String? deleted_at;
  final String? created_at;
  final String? updated_at;
  VehicleModel({
    this.id,
    this.driver_id,
    this.vehicle_type_id,
    this.make,
    this.model,
    this.year,
    this.license_plate,
    this.color,
    this.is_active,
    this.approved_at,
    this.approved_by,
    this.deleted_at,
    this.created_at,
    this.updated_at,
  });

  VehicleModel copyWith({
    int? id,
    String? driver_id,
    String? vehicle_type_id,
    String? make,
    String? model,
    int? year,
    String? license_plate,
    String? color,
    String? is_active,
    String? approved_at,
    String? approved_by,
    String? deleted_at,
    String? created_at,
    String? updated_at,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      driver_id: driver_id ?? this.driver_id,
      vehicle_type_id: vehicle_type_id ?? this.vehicle_type_id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      license_plate: license_plate ?? this.license_plate,
      color: color ?? this.color,
      is_active: is_active ?? this.is_active,
      approved_at: approved_at ?? this.approved_at,
      approved_by: approved_by ?? this.approved_by,
      deleted_at: deleted_at ?? this.deleted_at,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'driver_id': driver_id,
      'vehicle_type_id': vehicle_type_id,
      'make': make,
      'model': model,
      'year': year,
      'license_plate': license_plate,
      'color': color,
      'is_active': is_active,
      'approved_at': approved_at,
      'approved_by': approved_by,
      'deleted_at': deleted_at,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] != null ? map['id'] as int : null,
      driver_id: map['driver_id'] != null ? map['driver_id'] as String : null,
      vehicle_type_id: map['vehicle_type_id'] != null ? map['vehicle_type_id'] as String : null,
      make: map['make'] != null ? map['make'] as String : null,
      model: map['model'] != null ? map['model'] as String : null,
      year: map['year'] != null ? map['year'] as int : null,
      license_plate: map['license_plate'] != null ? map['license_plate'] as String : null,
      color: map['color'] != null ? map['color'] as String : null,
      is_active: map['is_active'] != null ? map['is_active'] as String : null,
      approved_at: map['approved_at'] != null ? map['approved_at'] as String : null,
      approved_by: map['approved_by'] != null ? map['approved_by'] as String : null,
      deleted_at: map['deleted_at'] != null ? map['deleted_at'] as String : null,
      created_at: map['created_at'] != null ? map['created_at'] as String : null,
      updated_at: map['updated_at'] != null ? map['updated_at'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory VehicleModel.fromJson(String source) => VehicleModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'VehicleModel(id: $id, driver_id: $driver_id, vehicle_type_id: $vehicle_type_id, make: $make, model: $model, year: $year, license_plate: $license_plate, color: $color, is_active: $is_active, approved_at: $approved_at, approved_by: $approved_by, deleted_at: $deleted_at, created_at: $created_at, updated_at: $updated_at)';
  }

  @override
  bool operator ==(covariant VehicleModel other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.driver_id == driver_id &&
      other.vehicle_type_id == vehicle_type_id &&
      other.make == make &&
      other.model == model &&
      other.year == year &&
      other.license_plate == license_plate &&
      other.color == color &&
      other.is_active == is_active &&
      other.approved_at == approved_at &&
      other.approved_by == approved_by &&
      other.deleted_at == deleted_at &&
      other.created_at == created_at &&
      other.updated_at == updated_at;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      driver_id.hashCode ^
      vehicle_type_id.hashCode ^
      make.hashCode ^
      model.hashCode ^
      year.hashCode ^
      license_plate.hashCode ^
      color.hashCode ^
      is_active.hashCode ^
      approved_at.hashCode ^
      approved_by.hashCode ^
      deleted_at.hashCode ^
      created_at.hashCode ^
      updated_at.hashCode;
  }
}
