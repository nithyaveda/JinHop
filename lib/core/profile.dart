// Player profile and the form validators used by Login, Register and
// Edit profile. PURE DART (unit-tested in test/core/profile_test.dart).
//
// Practical 1 keeps the profile on the device; no passwords are stored.
// Practical 2 replaces this with a real database and authentication.

/// The player's profile (the item edited on the Edit profile screen).
class PlayerProfile {
  final String name;
  final String email;
  final String motto;

  /// 1 = Misty Pond, 2 = Lantern Marsh.
  final int favouriteWorld;
  final bool guest;

  const PlayerProfile({
    required this.name,
    this.email = '',
    this.motto = '',
    this.favouriteWorld = 1,
    this.guest = false,
  });

  PlayerProfile copyWith({String? name, String? email, String? motto, int? favouriteWorld, bool? guest}) =>
      PlayerProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        motto: motto ?? this.motto,
        favouriteWorld: favouriteWorld ?? this.favouriteWorld,
        guest: guest ?? this.guest,
      );

  /// First letter of the name, for the round avatar.
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Required, must look like name@example.com.
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Please enter your email';
  if (!_emailPattern.hasMatch(v)) return 'Enter a valid email, e.g. name@example.com';
  return null;
}

/// Required, 6+ characters with at least one letter and one number.
String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Please enter your password';
  if (v.length < 6) return 'Password must be at least 6 characters';
  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
    return 'Use at least one letter and one number';
  }
  return null;
}

/// The confirm field must match the password typed above it.
String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) return 'Please confirm your password';
  if (value != password) return 'Passwords do not match';
  return null;
}

/// Required, 2 to 20 characters.
String? validateName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Please enter a player name';
  if (v.length < 2) return 'Name is too short (at least 2 characters)';
  if (v.length > 20) return 'Name is too long (20 characters max)';
  return null;
}

/// Optional, at most 40 characters.
String? validateMotto(String? value) {
  if ((value ?? '').trim().length > 40) return 'Keep your motto under 40 characters';
  return null;
}
