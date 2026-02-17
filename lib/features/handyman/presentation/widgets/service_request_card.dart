import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

/// Reusable card for a service request (used in requests tab and home tab recent services).
class ServiceRequestCard extends StatelessWidget {
  const ServiceRequestCard({
    super.key,
    required this.request,
    this.showActions = false,
    this.onAccept,
    this.onDecline,
    this.isAccepting = false,
    this.isDeclining = false,
    this.onTap,
  });

  final Map<String, dynamic> request;
  final bool showActions;
  final void Function(int requestId)? onAccept;
  final void Function(int requestId)? onDecline;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback? onTap;

  static int? _requestId(Map<String, dynamic> r) {
    final id = r['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  static Color _statusColor(String status) {
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

  @override
  Widget build(BuildContext context) {
    final serviceType = request['service_type']?.toString() ?? 'Service';
    final clientName = request['client_name']?.toString() ?? request['customer']?['name']?.toString() ?? '—';
    final address = request['address']?.toString() ?? request['location']?.toString() ?? '—';
    final status = request['status']?.toString() ?? '';
    final estimatedPay = request['estimated_pay']?.toString() ?? request['amount']?.toString() ?? '—';
    final id = _requestId(request);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ?? (id != null && showActions ? () {} : null),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      serviceType.isNotEmpty
                          ? '${serviceType[0].toUpperCase()}${serviceType.substring(1)}'
                          : 'Service',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AuthColors.title,
                      ),
                    ),
                  ),
                  if (status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clientName,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Est. pay',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    estimatedPay.startsWith(r'$') ? estimatedPay : '\$$estimatedPay',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.title,
                    ),
                  ),
                ],
              ),
              if (showActions && onAccept != null && onDecline != null && id != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeclining ? null : () => onDecline!(id),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isDeclining
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isAccepting ? null : () => onAccept!(id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuthColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: isAccepting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
