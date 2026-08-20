import 'dart:async';

import 'package:flutter/material.dart';

class OfferExpiryChip extends StatefulWidget {
  const OfferExpiryChip({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });

  final DateTime expiresAt;
  final VoidCallback onExpired;

  static DateTime? tryParse(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  @override
  State<OfferExpiryChip> createState() => _OfferExpiryChipState();
}

class _OfferExpiryChipState extends State<OfferExpiryChip> {
  Timer? _timer;
  bool _expiredNotified = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _notifyIfExpired();
    });
    _notifyIfExpired();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _notifyIfExpired() {
    if (_expiredNotified) return;
    if (!DateTime.now().isAfter(widget.expiresAt)) return;
    _expiredNotified = true;
    widget.onExpired();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return const SizedBox.shrink();
    }
    final label = remaining.inMinutes >= 1
        ? '${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s'
        : '${remaining.inSeconds}s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Offer $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }
}
