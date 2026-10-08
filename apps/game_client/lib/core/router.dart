import 'package:game_client/features/match/match_page.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:game_client/features/menu/home_page.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(
      path: '/match',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return MatchPage(
          mode: q['mode'] == 'training' ? MatchMode.training : MatchMode.arena,
          classId: int.tryParse(q['class'] ?? '') ?? 0,
        );
      },
    ),
  ],
);
