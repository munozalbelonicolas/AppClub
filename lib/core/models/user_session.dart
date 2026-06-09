import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing the logged-in user session and its role hierarchy
class UserSession {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String role; // 'padre', 'jugador', 'dt', 'secretario', 'directivo'
  final String? category; // e.g., 'Sub-12', 'Sub-14', etc.
  final String? childId; // For 'padre' role
  
  // New profile fields
  final String? dni;
  final String? weight;
  final String? height;
  final int? age;
  final String? fatherName;
  final String? motherName;
  final String? aptoFisicoUrl;
  final DateTime? aptoFisicoExpiry;
  final bool hasPendingDebt;
  final String? avatarUrl;

  const UserSession({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.role,
    this.category,
    this.childId,
    this.dni,
    this.weight,
    this.height,
    this.age,
    this.fatherName,
    this.motherName,
    this.aptoFisicoUrl,
    this.aptoFisicoExpiry,
    this.hasPendingDebt = false,
    this.avatarUrl,
  });

  /// Check if user is the Director (directivo)
  bool get isDirector => role == 'directivo';

  /// Check if user is a Secretario
  bool get isSecretario => role == 'secretario';

  /// Check if user has administrative rights (Director or Secretario)
  bool get isAdmin => role == 'secretario' || role == 'directivo';

  /// Check if user is a coach (DT)
  bool get isCoach => role == 'dt';

  /// Check if user is parent/player
  bool get isNormalUser => role == 'padre' || role == 'jugador';

  /// Helper to check if a fitness card is about to expire (within 30 days) or expired
  bool get isAptoFisicoWarning {
    if (aptoFisicoExpiry == null) return true; // Warning if not uploaded
    final difference = aptoFisicoExpiry!.difference(DateTime.now()).inDays;
    return difference <= 30;
  }

  /// Helper to check if a fitness card is expired
  bool get isAptoFisicoExpired {
    if (aptoFisicoExpiry == null) return true;
    return aptoFisicoExpiry!.isBefore(DateTime.now());
  }

  /// Check if user has access to a specific category
  bool hasCategoryAccess(String? targetCategory) {
    if (isAdmin) return true;
    if (category == null || targetCategory == null) return false;
    return category == targetCategory;
  }

  /// Hierarchical permission check:
  /// - Director has authority over ALL (Secretarios, DTs, Players, Parents)
  /// - Secretario has authority over DTs, Players, Parents (not Director)
  /// - DT has authority over Players and Parents of THEIR category
  bool canManage(UserSession other) {
    if (isDirector) return true;
    if (isSecretario) {
      return other.role != 'directivo';
    }
    if (isCoach) {
      return other.isNormalUser && category == other.category;
    }
    return false;
  }

  /// Parse date from dynamic input (String, Timestamp, etc.)
  static DateTime? parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lastName': lastName,
      'email': email,
      'role': role,
      'category': category,
      'childId': childId,
      'dni': dni,
      'weight': weight,
      'height': height,
      'age': age,
      'fatherName': fatherName,
      'motherName': motherName,
      'aptoFisicoUrl': aptoFisicoUrl,
      'aptoFisicoExpiry': aptoFisicoExpiry != null ? Timestamp.fromDate(aptoFisicoExpiry!) : null,
      'hasPendingDebt': hasPendingDebt,
      'avatarUrl': avatarUrl,
    };
  }
}
