import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/service_request_detail_page.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/widgets/service_request_card.dart';

class HandymanRequestsTab extends StatefulWidget {
  const HandymanRequestsTab({super.key});

  @override
  State<HandymanRequestsTab> createState() => _HandymanRequestsTabState();
}

class _HandymanRequestsTabState extends State<HandymanRequestsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];
  int? _acceptingId;
  int? _decliningId;

  static int? _requestId(Map<String, dynamic> r) {
    final id = r['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final list = await api.getHandymanServiceRequests();
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _requests = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(int requestId) async {
    setState(() => _acceptingId = requestId);
    try {
      final api = getIt<ApiService>();
      await api.acceptHandymanServiceRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  Future<void> _declineRequest(int requestId) async {
    setState(() => _decliningId = requestId);
    try {
      final api = getIt<ApiService>();
      await api.declineHandymanServiceRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request declined'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _requests.removeWhere((r) => _requestId(r) == requestId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _decliningId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRequests,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _requests.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25),
                        Icon(Icons.assignment_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No available service requests',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        return ServiceRequestCard(
                          request: request,
                          showActions: true,
                          onAccept: _acceptRequest,
                          onDecline: _declineRequest,
                          isAccepting: _acceptingId == _requestId(request),
                          isDeclining: _decliningId == _requestId(request),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServiceRequestDetailPage(
                                  request: request,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
