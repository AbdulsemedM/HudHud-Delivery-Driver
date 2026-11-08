import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

/// Already-translated text for [FoodOfferCard] (keeps the widget free of
/// localization so it is easy to test).
class FoodOfferCardText {
  const FoodOfferCardText({
    required this.title,
    required this.pickupDistance,
    required this.dropoff,
    required this.earnings,
    required this.accept,
    required this.decline,
    required this.expired,
    required this.cash,
    required this.gift,
    required this.stillCooking,
    required this.secondsUnit,
    required this.items,
  });

  /// "New order offer"
  final String title;

  /// "{km} km to pickup" with `{km}` replaced by the card.
  final String pickupDistance;

  /// "Drop-off"
  final String dropoff;

  /// "You earn"
  final String earnings;
  final String accept;
  final String decline;

  /// "Offer expired"
  final String expired;

  /// "Cash order — collect {amount}" style badge text ("Cash order").
  final String cash;
  final String gift;

  /// "Still cooking — arrive as it is ready"
  final String stillCooking;

  /// "s" (seconds suffix under the countdown)
  final String secondsUnit;

  /// "{count} items" with `{count}` replaced by the card.
  final String items;

  static const FoodOfferCardText english = FoodOfferCardText(
    title: 'New order offer',
    pickupDistance: '{km} km to pickup',
    dropoff: 'Drop-off',
    earnings: 'You earn',
    accept: 'Accept',
    decline: 'Decline',
    expired: 'Offer expired',
    cash: 'Cash order',
    gift: 'Gift',
    stillCooking: 'Still cooking — you will arrive as it is ready',
    secondsUnit: 's',
    items: '{count} items',
  );
}

/// Full-screen system-dispatch offer: countdown, restaurant, distance to
/// pickup, drop-off area, earnings (in the order's currency), Accept /
/// Decline. Calls [onExpired] once when the countdown reaches zero.
class FoodOfferCard extends StatefulWidget {
  const FoodOfferCard({
    super.key,
    required this.offer,
    required this.text,
    required this.onAccept,
    required this.onDecline,
    this.onExpired,
    this.busy = false,
    this.clock,
  });

  final FoodDispatchOffer offer;
  final FoodOfferCardText text;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onExpired;

  /// Disables both buttons while a request is in flight.
  final bool busy;

  /// Overridable for tests; defaults to [DateTime.now].
  final DateTime Function()? clock;

  static const Color brandOrange = Color(0xFFF55905);

  @override
  State<FoodOfferCard> createState() => _FoodOfferCardState();
}

class _FoodOfferCardState extends State<FoodOfferCard> {
  Timer? _timer;
  bool _expiredNotified = false;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_expiredNotified && widget.offer.isExpired(_now())) {
      _expiredNotified = true;
      _timer?.cancel();
      widget.onExpired?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final text = widget.text;
    final now = _now();
    final left = offer.secondsLeft(now);
    final expired = left <= 0;
    final urgent = left <= 10;
    final ringColor = expired
        ? Colors.grey
        : (urgent ? Colors.red.shade600 : FoodOfferCard.brandOrange);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      key: const ValueKey('food-offer-ring'),
                      value: offer.remainingFraction(now),
                      strokeWidth: 9,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                    Center(
                      child: expired
                          ? Text(
                              text.expired,
                              key: const ValueKey('food-offer-expired'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$left',
                                  key: const ValueKey('food-offer-seconds'),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: ringColor,
                                  ),
                                ),
                                Text(
                                  text.secondsUnit,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _RestaurantTile(offer: offer, text: text),
                  const SizedBox(height: 10),
                  if (offer.dropoffArea != null)
                    _Row(
                      icon: Icons.location_on_outlined,
                      label: text.dropoff,
                      value: offer.dropoffArea!,
                    ),
                  const SizedBox(height: 10),
                  _EarningsTile(offer: offer, label: text.earnings),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (offer.isCash)
                        _Badge(
                          key: const ValueKey('food-offer-cash'),
                          icon: Icons.payments_outlined,
                          text: text.cash,
                        ),
                      if (offer.isGift)
                        _Badge(
                          key: const ValueKey('food-offer-gift'),
                          icon: Icons.card_giftcard,
                          text: text.gift,
                        ),
                      if (offer.itemsCount > 0)
                        _Badge(
                          icon: Icons.shopping_bag_outlined,
                          text: text.items
                              .replaceAll('{count}', '${offer.itemsCount}'),
                        ),
                    ],
                  ),
                  if (offer.waitingForFood) ...[
                    const SizedBox(height: 12),
                    Text(
                      text.stillCooking,
                      key: const ValueKey('food-offer-still-cooking'),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      key: const ValueKey('food-offer-decline'),
                      onPressed:
                          widget.busy || expired ? null : widget.onDecline,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(text.decline,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      key: const ValueKey('food-offer-accept'),
                      onPressed:
                          widget.busy || expired ? null : widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FoodOfferCard.brandOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: widget.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              text.accept,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({required this.offer, required this.text});

  final FoodDispatchOffer offer;
  final FoodOfferCardText text;

  @override
  Widget build(BuildContext context) {
    final km = offer.pickupDistanceKm;
    final kmText =
        km == null ? null : AppCurrency.formatDecimal(km, fractionDigits: 1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined,
              color: FoodOfferCard.brandOrange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.restaurantName ?? offer.displayNumber,
                  key: const ValueKey('food-offer-restaurant'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (offer.restaurantAddress != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    offer.restaurantAddress!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
                if (kmText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    text.pickupDistance.replaceAll('{km}', kmText),
                    key: const ValueKey('food-offer-distance'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  const _EarningsTile({required this.offer, required this.label});

  final FoodDispatchOffer offer;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (offer.earningsEstimate == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            AppCurrency.format(
              offer.earningsEstimate,
              currency: offer.currency,
            ),
            key: const ValueKey('food-offer-earnings'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: FoodOfferCard.brandOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                value,
                key: const ValueKey('food-offer-dropoff'),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade800),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
