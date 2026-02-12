import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/user_status_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/user_model.dart';
import 'package:hudhud_delivery_driver/core/models/handyman_profile_model.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

class HandymanDetailPage extends StatefulWidget {
  const HandymanDetailPage({super.key, required this.userId});

  final int userId;

  @override
  State<HandymanDetailPage> createState() => _HandymanDetailPageState();
}

class _HandymanDetailPageState extends State<HandymanDetailPage> {
  UserModel? _user;
  HandymanProfileModel? _profile;
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
      final profile = await api.getHandymanProfileByUserId(widget.userId);
      if (mounted) setState(() {
        _user = user;
        _profile = profile;
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
      appBar: AppBar(title: const Text('Handyman detail')),
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
                          onPressed: _load, child: const Text('Retry')),
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
                          const Text('User',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Name: ${_user!.name ?? '—'}'),
                          Text('Email: ${_user!.email ?? '—'}'),
                          Text('Phone: ${_user!.phone ?? '—'}'),
                          Text('Status: ${_user!.status ?? '—'}'),
                          if (_profile != null) ...[
                            const SizedBox(height: 24),
                            const Text('Handyman profile',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('Skills: ${_profile!.skills ?? '—'}'),
                            Text('Service type: ${_profile!.serviceType ?? '—'}'),
                            Text(
                                'Hourly rate: ${_profile!.hourlyRate?.toString() ?? '—'}'),
                            Text(
                                'Verified: ${_profile!.isVerified == true ? 'Yes' : 'No'}'),
                            Text(
                                'Available: ${_profile!.isAvailable == true ? 'Yes' : 'No'}'),
                            if (_profile!.bio != null)
                              Text('Bio: ${_profile!.bio}'),
                          ],
                          const SizedBox(height: 24),
                          const Text('Actions',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_user!.status != UserStatusConstants.active)
                                ElevatedButton(
                                  onPressed: () => _updateStatus(
                                      UserStatusConstants.active),
                                  child: const Text('Approve / Verify'),
                                ),
                              if (_user!.status !=
                                  UserStatusConstants.suspended)
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
