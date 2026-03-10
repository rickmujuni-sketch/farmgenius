import 'package:flutter/material.dart';

import '../legacy_content.dart';

class DashboardHubScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final Widget child;

  const DashboardHubScaffold({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.onLogout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1B5E20),
        actions: [
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DrillDownScaffold(
                    title: 'Legacy',
                    children: [
                      Text(
                        LegacyContent.signboard,
                        style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        LegacyContent.websiteHero,
                        style: TextStyle(height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        LegacyContent.dedication,
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.favorite),
            tooltip: 'Legacy',
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: child,
      ),
    );
  }
}

class HubSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String primaryValue;
  final String secondaryValue;
  final Color color;
  final VoidCallback onTap;

  const HubSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 28),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  primaryValue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  secondaryValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DrillDownScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const DrillDownScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}
