// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class HandymanProfileModel {
  final int? id;
  final int? userId;
  final String? skills;
  final String? serviceType;
  final double? hourlyRate;
  final int? experienceYears;
  final double? serviceRadius;
  final String? address;
  final bool? isVerified;
  final bool? isAvailable;
  final String? bio;
  final String? certifications;
  final String? tools;
  final String? availability;
  final String? createdAt;
  final String? updatedAt;

  HandymanProfileModel({
    this.id,
    this.userId,
    this.skills,
    this.serviceType,
    this.hourlyRate,
    this.experienceYears,
    this.serviceRadius,
    this.address,
    this.isVerified,
    this.isAvailable,
    this.bio,
    this.certifications,
    this.tools,
    this.availability,
    this.createdAt,
    this.updatedAt,
  });

  HandymanProfileModel copyWith({
    int? id,
    int? userId,
    String? skills,
    String? serviceType,
    double? hourlyRate,
    int? experienceYears,
    double? serviceRadius,
    String? address,
    bool? isVerified,
    bool? isAvailable,
    String? bio,
    String? certifications,
    String? tools,
    String? availability,
    String? createdAt,
    String? updatedAt,
  }) {
    return HandymanProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      skills: skills ?? this.skills,
      serviceType: serviceType ?? this.serviceType,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      experienceYears: experienceYears ?? this.experienceYears,
      serviceRadius: serviceRadius ?? this.serviceRadius,
      address: address ?? this.address,
      isVerified: isVerified ?? this.isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
      bio: bio ?? this.bio,
      certifications: certifications ?? this.certifications,
      tools: tools ?? this.tools,
      availability: availability ?? this.availability,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'skills': skills,
      'service_type': serviceType,
      'hourly_rate': hourlyRate,
      'experience_years': experienceYears,
      'service_radius': serviceRadius,
      'address': address,
      'is_verified': isVerified,
      'is_available': isAvailable,
      'bio': bio,
      'certifications': certifications,
      'tools': tools,
      'availability': availability,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory HandymanProfileModel.fromMap(Map<String, dynamic> map) {
    return HandymanProfileModel(
      id: map['id'] != null ? (map['id'] is int ? map['id'] as int : int.tryParse(map['id'].toString())) : null,
      userId: map['user_id'] != null ? (map['user_id'] is int ? map['user_id'] as int : int.tryParse(map['user_id'].toString())) : null,
      skills: map['skills'] != null ? map['skills'] as String : null,
      serviceType:
          map['service_type'] != null ? map['service_type'] as String : null,
      hourlyRate: map['hourly_rate'] != null
          ? (map['hourly_rate'] is int
              ? (map['hourly_rate'] as int).toDouble()
              : map['hourly_rate'] as double)
          : null,
      experienceYears: map['experience_years'] != null
          ? map['experience_years'] as int
          : null,
      serviceRadius: map['service_radius'] != null
          ? (map['service_radius'] is int
              ? (map['service_radius'] as int).toDouble()
              : map['service_radius'] as double)
          : null,
      address: map['address'] != null ? map['address'] as String : null,
      isVerified:
          map['is_verified'] != null ? map['is_verified'] as bool : null,
      isAvailable:
          map['is_available'] != null ? map['is_available'] as bool : null,
      bio: map['bio'] != null ? map['bio'] as String : null,
      certifications: map['certifications'] != null
          ? map['certifications'] as String
          : null,
      tools: map['tools'] != null ? map['tools'] as String : null,
      availability:
          map['availability'] != null ? map['availability'] as String : null,
      createdAt:
          map['created_at'] != null ? map['created_at'] as String : null,
      updatedAt:
          map['updated_at'] != null ? map['updated_at'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory HandymanProfileModel.fromJson(String source) =>
      HandymanProfileModel.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
