// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class DriverModel {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? email_verified_at;
  final String? phone_verified_at;
  final String? type;
  final String? status;
  final String? avatar;
  final String? device_token;
  final String? email_verification_code;
  final String? phone_verification_code;
  final String? last_login_at;
  final String? last_login_ip;
  final String? date_of_birth;
  final String? gender;
  final String? social_type;
  final String? language;
  final String? timezone;
  final String? referral_code;
  final String? deleted_at;
  final String? created_at;
  final String? updated_at;
  DriverModel({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.email_verified_at,
    this.phone_verified_at,
    this.type,
    this.status,
    this.avatar,
    this.device_token,
    this.email_verification_code,
    this.phone_verification_code,
    this.last_login_at,
    this.last_login_ip,
    this.date_of_birth,
    this.gender,
    this.social_type,
    this.language,
    this.timezone,
    this.referral_code,
    this.deleted_at,
    this.created_at,
    this.updated_at,
  });

  DriverModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? email_verified_at,
    String? phone_verified_at,
    String? type,
    String? status,
    String? avatar,
    String? device_token,
    String? email_verification_code,
    String? phone_verification_code,
    String? last_login_at,
    String? last_login_ip,
    String? date_of_birth,
    String? gender,
    String? social_type,
    String? language,
    String? timezone,
    String? referral_code,
    String? deleted_at,
    String? created_at,
    String? updated_at,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      email_verified_at: email_verified_at ?? this.email_verified_at,
      phone_verified_at: phone_verified_at ?? this.phone_verified_at,
      type: type ?? this.type,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      device_token: device_token ?? this.device_token,
      email_verification_code: email_verification_code ?? this.email_verification_code,
      phone_verification_code: phone_verification_code ?? this.phone_verification_code,
      last_login_at: last_login_at ?? this.last_login_at,
      last_login_ip: last_login_ip ?? this.last_login_ip,
      date_of_birth: date_of_birth ?? this.date_of_birth,
      gender: gender ?? this.gender,
      social_type: social_type ?? this.social_type,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      referral_code: referral_code ?? this.referral_code,
      deleted_at: deleted_at ?? this.deleted_at,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'email_verified_at': email_verified_at,
      'phone_verified_at': phone_verified_at,
      'type': type,
      'status': status,
      'avatar': avatar,
      'device_token': device_token,
      'email_verification_code': email_verification_code,
      'phone_verification_code': phone_verification_code,
      'last_login_at': last_login_at,
      'last_login_ip': last_login_ip,
      'date_of_birth': date_of_birth,
      'gender': gender,
      'social_type': social_type,
      'language': language,
      'timezone': timezone,
      'referral_code': referral_code,
      'deleted_at': deleted_at,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      id: map['id'] != null ? map['id'] as int : null,
      name: map['name'] != null ? map['name'] as String : null,
      email: map['email'] != null ? map['email'] as String : null,
      phone: map['phone'] != null ? map['phone'] as String : null,
      email_verified_at: map['email_verified_at'] != null ? map['email_verified_at'] as String : null,
      phone_verified_at: map['phone_verified_at'] != null ? map['phone_verified_at'] as String : null,
      type: map['type'] != null ? map['type'] as String : null,
      status: map['status'] != null ? map['status'] as String : null,
      avatar: map['avatar'] != null ? map['avatar'] as String : null,
      device_token: map['device_token'] != null ? map['device_token'] as String : null,
      email_verification_code: map['email_verification_code'] != null ? map['email_verification_code'] as String : null,
      phone_verification_code: map['phone_verification_code'] != null ? map['phone_verification_code'] as String : null,
      last_login_at: map['last_login_at'] != null ? map['last_login_at'] as String : null,
      last_login_ip: map['last_login_ip'] != null ? map['last_login_ip'] as String : null,
      date_of_birth: map['date_of_birth'] != null ? map['date_of_birth'] as String : null,
      gender: map['gender'] != null ? map['gender'] as String : null,
      social_type: map['social_type'] != null ? map['social_type'] as String : null,
      language: map['language'] != null ? map['language'] as String : null,
      timezone: map['timezone'] != null ? map['timezone'] as String : null,
      referral_code: map['referral_code'] != null ? map['referral_code'] as String : null,
      deleted_at: map['deleted_at'] != null ? map['deleted_at'] as String : null,
      created_at: map['created_at'] != null ? map['created_at'] as String : null,
      updated_at: map['updated_at'] != null ? map['updated_at'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory DriverModel.fromJson(String source) => DriverModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'DriverModel(id: $id, name: $name, email: $email, phone: $phone, email_verified_at: $email_verified_at, phone_verified_at: $phone_verified_at, type: $type, status: $status, avatar: $avatar, device_token: $device_token, email_verification_code: $email_verification_code, phone_verification_code: $phone_verification_code, last_login_at: $last_login_at, last_login_ip: $last_login_ip, date_of_birth: $date_of_birth, gender: $gender, social_type: $social_type, language: $language, timezone: $timezone, referral_code: $referral_code, deleted_at: $deleted_at, created_at: $created_at, updated_at: $updated_at)';
  }

  @override
  bool operator ==(covariant DriverModel other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.email_verified_at == email_verified_at &&
      other.phone_verified_at == phone_verified_at &&
      other.type == type &&
      other.status == status &&
      other.avatar == avatar &&
      other.device_token == device_token &&
      other.email_verification_code == email_verification_code &&
      other.phone_verification_code == phone_verification_code &&
      other.last_login_at == last_login_at &&
      other.last_login_ip == last_login_ip &&
      other.date_of_birth == date_of_birth &&
      other.gender == gender &&
      other.social_type == social_type &&
      other.language == language &&
      other.timezone == timezone &&
      other.referral_code == referral_code &&
      other.deleted_at == deleted_at &&
      other.created_at == created_at &&
      other.updated_at == updated_at;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      email_verified_at.hashCode ^
      phone_verified_at.hashCode ^
      type.hashCode ^
      status.hashCode ^
      avatar.hashCode ^
      device_token.hashCode ^
      email_verification_code.hashCode ^
      phone_verification_code.hashCode ^
      last_login_at.hashCode ^
      last_login_ip.hashCode ^
      date_of_birth.hashCode ^
      gender.hashCode ^
      social_type.hashCode ^
      language.hashCode ^
      timezone.hashCode ^
      referral_code.hashCode ^
      deleted_at.hashCode ^
      created_at.hashCode ^
      updated_at.hashCode;
  }
}
