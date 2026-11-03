/// The user's onboarding choice. The API remains authoritative for roles.
enum RegistrationRole {
  customer('customer'),
  owner('owner');

  const RegistrationRole(this.storageValue);

  final String storageValue;

  static RegistrationRole? fromStorageValue(String? value) => switch (value) {
    'customer' => customer,
    'owner' => owner,
    _ => null,
  };
}
