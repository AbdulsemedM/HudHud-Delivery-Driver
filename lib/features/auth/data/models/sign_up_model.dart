class SignUpModel {
  final String? email;
  final String? name;
  final String? mobileNumber;

  SignUpModel({
    this.email,
    this.name,
    this.mobileNumber,
  });

  SignUpModel copyWith({
    String? email,
    String? name,
    String? mobileNumber,
  }) {
    return SignUpModel(
      email: email ?? this.email,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'mobile_number': mobileNumber,
    };
  }

  factory SignUpModel.fromJson(Map<String, dynamic> json) {
    return SignUpModel(
      email: json['email'],
      name: json['name'],
      mobileNumber: json['mobile_number'],
    );
  }
}