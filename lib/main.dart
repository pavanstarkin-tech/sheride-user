import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/services/mapbox_service.dart';
import 'core/services/network_service.dart';
import 'core/services/storage_service.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/rides/data/destination_preload_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production Global Error Boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[SheRide User Error Boundary] ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[SheRide User Async Exception] $error');
    return true; // Handled
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final storageService = StorageService();
  await storageService.init();

  NetworkService().initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully with sheride-1");
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  MapboxService.initMapbox();
  await NotificationService.initializeLocalNotifications();

  // Kick off background preload of destination places & image galleries immediately
  DestinationPreloadService().startBackgroundPreload();

  runApp(const SheRideUserApp());
}
