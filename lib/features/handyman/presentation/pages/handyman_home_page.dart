import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_earnings_tab.dart';

class HandymanHomePage extends StatefulWidget {
  const HandymanHomePage({Key? key}) : super(key: key);

  @override
  State<HandymanHomePage> createState() => _HandymanHomePageState();
}

class _HandymanHomePageState extends State<HandymanHomePage> {
  final SecureStorageService _secureStorage = SecureStorageService();

  String _userName = 'Handyman';
  String _walletBalance = '0.00';
  String _walletCurrency = 'USD';
  String? _profilePictureUrl;
  String _status = '';
  List<String> _skills = [];
  String _serviceType = '';
  String _hourlyRate = '0.00';
  int _experienceYears = 0;
  int _serviceRadius = 0;
  String _address = '';
  String _bio = '';
  double _averageRating = 0;
  int _ratingsCount = 0;
  bool _isAvailable = true;
  bool _isVerified = false;
  bool _isUpdatingAvailability = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentServices = [];

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
          _profilePictureUrl = data['avatar_url']?.toString();
          _status = data['status']?.toString() ?? '';

          // Parse skills (API returns a JSON array)
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
          _averageRating = _parseDouble(data['average_rating']);
          _ratingsCount = _parseInt(data['ratings_count']);
          _isAvailable = data['is_available'] == true;
          _isVerified = data['is_verified'] == true;

          // Recent services
          final services = data['recent_services'];
          if (services is List) {
            _recentServices = services
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }

          _isLoading = false;
        });
      } else {
        // Fallback to stored name
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _toggleAvailability(bool available) async {
    if (_isUpdatingAvailability) return;
    setState(() => _isUpdatingAvailability = true);
    try {
      // Use the same availability endpoint
      final api = getIt<ApiService>();
      await api.updateDriverAvailability(
        isAvailable: available,
        reason: available
            ? 'Available for service requests'
            : 'Taking a break',
      );
      if (mounted) {
        setState(() {
          _isAvailable = available;
          _isUpdatingAvailability = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              available ? 'You are now available' : 'You are now unavailable',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingAvailability = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                child: CustomScrollView(
                  slivers: [
                    // App bar
                    SliverToBoxAdapter(child: _buildAppBar()),
                    // Verification status (if not verified)
                    if (!_isVerified)
                      SliverToBoxAdapter(child: _buildVerificationBanner()),
                    // Availability banner
                    SliverToBoxAdapter(child: _buildAvailabilityBanner()),
                    // Stats cards
                    SliverToBoxAdapter(child: _buildStatsRow()),
                    // Quick actions
                    SliverToBoxAdapter(child: _buildQuickActions()),
                    // Skills section
                    SliverToBoxAdapter(child: _buildSkillsSection()),
                    // Recent services
                    if (_recentServices.isNotEmpty)
                      SliverToBoxAdapter(child: _buildRecentServices()),
                    // Profile card
                    SliverToBoxAdapter(child: _buildProfileCard()),
                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 24),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.jpg',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.handyman,
                size: 32,
                color: AuthColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $_userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AuthColors.title,
                  ),
                ),
                Text(
                  _serviceType.isNotEmpty
                      ? '${_serviceType[0].toUpperCase()}${_serviceType.substring(1)}'
                      : 'Handyman',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AuthColors.label,
                  ),
                ),
              ],
            ),
          ),
          // Wallet chip
          Material(
            color: AuthColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('Earnings')),
                        body: const HandymanEarningsTab(),
                      ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 18, color: AuthColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$_walletCurrency $_walletBalance',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AuthColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status == 'pending_verification'
                        ? 'Pending Verification'
                        : 'Account Not Verified',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your account is being reviewed. Some features may be limited.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isAvailable
                ? [Colors.green.shade600, Colors.green.shade800]
                : [Colors.grey.shade600, Colors.grey.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isAvailable ? Icons.check_circle : Icons.pause_circle,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAvailable ? 'Available' : 'Unavailable',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isAvailable
                        ? 'You can receive service requests'
                        : 'You won\'t receive new requests',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isAvailable,
              onChanged:
                  _isUpdatingAvailability ? null : _toggleAvailability,
              activeColor: Colors.white,
              activeTrackColor: Colors.white.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              label: 'Rating',
              value: _averageRating > 0
                  ? _averageRating.toStringAsFixed(1)
                  : '—',
              subtitle: '$_ratingsCount reviews',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.attach_money,
              iconColor: Colors.green,
              label: 'Rate',
              value: '\$$_hourlyRate',
              subtitle: 'per hour',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.work_history,
              iconColor: AuthColors.primary,
              label: 'Experience',
              value: '$_experienceYears',
              subtitle: 'years',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AuthColors.hint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.assignment,
                  label: 'Service\nRequests',
                  color: Colors.blue,
                  onTap: () {
                    // Navigate to service requests when implemented
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.history,
                  label: 'Service\nHistory',
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Navigate to service history
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.account_balance_wallet,
                  label: 'Earnings',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('Earnings')),
                        body: const HandymanEarningsTab(),
                      ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.person,
                  label: 'Profile',
                  color: AuthColors.primary,
                  onTap: () => context.goNamed(AppRouter.handymanHome),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AuthColors.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    if (_skills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
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
            Row(
              children: [
                const Icon(Icons.handyman, size: 20, color: AuthColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'My Skills',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.title,
                  ),
                ),
                const Spacer(),
                Text(
                  'Radius: $_serviceRadius km',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AuthColors.hint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((skill) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AuthColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AuthColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    skill[0].toUpperCase() + skill.substring(1),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AuthColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _bio,
                style: const TextStyle(
                  fontSize: 13,
                  color: AuthColors.label,
                  height: 1.4,
                ),
              ),
            ],
            if (_address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AuthColors.hint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AuthColors.hint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentServices() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
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
            const Row(
              children: [
                Icon(Icons.history, size: 20, color: AuthColors.primary),
                SizedBox(width: 8),
                Text(
                  'Recent Services',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recentServices.take(5).map((service) {
              final status = service['status']?.toString() ?? '';
              final type = service['service_type']?.toString() ?? 'Service';
              final date = service['created_at']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AuthColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.build,
                          size: 18, color: AuthColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type[0].toUpperCase() + type.substring(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AuthColors.title,
                            ),
                          ),
                          if (date.isNotEmpty)
                            Text(
                              date.length > 10 ? date.substring(0, 10) : date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AuthColors.hint,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.isNotEmpty
                            ? status[0].toUpperCase() + status.substring(1)
                            : '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return AuthColors.hint;
    }
  }

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
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
          children: [
            // Profile row
            InkWell(
              onTap: () => context.goNamed(AppRouter.handymanHome),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AuthColors.primary.withOpacity(0.15),
                      backgroundImage:
                          _profilePictureUrl != null &&
                                  _profilePictureUrl!.isNotEmpty
                              ? NetworkImage(_profilePictureUrl!)
                              : null,
                      child: _profilePictureUrl == null ||
                              _profilePictureUrl!.isEmpty
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'H',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AuthColors.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AuthColors.title,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _serviceType.isNotEmpty
                                ? '${_serviceType[0].toUpperCase()}${_serviceType.substring(1)} • $_experienceYears yrs exp'
                                : 'Handyman',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AuthColors.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AuthColors.hint),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Logout
            InkWell(
              onTap: _handleLogout,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
