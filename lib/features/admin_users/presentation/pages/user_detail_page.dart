import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/user_status_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/user_model.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({
    super.key,
    required this.userId,
    required this.userType,
    required this.title,
  });

  final int userId;
  final String userType;
  final String title;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  UserModel? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = getIt<ApiService>();
      final user = await api.getUserById(widget.userId);
      if (mounted) setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await getIt<ApiService>().updateUserStatus(widget.userId, status);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _user == null
                  ? const Center(child: Text('User not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: ${_user!.name ?? '—'}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Email: ${_user!.email ?? '—'}'),
                          Text('Phone: ${_user!.phone ?? '—'}'),
                          Text('Status: ${_user!.status ?? '—'}'),
                          if (_user!.last_login_at != null)
                            Text('Last login: ${_user!.last_login_at}'),
                          const SizedBox(height: 24),
                          const Text('Actions',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_user!.status != UserStatusConstants.active)
                                ElevatedButton(
                                  onPressed: () =>
                                      _updateStatus(UserStatusConstants.active),
                                  child: const Text('Approve'),
                                ),
                              if (_user!.status != UserStatusConstants.suspended)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  onPressed: () => _updateStatus(
                                      UserStatusConstants.suspended),
                                  child: const Text('Suspend'),
                                ),
                              if (_user!.status != UserStatusConstants.active)
                                OutlinedButton(
                                  onPressed: () => _updateStatus(
                                      UserStatusConstants.deactivated),
                                  child: const Text('Deactivate'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }
}
