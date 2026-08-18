import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/features/chat/data/models/chat_conversation_model.dart';

class DeliveryProfilePage extends StatefulWidget {
  const DeliveryProfilePage({super.key});

  @override
  State<DeliveryProfilePage> createState() => _DeliveryProfilePageState();
}

class _DeliveryProfilePageState extends State<DeliveryProfilePage> {
  bool _profileLoading = true;
  bool _historyLoading = true;
  bool _openingSupport = false;
  List<dynamic> _historyOrders = [];
  int _historyTotal = 0;

  String _name = '—';
  String _email = '—';
  String _phone = '—';
  String? _avatarPath;
  String _vehicleDisplay = '—';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadHistory();
  }

  Future<void> _loadProfile() async {
    setState(() => _profileLoading = true);
    try {
      final api = getIt<ApiService>();
      final profile = await api.getDriverProfile();
      if (!mounted) return;
      if (profile != null) {
        final user = profile['user'];
        final driverProfile = profile['driver_profile'];
        if (user is Map<String, dynamic>) {
          _name = user['name']?.toString() ?? '—';
          _email = user['email']?.toString() ?? '—';
          _phone = user['phone']?.toString() ?? '—';
          _avatarPath = user['avatar']?.toString();
          if ((_avatarPath == null || _avatarPath!.isEmpty) && driverProfile is Map<String, dynamic>) {
            final dp = driverProfile['profile_picture']?.toString();
            if (dp != null && dp.isNotEmpty) _avatarPath = dp;
          }
        }
        if (driverProfile is Map<String, dynamic>) {
          final make = driverProfile['vehicle_make']?.toString();
          final model = driverProfile['vehicle_model']?.toString();
          final plate = driverProfile['vehicle_plate_number']?.toString();
          if (make != null && model != null && plate != null) {
            _vehicleDisplay = '$make $model - $plate';
          } else if (plate != null) {
            _vehicleDisplay = plate;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _profileLoading = false);
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final api = getIt<ApiService>();
      final res = await api.getDriverHistory(page: 1);
      if (!mounted) return;
      if (res != null) {
        final data = res['data'];
        final list = data is List ? data : <dynamic>[];
        setState(() {
          _historyOrders = List<dynamic>.from(list);
          _historyTotal = (res['total'] is int) ? res['total'] as int : 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _historyOrders = []);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
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
      await LogoutHelper.logout();
      if (mounted) context.goNamed(AppRouter.login);
    }
  }

  Future<void> _openSupportChat() async {
    if (_openingSupport) return;
    setState(() => _openingSupport = true);
    try {
      final api = getIt<ApiService>();
      final res = await api.openSupportConversation();
      if (!mounted) return;
      final conversationId = ChatConversation.conversationIdFromResponse(res);
      await context.pushNamed(
        AppRouter.supportChat,
        extra: {'conversationId': conversationId},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSupport = false);
    }
  }

  static String _avatarUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = ApiConfig.originUrl;
    if (path.startsWith('/')) return '$base$path';
    return '$base/storage/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadHistory();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_profileLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _avatarPath != null && _avatarPath!.isNotEmpty
                      ? NetworkImage(_avatarUrl(_avatarPath))
                      : null,
                  child: _avatarPath == null || _avatarPath!.isEmpty
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _name,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                if (_vehicleDisplay != '—') ...[
                  const SizedBox(height: 4),
                  Text(
                    _vehicleDisplay,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Divider(height: 32),
                _buildProfileItem(Icons.email, 'Email', _email),
                _buildProfileItem(Icons.phone, 'Phone', _phone),
                _buildProfileItem(Icons.local_shipping, 'Vehicle', _vehicleDisplay),
                const SizedBox(height: 8),
                Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Icon(Icons.support_agent, color: Colors.deepOrange.shade700),
                    title: Text('chat.support'.tr()),
                    trailing: _openingSupport
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _openingSupport ? null : _openSupportChat,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, size: 20, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Job history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              if (_historyLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_historyOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No jobs yet',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _historyOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = _historyOrders[index];
                    if (order is! Map<String, dynamic>) return const SizedBox.shrink();
                    final orderNumber = order['order_number']?.toString() ?? '—';
                    final totalAmount = order['total_amount']?.toString() ?? '—';
                    final status = order['status']?.toString() ?? '—';
                    final deliveredAt = order['delivered_at']?.toString();
                    final createdAt = order['created_at']?.toString();
                    final dateStr = deliveredAt ?? createdAt ?? '—';
                    final customer = order['customer'];
                    final customerName = customer is Map<String, dynamic> ? (customer['name']?.toString() ?? '—') : '—';
                    final typeLabel = _jobTypeLabel(order);
                    return Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                orderNumber,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (typeLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _jobTypeBadge(typeLabel),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer: $customerName'),
                              Text(
                                dateStr.length > 10
                                    ? '${dateStr.substring(0, 10)} ${dateStr.length > 19 ? dateStr.substring(11, 19) : ''}'
                                    : dateStr,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppCurrency.format(totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: status == 'delivered' ? Colors.green.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: status == 'delivered' ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (!_historyLoading && _historyTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '$_historyTotal job${_historyTotal == 1 ? '' : 's'} total',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _jobTypeLabel(Map<String, dynamic> order) {
    final type = order['type']?.toString().trim().toLowerCase() ?? '';
    if (type == 'ride') return 'Ride';
    if (type == 'delivery') return 'Delivery';
    if (type.isEmpty) return '';
    return '${type[0].toUpperCase()}${type.substring(1)}';
  }

  static Widget _jobTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
