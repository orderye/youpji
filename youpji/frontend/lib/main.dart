import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/theme_constants.dart';
import 'views/home/home_page.dart';
import 'views/plan/plan_page.dart';
import 'views/itinerary/detail_page.dart';
import 'views/chat/chat_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: YoupjiApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/plan',
      builder: (context, state) => const PlanPage(),
    ),
    GoRoute(
      path: '/itinerary/detail',
      builder: (context, state) => const ItineraryDetailPage(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatPage(),
    ),
  ],
);

class YoupjiApp extends StatelessWidget {
  const YoupjiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '游迹 · 贵州旅游',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
