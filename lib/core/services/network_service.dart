import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void initialize() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (isOnline.value != hasConnection) {
        isOnline.value = hasConnection;
        debugPrint('[NetworkService] Connectivity changed: isOnline=$hasConnection');
      }
    });

    _connectivity.checkConnectivity().then((results) {
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    }).catchError((_) {
      isOnline.value = true;
    });
  }

  void dispose() {
    _subscription?.cancel();
    isOnline.dispose();
  }
}
