import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/theme_constants.dart';
import 'views/main_navigation_screen.dart';
import 'views/plan/plan_page.dart';
import 'views/itinerary/detail_page.dart';
import 'views/itinerary/itinerary_list_page.dart';
import 'views/explore/explore_page.dart';
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
      builder: (context, state) => const MainNavigationScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/explore',
      builder: (context, state) => const MainNavigationScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/itineraries',
      builder: (context, state) => const MainNavigationScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/plan',
      builder: (context, state) {
        final origin = state.uri.queryParameters['origin'];
        final dest = state.uri.queryParameters['destination'];
        return PlanPage(initialOrigin: origin, initialDestination: dest);
      },
    ),
    GoRoute(
      path: '/itinerary/detail',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'];
        return ItineraryDetailPage(itineraryId: id);
      },
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
