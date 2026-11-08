import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_quest.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

/// Peak quests (Phase 3 §4): today's progress toward each quest's target.
class QuestsPage extends StatefulWidget {
  const QuestsPage({super.key});

  static const Color brandOrange = Color(0xFFF55905);

  @override
  State<QuestsPage> createState() => _QuestsPageState();
}

class _QuestsPageState extends State<QuestsPage> {
  bool _loading = true;
  bool _disabled = false;
  bool _failed = false;
  List<DriverQuest> _quests = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_quests.isEmpty) setState(() => _loading = true);
    final result = await getIt<ApiService>().getDriverQuests();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk) {
        _quests = result.data!.quests;
        _disabled = false;
        _failed = false;
      } else if (result.isDisabled) {
        _quests = const [];
        _disabled = true;
        _failed = false;
      } else {
        // Transient failure: keep whatever was already shown.
        _failed = true;
      }
    });
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      // Opened from a push notification via `goNamed` — no stack below.
      context.goNamed(AppRouter.deliveryHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _goBack,
        ),
        title: Text(
          'quests.title'.tr(),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_quests.isEmpty) {
      final message = _disabled
          ? 'quests.unavailable'.tr()
          : _failed
              ? 'quests.load_failed'.tr()
              : 'quests.empty'.tr();
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_failed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'quests.load_failed'.tr(),
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        for (final quest in _quests) _QuestCard(quest: quest),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final DriverQuest quest;

  @override
  Widget build(BuildContext context) {
    final reward = quest.rewardLabel;
    final windows = quest.windowsLabel;
    final progressColor =
        quest.rewardedToday ? Colors.green.shade600 : QuestsPage.brandOrange;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: quest.activeNow && !quest.rewardedToday
            ? Border.all(
                color: QuestsPage.brandOrange.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: QuestsPage.brandOrange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quest.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (quest.rewardedToday)
                _badge(
                  label: 'quests.rewarded'.tr(),
                  icon: Icons.check_circle,
                  color: Colors.green.shade700,
                  background: Colors.green.shade50,
                )
              else if (quest.activeNow)
                _badge(
                  label: 'quests.active_now'.tr(),
                  icon: Icons.bolt,
                  color: Colors.white,
                  background: QuestsPage.brandOrange,
                ),
            ],
          ),
          if (quest.description != null) ...[
            const SizedBox(height: 8),
            Text(
              quest.description!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: quest.progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'quests.progress'.tr(
                    namedArgs: {
                      'done': '${quest.completedToday}',
                      'target': '${quest.target}',
                    },
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              Text(
                quest.progressLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (reward.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'quests.reward'.tr(namedArgs: {'amount': reward}),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (windows.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'quests.windows'.tr(namedArgs: {'windows': windows}),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge({
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
