import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/services/secure_storage_service.dart';
import '../../../driver_registration/driver_registration_page.dart';
import '../../../ride/ride_status_screen.dart';
import '../../../wallet/earnings_main_screen.dart';
import '../../../auth/presentation/pages/verify_phonenumber_page.dart';
import '../../../auth/presentation/pages/verify_email_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isOnline = false;
  int _availableRides = 24;
  final SecureStorageService _secureStorage = SecureStorageService();

  // User data variables
  String _userName = 'HudHud Driver';
  String _userEmail = '';
  String _userPhone = '';
  String _userReferralCode = '';
  bool _emailVerified = false;
  bool _phoneVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userName = await _secureStorage.getUserName();
      final userEmail = await _secureStorage.getUserEmail();
      final userPhone = await _secureStorage.getUserPhone();
      final userReferralCode = await _secureStorage.getUserReferralCode();
      final emailVerified = await _secureStorage.getUserEmailVerified();
      final phoneVerified = await _secureStorage.getUserPhoneVerified();

      setState(() {
        _userName = userName ?? 'HudHud Driver';
        _userEmail = userEmail ?? '';
        _userPhone = userPhone ?? '';
        _userReferralCode = userReferralCode ?? '';
        _emailVerified = emailVerified ?? false;
        _phoneVerified = phoneVerified ?? false;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _checkEmailVerificationAndProceed(VoidCallback onProceed) {
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email before accessing this feature'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    onProceed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Welcome, $_userName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Profile Card
                    // Status Card
                    _buildStatusCard(),
                    const SizedBox(height: 24),

                    // Quick Actions Title
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildActionCard(
                          'Driver Registration',
                          Icons.app_registration,
                          Colors.purple,
                          () {
                            _checkEmailVerificationAndProceed(() {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DriverRegistrationPage(),
                                ),
                              );
                            });
                          },
                        ),
                        _buildActionCard(
                          'Assigned Rides',
                          Icons.directions_car,
                          Colors.blue,
                          () {
                            _checkEmailVerificationAndProceed(() {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RideStatusScreen(),
                                ),
                              );
                            });
                          },
                        ),
                        _buildActionCard(
                          'Wallet',
                          Icons.account_balance_wallet,
                          Colors.green,
                          () {
                            _checkEmailVerificationAndProceed(() {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EarningsMainScreen(),
                                ),
                              );
                            });
                          },
                        ),
                        _buildActionCard(
                          'Earnings',
                          Icons.attach_money,
                          Colors.amber,
                          () {
                            _checkEmailVerificationAndProceed(() {
                              // Add earnings functionality here
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildUserProfileCard(),
                    const SizedBox(height: 24),

                    // Recent Activity Title
                    // const Text(
                    //   'Recent Activity',
                    //   style: TextStyle(
                    //     fontSize: 18,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    // const SizedBox(height: 16),

                    // // Recent Activity List
                    // _buildActivityItem(
                    //   'Completed Delivery',
                    //   'Order #12345 - \$15.50',
                    //   '2 hours ago',
                    //   Icons.check_circle,
                    //   Colors.green,
                    // ),
                    // _buildActivityItem(
                    //   'Cancelled Delivery',
                    //   'Order #12344 - \$8.25',
                    //   '5 hours ago',
                    //   Icons.cancel,
                    //   Colors.red,
                    // ),
                    // _buildActivityItem(
                    //   'Wallet Deposit',
                    //   '\$50.00 added to your wallet',
                    //   'Yesterday',
                    //   Icons.account_balance_wallet,
                    //   Colors.blue,
                    // ),
                  ],
                ),
              ),
            ),

            // Bottom Driver Card
            // _buildBottomDriverCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            if (!_emailVerified || !_phoneVerified) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Verification Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_emailVerified && _userEmail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VerifyEmailPage(),
                                ),
                              );
                              // Refresh user data if email verification was successful
                              if (result == true) {
                                _loadUserData();
                              }
                            },
                            icon: const Icon(Icons.email_outlined, size: 18),
                            label: const Text('Verify Email'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_phoneVerified && _userPhone.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VerifyPhoneNumberPage(phone: _userPhone),
                              ),
                            );
                            // Refresh user data if phone verification was successful
                            if (result == true) {
                              _loadUserData();
                            }
                          },
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('Verify Phone Number'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.deepPurple, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.deepPurple.withOpacity(0.2),
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'H',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_userEmail.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _userEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_emailVerified)
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      if (_userPhone.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _userPhone,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (_phoneVerified)
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.green,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditProfileDialog(),
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
            if (_userReferralCode.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Referral Code: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _userReferralCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        // Copy to clipboard functionality can be added here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referral code copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.copy,
                        size: 18,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Verification Status Section
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.deepPurple,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Deliveries', '5', Icons.delivery_dining),
                _buildSummaryItem('Earnings', '\$75.50', Icons.attach_money),
                _buildSummaryItem('Rating', '4.8', Icons.star),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Text(
          time,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDriverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    'https://randomuser.me/api/portraits/women/44.jpg',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Olivia Rhye',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Honda Civic - RYT 2093 -234',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        _isOnline ? 'Go offline' : 'Go online',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isOnline,
                        onChanged: (value) {
                          setState(() {
                            _isOnline = value;
                          });
                        },
                        activeColor: Colors.white,
                        activeTrackColor: Colors.green,
                      ),
                    ],
                  ),
                  if (_isOnline)
                    Text(
                      '$_availableRides rides available',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName);
    final TextEditingController phoneController = TextEditingController(text: _userPhone);
    final TextEditingController emailController = TextEditingController(text: _userEmail);
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar section
                    GestureDetector(
                      onTap: () async {
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Take Photo'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (image != null) {
                                        setState(() {
                                          selectedImage = File(image.path);
                                        });
                                      }
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose from Gallery'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (image != null) {
                                        setState(() {
                                          selectedImage = File(image.path);
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple.withOpacity(0.1),
                          border: Border.all(color: Colors.deepPurple, width: 2),
                        ),
                        child: selectedImage != null
                            ? ClipOval(
                                child: Image.file(
                                  selectedImage!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.deepPurple.withOpacity(0.2),
                                child: selectedImage == null
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'H',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.camera_alt,
                                            color: Colors.deepPurple,
                                            size: 16,
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Name field
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Phone field
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    // Email field
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateProfile(
                      nameController.text,
                      phoneController.text,
                      emailController.text,
                      selectedImage,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateProfile(String name, String phone, String email, File? avatar) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Updating profile...'),
              ],
            ),
          );
        },
      );

      // Get the auth token
      final token = await _secureStorage.getToken();
      if (token == null) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Authentication token not found. Please login again.', Colors.red);
        return;
      }

      // Check if email or phone has changed
      final bool emailChanged = email != _userEmail;
      final bool phoneChanged = phone != _userPhone;

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://hudapi.mbitrix.com/api/update-profile'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add form fields
      request.fields['name'] = name;
      request.fields['phone'] = phone;
      request.fields['email'] = email;

      // Add avatar if selected
      if (avatar != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            avatar.path,
          ),
        );
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        
        // Update local data
        setState(() {
          _userName = name;
          _userPhone = phone;
          _userEmail = email;
          // Only reset verification status if the corresponding field changed
          if (emailChanged) {
            _emailVerified = false;
          }
          if (phoneChanged) {
            _phoneVerified = false;
          }
        });

        // Update secure storage
         await _secureStorage.saveUserName(name);
         await _secureStorage.saveUserEmail(email);
         await _secureStorage.saveUserPhone(phone);
         
         // Only reset verification status in storage if the corresponding field changed
         if (emailChanged) {
           await _secureStorage.saveUserEmailVerified(false);
         }
         if (phoneChanged) {
           await _secureStorage.saveUserPhoneVerified(false);
         }

        // Show appropriate success message
        String successMessage = 'Profile updated successfully!';
        if (emailChanged || phoneChanged) {
          List<String> changedFields = [];
          if (emailChanged) changedFields.add('email');
          if (phoneChanged) changedFields.add('phone');
          successMessage += ' Please verify your ${changedFields.join(' and ')}.';
        }
        
        _showSnackBar(successMessage, Colors.green);
        
        // Show verification reminder only if email or phone changed
        if (emailChanged || phoneChanged) {
          _showVerificationReminder(emailChanged, phoneChanged);
        }
      } else {
        final errorData = json.decode(responseBody);
        _showSnackBar(errorData['message'] ?? 'Failed to update profile', Colors.red);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      _showSnackBar('Error updating profile: ${e.toString()}', Colors.red);
    }
  }

  void _showVerificationReminder(bool emailChanged, bool phoneChanged) {
    List<String> fieldsToVerify = [];
    if (emailChanged) fieldsToVerify.add('email');
    if (phoneChanged) fieldsToVerify.add('phone number');
    
    String message = 'Your profile has been updated successfully. Please verify your ${fieldsToVerify.join(' and ')} to continue using all features.';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verification Required'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
