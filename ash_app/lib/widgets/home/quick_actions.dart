import 'package:flutter/material.dart';

import '../../core/routing/app_router.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildActionCard(
          context: context,
          icon: Icons.add,
          title: 'Schedule Meeting',
          subtitle: 'Book a new meeting',
          color: theme.colorScheme.primary,
          onTap: () => AppRouter.pushNamed(context, AppRouter.chat),
        ),
        _buildActionCard(
          context: context,
          icon: Icons.calendar_today,
          title: 'View Calendar',
          subtitle: 'See your schedule',
          color: theme.colorScheme.secondary,
          onTap: () => AppRouter.pushNamed(context, AppRouter.calendar),
        ),
        _buildActionCard(
          context: context,
          icon: Icons.voice_chat,
          title: 'Voice Command',
          subtitle: 'Speak to ASH',
          color: Colors.orange,
          onTap: () => AppRouter.pushNamed(context, AppRouter.chat),
        ),
        _buildActionCard(
          context: context,
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Manage preferences',
          color: Colors.grey,
          onTap: () => AppRouter.pushNamed(context, AppRouter.settings),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

