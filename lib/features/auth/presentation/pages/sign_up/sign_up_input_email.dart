import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_input_name.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/custom_text_field.dart';

class SignUpInputEmail extends StatefulWidget {
  const SignUpInputEmail({Key? key}) : super(key: key);

  @override
  State<SignUpInputEmail> createState() => _SignUpInputEmailState();
}

class _SignUpInputEmailState extends State<SignUpInputEmail> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      return false;
    } else if (!EmailValidator.validate(email)) {
      setState(() {
        _emailError = 'Please enter a valid email';
      });
      return false;
    }
    setState(() {
      _emailError = null;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What's your Email?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This is where we'll send your receipts",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                hintText: "Email",
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() {
                      _emailError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                "Please enter a valid email address",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  // Navigate to login page or handle existing account
                },
                child: const Text(
                  "Already have an account?",
                  style: TextStyle(
                    color: Colors.purple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_validateEmail()) {
                      // Navigate to next page if validation passes
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpInputName()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}