import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_input_mobile.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/custom_text_field.dart';

class SignUpInputName extends StatefulWidget {
  final String email;
  
  const SignUpInputName({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<SignUpInputName> createState() => _SignUpInputNameState();
}

class _SignUpInputNameState extends State<SignUpInputName> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Full name is required';
      });
      return false;
    } else if (name.length < 3) {
      setState(() {
        _nameError = 'Name must be at least 3 characters';
      });
      return false;
    } else if (!name.contains(' ')) {
      setState(() {
        _nameError = 'Please enter your full name';
      });
      return false;
    }
    setState(() {
      _nameError = null;
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
                "What's your name?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Drivers will confirm it's you upon arrival",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                hintText: "Your Full Name",
                controller: _nameController,
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                "Please enter your first and last name",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
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
                  FloatingActionButton(
                    onPressed: () {
                      if (_validateName()) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignUpInputMobile(
                              email: widget.email,
                              name: _nameController.text.trim(),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}