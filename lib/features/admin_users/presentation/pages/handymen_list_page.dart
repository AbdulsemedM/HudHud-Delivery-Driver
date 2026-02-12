import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/user_model.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/admin_users/presentation/pages/handyman_detail_page.dart';
import 'package:hudhud_delivery_driver/features/admin_users/presentation/pages/create_user_page.dart';

class HandymenListPage extends StatefulWidget {
  const HandymenListPage({super.key});

  @override
  State<HandymenListPage> createState() => _HandymenListPageState();
}

class _HandymenListPageState extends State<HandymenListPage> {
  List<UserModel> _list = [];
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
      final list = await api.listUsersByType(UserTypeConstants.handyman);
      if (mounted) setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handymen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => CreateUserPage(
                    userType: UserTypeConstants.handyman,
                    title: 'Create Handyman',
                  ),
                ),
              );
              if (created == true) _load();
            },
          ),
        ],
      ),
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
              : _list.isEmpty
                  ? const Center(child: Text('No handymen yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final u = _list[i];
                          return ListTile(
                            title: Text(u.name ?? '—'),
                            subtitle: Text(u.email ?? u.phone ?? '—'),
                            trailing: Chip(
                              label: Text(
                                u.status ?? '—',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            onTap: () async {
                              final updated = await Navigator.of(context)
                                  .push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => HandymanDetailPage(
                                    userId: u.id!,
                                  ),
                                ),
                              );
                              if (updated == true) _load();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
