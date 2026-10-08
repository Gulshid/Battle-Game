import 'package:game_client/features/match/match_page.dart';
import 'package:game_client/features/menu/home_page.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/match', builder: (_, __) => const MatchPage()),
  ],
);
