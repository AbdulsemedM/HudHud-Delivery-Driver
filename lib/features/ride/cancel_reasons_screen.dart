import 'package:flutter/material.dart';

class CancelReasonsScreen extends StatefulWidget {
  const CancelReasonsScreen({Key? key}) : super(key: key);

  @override
  State<CancelReasonsScreen> createState() => _CancelReasonsScreenState();
}

class _CancelReasonsScreenState extends State<CancelReasonsScreen> {
  String selectedReason = 'Other';
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reasonController.text = 'Amet minim mollit non deserunt ullamco est sit aliqua dolor do amet sint. Velit officia consequat duis enim velit mollit. Exercitation veniam consequat sunt nostrud amet.';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Go Back',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'My_Rides_Main',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Reasons to Cancel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            // Reason Options
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildReasonOption('Reason 1'),
                  const SizedBox(height: 16),
                  _buildReasonOption('Reason 2'),
                  const SizedBox(height: 16),
                  _buildReasonOption('Reason 3'),
                  const SizedBox(height: 16),
                  _buildReasonOption('Other'),
                  const SizedBox(height: 24),

                  // Text Input for Other Reason
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Please specify your reason...',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Show confirmation and navigate back
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ride cancelled successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Submit and Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption(String reason) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedReason = reason;
        });
      },
      child: Row(
        children: [
          Radio<String>(
            value: reason,
            groupValue: selectedReason,
            onChanged: (value) {
              setState(() {
                selectedReason = value!;
              });
            },
            activeColor: const Color(0xFF673AB7),
          ),
          const SizedBox(width: 8),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}