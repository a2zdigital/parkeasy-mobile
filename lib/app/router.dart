import 'package:app/app/routes.dart';
import 'package:app/app/tab_shell.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/auth/ui/launch_screen.dart';
import 'package:app/features/auth/ui/otp_screen.dart';
import 'package:app/features/auth/ui/phone_screen.dart';
import 'package:app/features/auth/ui/start_up_screen.dart';
import 'package:app/features/booking/state/booking_draft.dart';
import 'package:app/features/booking/ui/booking_details_screen.dart';
import 'package:app/features/booking/ui/bookings_screen.dart';
import 'package:app/features/booking/ui/choose_time_screen.dart';
import 'package:app/features/booking/ui/review_screen.dart';
import 'package:app/features/notifications/ui/activity_screen.dart';
import 'package:app/features/owner/ui/facility_form_screen.dart';
import 'package:app/features/owner/ui/facility_screen.dart';
import 'package:app/features/owner/ui/hours_form_screen.dart';
import 'package:app/features/owner/ui/owner_application_screen.dart';
import 'package:app/features/owner/ui/owner_booking_screen.dart';
import 'package:app/features/owner/ui/owner_bookings_screen.dart';
import 'package:app/features/owner/ui/owner_earnings_screen.dart';
import 'package:app/features/owner/ui/owner_facilities_screen.dart';
import 'package:app/features/owner/ui/pool_form_screen.dart';
import 'package:app/features/parking_lot/ui/parking_lot_screen.dart';
import 'package:app/features/payment/ui/payment_screen.dart';
import 'package:app/features/profile/ui/complete_profile_screen.dart';
import 'package:app/features/profile/ui/edit_profile_screen.dart';
import 'package:app/features/profile/ui/profile_screen.dart';
import 'package:app/features/search/ui/explore_screen.dart';
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
    ..listen(sessionControllerProvider, (previous, next) {
      final routingChanged = switch ((previous, next)) {
        (SignedIn(user: final a), SignedIn(user: final b)) =>
          a.isProfileComplete != b.isProfileComplete,
        _ => previous?.runtimeType != next.runtimeType,
      };
      if (routingChanged) {
        sessionChanged.value = next;
      }
    })
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
                        routes: [
                          GoRoute(
                            path: 'review',
                            // Without the choice there is nothing to review.
                            redirect: (context, state) =>
                                state.extra is BookingDraft
                                ? null
                                : Routes.chooseTime(
                                    state.pathParameters['id']!,
                                  ),
                            builder: (context, state) => ReviewScreen(
                              draft: state.extra! as BookingDraft,
                            ),
                          ),
                        ],
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
                builder: (context, state) => const BookingsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        BookingDetailsScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'pay',
                        builder: (context, state) => PaymentScreen(
                          bookingId: state.pathParameters['id']!,
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
                path: Routes.activity,
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.owner,
        builder: (context, state) => const OwnerApplicationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            OwnerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerBookings,
                builder: (context, state) => const OwnerBookingsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        OwnerBookingScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ownerFacilities,
                builder: (context, state) => const OwnerFacilitiesScreen(),
                routes: [
                  // Before ':id', so "new" is not read as an ID.
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const FacilityFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        FacilityScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => FacilityFormScreen(
                          facilityId: state.pathParameters['id'],
                        ),
                      ),
                      GoRoute(
                        path: 'hours',
                        builder: (context, state) => HoursFormScreen(
                          facilityId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'pools/:poolId',
                        builder: (context, state) {
                          final poolId = state.pathParameters['poolId'];
                          return PoolFormScreen(
                            facilityId: state.pathParameters['id']!,
                            poolId: poolId == 'new' ? null : poolId,
                          );
                        },
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
                path: Routes.ownerEarnings,
                builder: (context, state) => const OwnerEarningsScreen(),
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
