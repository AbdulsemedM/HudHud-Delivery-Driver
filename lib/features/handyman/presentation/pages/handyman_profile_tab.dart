import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/edit_handyman_profile_page.dart';

class HandymanProfileTab extends StatefulWidget {
  const HandymanProfileTab({super.key});

  @override
  State<HandymanProfileTab> createState() => _HandymanProfileTabState();
}

class _HandymanProfileTabState extends State<HandymanProfileTab> {
  final SecureStorageService _secureStorage = SecureStorageService();

  String _userName = 'Handyman';
  String _email = '';
  String _phone = '';
  String? _profilePictureUrl;
  String _status = '';
  List<String> _skills = [];
  String _serviceType = '';
  String _hourlyRate = '0.00';
  int _experienceYears = 0;
  int _serviceRadius = 0;
  String _address = '';
  String _bio = '';
  bool _isVerified = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = getIt<ApiService>();
      final data = await api.getHandymanProfile();
      if (mounted && data != null) {
        setState(() {
          _userName = data['name']?.toString() ?? 'Handyman';
          _email = data['email']?.toString() ?? '';
          _phone = data['phone']?.toString() ?? '';
          _profilePictureUrl = data['avatar_url']?.toString();
          _status = data['status']?.toString() ?? '';
          final rawSkills = data['skills'];
          if (rawSkills is List) {
            _skills = rawSkills.map((e) => e.toString()).toList();
          }
          _serviceType = data['service_type']?.toString() ?? '';
          _hourlyRate = data['hourly_rate']?.toString() ?? '0.00';
          _experienceYears = _parseInt(data['experience_years']);
          _serviceRadius = _parseInt(data['service_radius']);
          _address = data['address']?.toString() ?? '';
          _bio = data['bio']?.toString() ?? '';
          _isVerified = data['is_verified'] == true;
          _isLoading = false;
        });
      } else {
        final name = await _secureStorage.getUserName();
        if (mounted) {
          setState(() {
            _userName = name ?? 'Handyman';
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        final name = await _secureStorage.getUserName();
        setState(() {
          _userName = name ?? 'Handyman';
          _isLoading = false;
        });
      }
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await getIt<SecureStorageService>().clearAll();
      if (mounted) context.goNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 20),
                      _buildProfileCard(),
                      const SizedBox(height: 20),
                      _buildLogoutButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AuthColors.primary.withOpacity(0.15),
              backgroundImage: _profilePictureUrl != null &&
                      _profilePictureUrl!.isNotEmpty
                  ? NetworkImage(_profilePictureUrl!)
                  : null,
              child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                  ? Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'H',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AuthColors.primary,
                      ),
                    )
                  : null,
            ),
            if (_isVerified)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _userName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AuthColors.title,
          ),
        ),
        if (_email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(
              fontSize: 14,
              color: AuthColors.label,
            ),
          ),
        ],
        if (_phone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _phone,
            style: const TextStyle(
              fontSize: 14,
              color: AuthColors.label,
            ),
          ),
        ],
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(_status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _status.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(_status),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'verified':
        return Colors.green;
      case 'pending_verification':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return AuthColors.hint;
    }
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_skills.isNotEmpty) ...[
            const Text(
              'Skills',
              style: TextStyle(
                fontSize: 12,
                color: AuthColors.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AuthColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    skill.isNotEmpty
                        ? '${skill[0].toUpperCase()}${skill.substring(1)}'
                        : skill,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AuthColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (_serviceType.isNotEmpty) _profileRow('Service type', _serviceType),
          _profileRow('Hourly rate', '\$$_hourlyRate'),
          _profileRow('Experience', '$_experienceYears years'),
          _profileRow('Service radius', '$_serviceRadius km'),
          if (_address.isNotEmpty) _profileRow('Address', _address),
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Bio',
              style: TextStyle(
                fontSize: 12,
                color: AuthColors.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _bio,
              style: const TextStyle(
                fontSize: 14,
                color: AuthColors.label,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditHandymanProfilePage(),
                  ),
                );
                if (result == true && mounted) _loadProfile();
              },
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AuthColors.hint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AuthColors.title,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, size: 20, color: Colors.red),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
