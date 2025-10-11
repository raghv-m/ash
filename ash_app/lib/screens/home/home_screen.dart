import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/home/quick_actions.dart';
import '../../widgets/home/upcoming_events.dart';
import '../../widgets/home/ash_greeting.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome back, ${user?.name.split(' ').first ?? 'User'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => AppRouter.pushNamed(context, AppRouter.tutorial),
            tooltip: 'Tutorial',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => AppRouter.pushNamed(context, AppRouter.settings),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ASH Greeting
                  const ASHGreeting(),
                  
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const QuickActions(),
                  
                  const SizedBox(height: 32),
                  
                  // Upcoming Events
                  Text(
                    'Upcoming Events',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const UpcomingEvents(),
                  
                  const SizedBox(height: 32),
                  
                  // Chat with ASH Button
                  Center(
                    child: CustomButton(
                      onPressed: () => AppRouter.pushNamed(context, AppRouter.chat),
                      text: 'Chat with ASH',
                      icon: Icons.chat,
                      width: 200,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              AppRouter.pushNamed(context, AppRouter.calendar);
              break;
            case 2:
              AppRouter.pushNamed(context, AppRouter.chat);
              break;
            case 3:
              AppRouter.pushNamed(context, AppRouter.settings);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

