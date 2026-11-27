import 'package:app/features/auth/state/registration_role.dart';
import 'package:app/features/auth/state/session_state.dart';

/// Every location in the app. Screens navigate by these, never by typing
/// a path or importing another feature's screen.
abstract final class Routes {
  static const String startUp = '/';
  static const String launch = '/welcome';
  static const String phone = '/sign-in/phone';
  static const String code = '/sign-in/code';
  static const String registrationRole = '/register/role';
  static const String registrationPhone = '/register/phone';
  static const String completeProfile = '/complete-profile';
  static const String explore = '/explore';
  static const String bookings = '/bookings';
  static const String activity = '/activity';
  static const String profile = '/profile';
  static const String profileEdit = '$profile/edit';
  static const String profileHelp = '$profile/help';

  /// The gate, for someone an owner made an attendant.
  static const String gate = '$profile/gate';

  /// A facility's details. The ID is the public, opaque one.
  static String parkingLot(String id) => '$explore/lots/$id';

  /// Choosing a vehicle type and a window at a facility.
  static String chooseTime(String id) => '${parkingLot(id)}/time';

  /// Reviewing the choice before booking. The choice travels in memory.
  static String review(String id) => '${chooseTime(id)}/review';

  /// One of the customer's bookings.
  static String booking(String id) => '$bookings/$id';

  /// Paying for a booking online.
  static String pay(String id) => '${booking(id)}/pay';

  /// The way into the owner area: apply, or see the application.
  static const String owner = '/owner';
  static const String ownerBookings = '/owner/bookings';
  static const String ownerFacilities = '/owner/facilities';
  static const String ownerEarnings = '/owner/earnings';
  static const String ownerActivity = '/owner/activity';
  static const String ownerProfile = '/owner/profile';
  static const String ownerProfileEdit = '$ownerProfile/edit';
  static const String ownerProfileHelp = '$ownerProfile/help';
  static const String ownerProfileDocuments = '$ownerProfile/documents';
  static const String ownerProfileGst = '$ownerProfile/gst';

  static const String ownerFacilityNew = '$ownerFacilities/new';

  /// One of the owner's facilities, with everything that sets it up.
  static String ownerFacility(String id) => '$ownerFacilities/$id';
  static String ownerFacilityEdit(String id) => '${ownerFacility(id)}/edit';
  static String ownerFacilityHours(String id) => '${ownerFacility(id)}/hours';

  /// Adding spaces for a vehicle type, or editing a pool when [poolId] is
  /// given.
  static String ownerFacilityPool(String id, {String? poolId}) =>
      '${ownerFacility(id)}/pools/${poolId ?? 'new'}';

  /// A booking at one of the owner's facilities.
  static String ownerBooking(String id) => '$ownerBookings/$id';

  /// Gate check-in by the customer's code, opened from that booking.
  static String ownerBookingCheckOut(String id) =>
      '${ownerBookingCheckIn(id)}?out=1';
  static String ownerBookingCheckIn(String id) =>
      '${ownerBooking(id)}/check-in';

  /// A numbered pool's bays.
  static String ownerPoolSpaces(String facilityId, String poolId) =>
      '${ownerFacilityPool(facilityId, poolId: poolId)}/spaces';

  static const Set<String> _signedOut = {
    launch,
    phone,
    code,
    registrationRole,
    registrationPhone,
  };

  /// What a guest may see without an account: search and a facility's
  /// public details. Choosing a time, booking and everything personal
  /// needs sign-in.
  static bool isGuestBrowsable(String location) =>
      location == explore ||
      RegExp(r'^/explore/lots/[^/]+$').hasMatch(location);

  /// A customer location worth returning to after signing in.
  static bool isReturnable(String location) =>
      location.startsWith(explore) ||
      location.startsWith(bookings) ||
      location.startsWith(activity) ||
      location.startsWith(profile);

  /// Where the session allows the user to be. Returns the location to go
  /// to instead of [location], or null to stay.
  ///
  /// [returnTo] is where a guest was going when they were asked to sign
  /// in; a signed-in customer arriving from the sign-in screens goes there.
  ///
  /// A pure function of its inputs, so the whole access policy of the app
  /// is tested without building a widget.
  static String? redirect(
    SessionState session,
    String location, {
    String? returnTo,
  }) {
    switch (session) {
      case SessionUnknown() || SessionRestoreFailed():
        return location == startUp ? null : startUp;

      case SignedOut():
        return _signedOut.contains(location) || isGuestBrowsable(location)
            ? null
            : launch;

      case SignedIn(:final user, :final registrationRole):
        if (!user.isProfileComplete) {
          return location == completeProfile ? null : completeProfile;
        }

        if (user.isOwner) {
          if (location == owner) return ownerBookings;
          if (_isOwnerRoute(location) ||
              location == ownerProfile ||
              location == ownerProfileEdit) {
            return null;
          }
          return ownerBookings;
        }

        if (registrationRole == RegistrationRole.owner) {
          return location == owner ? null : owner;
        }

        // The application page itself is open to anyone signed in (anyone
        // may apply, and an applicant comes back to see it); the owner
        // modules behind it need the owner role.
        if (_isOwnerRoute(location) && location != owner) {
          return explore;
        }
        final isOutside =
            location == startUp ||
            location == completeProfile ||
            _signedOut.contains(location);
        // Back to what a guest was doing when sign-in was needed; the
        // router forgets it once used.
        if (returnTo != null &&
            isReturnable(returnTo) &&
            location != returnTo) {
          return returnTo;
        }
        return isOutside ? explore : null;
    }
  }

  static bool _isOwnerRoute(String location) =>
      location == owner || location.startsWith('$owner/');
}
