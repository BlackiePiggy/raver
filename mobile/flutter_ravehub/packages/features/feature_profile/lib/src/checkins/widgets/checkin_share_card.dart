import 'package:flutter/material.dart';

class CheckinShareCard extends StatelessWidget {
  const CheckinShareCard({
    super.key,
    required this.title,
    required this.totalLabel,
    required this.eventsLabel,
    required this.djsLabel,
    required this.daysLabel,
    required this.shortUrl,
  });

  final String title;
  final String totalLabel;
  final String eventsLabel;
  final String djsLabel;
  final String daysLabel;
  final String shortUrl;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF33D6A6);
    const violet = Color(0xFF8B5CF6);
    return Container(
      width: 390,
      height: 520,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1718), Color(0xFF18122A), Color(0xFF05050A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.42), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'RAVEHUB CHECK-INS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          _MetricGrid(
            totalLabel: totalLabel,
            eventsLabel: eventsLabel,
            djsLabel: djsLabel,
            daysLabel: daysLabel,
            accent: accent,
            violet: violet,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              shortUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'RAVEHUB',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.totalLabel,
    required this.eventsLabel,
    required this.djsLabel,
    required this.daysLabel,
    required this.accent,
    required this.violet,
  });

  final String totalLabel;
  final String eventsLabel;
  final String djsLabel;
  final String daysLabel;
  final Color accent;
  final Color violet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(label: totalLabel, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(label: eventsLabel, color: violet),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(label: djsLabel, color: violet),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(label: daysLabel, color: accent),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
