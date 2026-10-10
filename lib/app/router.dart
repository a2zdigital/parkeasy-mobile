import 'package:app/app/customer_shell.dart';
import 'package:app/app/not_built_screen.dart';
import 'package:app/app/routes.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/auth/ui/launch_screen.dart';
import 'package:app/features/auth/ui/otp_screen.dart';
import 'package:app/features/auth/ui/phone_screen.dart';
import 'package:app/features/auth/ui/start_up_screen.dart';
import 'package:app/features/booking/ui/choose_time_screen.dart';
import 'package:app/features/parking_lot/ui/parking_lot_screen.dart';
import 'package:app/features/profile/ui/complete_profile_screen.dart';
import 'package:app/features/profile/ui/profile_screen.dart';
import 'package:app/features/search/ui/explore_screen.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever the session changes, so signing in,
  // signing out and an expired token all move the user by themselves.
  final sessionChanged = ValueNotifier<SessionState>(
    ref.read(sessionControllerProvider),
  );
  ref
    ..listen(
      sessionControllerProvider,
      (_, next) => sessionChanged.value = next,
    )
    ..onDispose(sessionChanged.dispose);

  final router = GoRouter(
    initialLocation: Routes.startUp,
    refreshListenable: sessionChanged,
    redirect: (context, state) =>
        Routes.redirect(sessionChanged.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.startUp,
        builder: (context, state) => const StartUpScreen(),
      ),
      GoRoute(
        path: Routes.launch,
        builder: (context, state) => const LaunchScreen(),
      ),
      GoRoute(
        path: Routes.phone,
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: Routes.code,
        // The phone number travels in memory, never in the location.
        redirect: (context, state) =>
            state.extra is CodeSent ? null : Routes.phone,
        builder: (context, state) => OtpScreen(sent: state.extra! as CodeSent),
      ),
      GoRoute(
        path: Routes.completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            CustomerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.explore,
                builder: (context, state) => const ExploreScreen(),
                routes: [
                  GoRoute(
                    path: 'lots/:id',
                    builder: (context, state) =>
                        ParkingLotScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'time',
                        builder: (context, state) => ChooseTimeScreen(
                          lotId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.bookings,
                builder: (context, state) =>
                    NotBuiltScreen(title: context.l10n.tabBookings),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.activity,
                builder: (context, state) =>
                    NotBuiltScreen(title: context.l10n.tabActivity),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
