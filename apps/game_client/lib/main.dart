import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_client/core/router.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Battle Game',
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      );
}
