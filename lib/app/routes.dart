import 'package:app/features/auth/state/session_state.dart';

/// Every location in the app. Screens navigate by these, never by typing
/// a path or importing another feature's screen.
abstract final class Routes {
  static const String startUp = '/';
  static const String launch = '/welcome';
  static const String phone = '/sign-in/phone';
  static const String code = '/sign-in/code';
  static const String completeProfile = '/complete-profile';
  static const String explore = '/explore';
  static const String bookings = '/bookings';
  static const String activity = '/activity';
  static const String profile = '/profile';

  /// A facility's details. The ID is the public, opaque one.
  static String parkingLot(String id) => '$explore/lots/$id';

  /// Choosing a vehicle type and a window at a facility.
  static String chooseTime(String id) => '${parkingLot(id)}/time';

  /// Reviewing the choice before booking. The choice travels in memory.
  static String review(String id) => '${chooseTime(id)}/review';

  /// One of the customer's bookings.
  static String booking(String id) => '$bookings/$id';

  static const Set<String> _signedOut = {launch, phone, code};

  /// Where the session allows the user to be. Returns the location to go
  /// to instead of [location], or null to stay.
  ///
  /// A pure function of its inputs, so the whole access policy of the app
  /// is tested without building a widget.
  static String? redirect(SessionState session, String location) {
    switch (session) {
      case SessionUnknown() || SessionRestoreFailed():
        return location == startUp ? null : startUp;

      case SignedOut():
        return _signedOut.contains(location) ? null : launch;

      case SignedIn(:final user):
        if (!user.isProfileComplete) {
          return location == completeProfile ? null : completeProfile;
        }
        final isOutside =
            location == startUp ||
            location == completeProfile ||
            _signedOut.contains(location);
        return isOutside ? explore : null;
    }
  }
}
