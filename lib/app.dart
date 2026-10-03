import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

import 'core/widgets/offline_banner.dart';

class SheRideUserApp extends StatelessWidget {
  const SheRideUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp.router(
        title: 'SheRide User',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          return OfflineBanner(child: child ?? const SizedBox());
        },
      ),
    );
  }
}
