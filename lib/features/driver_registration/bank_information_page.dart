import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BankInformationPage extends StatefulWidget {
  const BankInformationPage({Key? key}) : super(key: key);

  @override
  State<BankInformationPage> createState() => _BankInformationPageState();
}

class _BankInformationPageState extends State<BankInformationPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _cardNumberController = TextEditingController();
  final _cvvController = TextEditingController();
  final _expiryController = TextEditingController();
  
  // Card type
  String _cardType = '';

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cvvController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  // Detect card type based on first digits
  void _detectCardType(String cardNumber) {
    if (cardNumber.isEmpty) {
      setState(() {
        _cardType = '';
      });
      return;
    }
    
    // Simple card type detection based on first digit
    if (cardNumber.startsWith('4')) {
      setState(() {
        _cardType = 'Visa';
      });
    } else if (cardNumber.startsWith('5')) {
      setState(() {
        _cardType = 'MasterCard';
      });
    } else if (cardNumber.startsWith('3')) {
      setState(() {
        _cardType = 'Amex';
      });
    } else if (cardNumber.startsWith('6')) {
      setState(() {
        _cardType = 'Discover';
      });
    } else {
      setState(() {
        _cardType = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Credit/Debit Information'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Number
                Row(
                  children: [
                    // Card icon based on detected type
                    Container(
                      width: 40,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _cardType.isNotEmpty ? _cardType[0] : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Card number field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Card number',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _cardNumberController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'XXXX XXXX XXXX XXXX',
                              suffixIcon: _cardType.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _cardType,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(16),
                            ],
                            onChanged: _detectCardType,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your card number';
                              }
                              if (value.length < 13 || value.length > 16) {
                                return 'Card number must be between 13 and 16 digits';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This is a hint text to help user.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // CVV and Expiry
                Row(
                  children: [
                    // CVV
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CVV',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _cvvController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'XXX',
                              suffixIcon: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.info_outline),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter CVV';
                              }
                              if (value.length < 3 || value.length > 4) {
                                return 'Invalid CVV';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Expiry
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expiry',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _expiryController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'MM/YYYY',
                              suffixIcon: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.calendar_today),
                              ),
                            ),
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                              LengthLimitingTextInputFormatter(7),
                              _ExpiryDateInputFormatter(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter expiry date';
                              }
                              if (!RegExp(r'^(0[1-9]|1[0-2])/20[2-9][0-9]$').hasMatch(value)) {
                                return 'Invalid format (MM/YYYY)';
                              }
                              
                              // Check if card is expired
                              try {
                                final parts = value.split('/');
                                final month = int.parse(parts[0]);
                                final year = int.parse(parts[1]);
                                
                                final now = DateTime.now();
                                if (year < now.year || (year == now.year && month < now.month)) {
                                  return 'Card has expired';
                                }
                              } catch (e) {
                                return 'Invalid date';
                              }
                              
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Return true to indicate completion
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom input formatter for expiry date (MM/YYYY)
class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    if (text.isEmpty) {
      return newValue;
    }
    
    // Add slash after month
    if (text.length == 2 && oldValue.text.length == 1) {
      return TextEditingValue(
        text: '$text/',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    }
    
    return newValue;
  }
}