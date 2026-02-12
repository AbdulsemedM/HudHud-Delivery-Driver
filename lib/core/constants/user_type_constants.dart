/// User type values matching the backend users table.
/// Same users table; distinction is by [UserModel.type].
class UserTypeConstants {
  UserTypeConstants._();

  static const String customer = 'customer';
  static const String driver = 'driver';
  static const String courier = 'courier';
  static const String handyman = 'handyman';
  static const String vendor = 'vendor';
  static const String admin = 'admin';

  /// Types that the admin app manages (list, create, approve, suspend).
  static const List<String> managedTypes = [driver, courier, handyman];

  static bool isManagedType(String? type) =>
      type != null && managedTypes.contains(type);

  static bool isAdmin(String? type) => type == admin;
}
