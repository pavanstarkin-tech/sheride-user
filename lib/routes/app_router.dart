import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/about_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/rewards_screen.dart';
import '../features/profile/presentation/saved_places_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/rides/domain/ride_model.dart';
import '../features/rides/presentation/destination_search_screen.dart';
import '../features/rides/presentation/live_tracking_screen.dart';
import '../features/rides/presentation/ride_completed_screen.dart';
import '../features/rides/presentation/ride_history_screen.dart';
import '../features/rides/presentation/ride_selection_screen.dart';
import '../features/rides/presentation/rider_assigned_screen.dart';
import '../features/rides/presentation/searching_rider_screen.dart';
import '../features/rides/presentation/travel_screen.dart';
import '../features/rides/presentation/trip_details_screen.dart';
import '../features/safety/presentation/emergency_contacts_screen.dart';
import '../features/safety/presentation/safety_center_screen.dart';
import '../features/services/presentation/services_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            verificationId: extra['verificationId'] ?? '',
            phoneNumber: extra['phoneNumber'] ?? '',
            resendToken: extra['resendToken'],
          );
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RegisterScreen(
            uid: extra['uid'] ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
            phone: extra['phone'] ?? '+919876543210',
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: '/travel',
        builder: (context, state) => const TravelScreen(),
      ),
      GoRoute(
        path: '/destination-search',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return DestinationSearchScreen(
            initialPickup: extra['pickup'] as LocationPoint?,
          );
        },
      ),
      GoRoute(
        path: '/ride-selection',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RideSelectionScreen(
            pickup: extra['pickup'] as LocationPoint? ??
                const LocationPoint(lat: 17.3850, lng: 78.4867, address: 'Current Location'),
            drop: extra['drop'] as LocationPoint? ??
                const LocationPoint(lat: 17.3980, lng: 78.4980, address: 'Destination'),
          );
        },
      ),
      GoRoute(
        path: '/searching-rider',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final ride = extra['ride'] as RideModel? ??
              RideModel(
                rideId: 'ride_demo',
                userId: 'user_1',
                pickup: const LocationPoint(lat: 17.3850, lng: 78.4867, address: 'Pickup Location'),
                drop: const LocationPoint(lat: 17.3980, lng: 78.4980, address: 'Destination'),
                vehicleType: 'scooty',
                fare: 48,
                distanceKm: 3.2,
                durationMin: 11,
                otp: '4829',
              );
          return SearchingRiderScreen(ride: ride);
        },
      ),
      GoRoute(
        path: '/rider-assigned',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final ride = extra['ride'] as RideModel? ??
              RideModel(
                rideId: '',
                userId: '',
                pickup: const LocationPoint(lat: 0, lng: 0, address: ''),
                drop: const LocationPoint(lat: 0, lng: 0, address: ''),
                vehicleType: 'scooty',
                fare: 0,
                distanceKm: 0,
                durationMin: 0,
                otp: '',
              );
          return RiderAssignedScreen(ride: ride);
        },
      ),
      GoRoute(
        path: '/live-tracking',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final ride = extra['ride'] as RideModel? ??
              RideModel(
                rideId: '',
                userId: '',
                pickup: const LocationPoint(lat: 0, lng: 0, address: ''),
                drop: const LocationPoint(lat: 0, lng: 0, address: ''),
                vehicleType: 'scooty',
                fare: 0,
                distanceKm: 0,
                durationMin: 0,
                otp: '',
              );
          return LiveTrackingScreen(ride: ride);
        },
      ),
      GoRoute(
        path: '/ride-completed',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final ride = extra['ride'] as RideModel? ??
              RideModel(
                rideId: '',
                userId: '',
                pickup: const LocationPoint(lat: 0, lng: 0, address: ''),
                drop: const LocationPoint(lat: 0, lng: 0, address: ''),
                vehicleType: 'scooty',
                fare: 0,
                distanceKm: 0,
                durationMin: 0,
                otp: '',
              );
          return RideCompletedScreen(ride: ride);
        },
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/ride-history',
        builder: (context, state) => const RideHistoryScreen(),
      ),
      GoRoute(
        path: '/trip-details',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final ride = extra['ride'] as RideModel? ??
              RideModel(
                rideId: 'demo',
                userId: 'user',
                pickup: const LocationPoint(lat: 17.3850, lng: 78.4867, address: 'Pickup'),
                drop: const LocationPoint(lat: 17.3980, lng: 78.4980, address: 'Drop'),
                vehicleType: 'electric_scooty',
                fare: 48,
                distanceKm: 3.2,
                durationMin: 11,
                otp: '4829',
              );
          return TripDetailsScreen(ride: ride);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/saved-places',
        builder: (context, state) => const SavedPlacesScreen(),
      ),
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/safety-center',
        builder: (context, state) => const SafetyCenterScreen(),
      ),
      GoRoute(
        path: '/emergency-contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
