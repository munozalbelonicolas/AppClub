/// Model representing the logged-in user session and its role hierarchy
class UserSession {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String role; // 'padre', 'jugador', 'dt', 'secretario', 'directivo'
  final String? category; // e.g., 'Sub-12', 'Sub-14', etc.
  final String? childId; // For 'padre' role

  const UserSession({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.role,
    this.category,
    this.childId,
  });

  /// Check if user has administrative rights
  bool get isAdmin => role == 'secretario' || role == 'directivo';

  /// Check if user is a coach (DT)
  bool get isCoach => role == 'dt';

  /// Check if user is parent/player
  bool get isNormalUser => role == 'padre' || role == 'jugador';

  /// Check if user has access to a specific category
  bool hasCategoryAccess(String? targetCategory) {
    if (isAdmin) return true;
    if (category == null || targetCategory == null) return false;
    return category == targetCategory;
  }
}
