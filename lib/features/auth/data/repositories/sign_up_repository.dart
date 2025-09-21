import 'package:hudhud_delivery_driver/features/auth/data/models/sign_up_model.dart';
import 'package:hudhud_delivery_driver/features/auth/data/providers/sign_up_provider.dart';

class SignUpRepository {
  final SignUpProvider _signUpProvider;

  SignUpRepository(this._signUpProvider);

  Future<bool> validateEmail(String email) async {
    return await _signUpProvider.validateEmail(email);
  }

  Future<bool> validateName(String name) async {
    return await _signUpProvider.validateName(name);
  }

  Future<bool> validateMobileNumber(String mobileNumber) async {
    return await _signUpProvider.validateMobileNumber(mobileNumber);
  }

  Future<bool> submitSignUpData(SignUpModel signUpData) async {
    return await _signUpProvider.submitSignUpData(signUpData);
  }
}