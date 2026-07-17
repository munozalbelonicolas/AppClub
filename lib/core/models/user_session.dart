import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing the logged-in user session and its role hierarchy
class UserSession {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final String role; // 'tutor', 'jugador', 'dt', 'secretario', 'directivo'
  final String? category; // e.g., 'Sub-12', 'Sub-14', etc.
  final String? childId; // For 'tutor' role

  // New profile fields
  final String? dni;
  final String? weight;
  final String? height;
  final int? age;
  final DateTime? birthDate;
  final String? fatherName;
  final String? motherName;
  final String? aptoFisicoUrl;
  final DateTime? aptoFisicoExpiry;
  final bool hasPendingDebt;
  final String? avatarUrl;

  // New Sign Up fields
  final String
  status; // 'pending_email', 'pending_approval', 'active', 'disabled', 'inactive'
  final bool emailVerified;
  final String? phone1;
  final String? phone2;
  final DateTime? termsAcceptedAt;
  final String? termsVersion;

  // For Coaches (DT) managing multiple categories
  final List<String>? assignedCategories;

  const UserSession({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.role,
    this.status = 'active',
    this.emailVerified = true,
    this.category,
    this.childId,
    this.dni,
    this.weight,
    this.height,
    this.age,
    this.birthDate,
    this.fatherName,
    this.motherName,
    this.aptoFisicoUrl,
    this.aptoFisicoExpiry,
    this.hasPendingDebt = false,
    this.avatarUrl,
    this.phone1,
    this.phone2,
    this.termsAcceptedAt,
    this.termsVersion,
    this.assignedCategories,
  });

  UserSession copyWith({
    String? id,
    String? name,
    String? lastName,
    String? email,
    String? role,
    String? status,
    bool? emailVerified,
    String? category,
    String? childId,
    String? dni,
    String? weight,
    String? height,
    int? age,
    DateTime? birthDate,
    String? fatherName,
    String? motherName,
    String? aptoFisicoUrl,
    DateTime? aptoFisicoExpiry,
    bool? hasPendingDebt,
    String? avatarUrl,
    String? phone1,
    String? phone2,
    DateTime? termsAcceptedAt,
    String? termsVersion,
    List<String>? assignedCategories,
  }) {
    return UserSession(
      id: id ?? this.id,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      emailVerified: emailVerified ?? this.emailVerified,
      category: category ?? this.category,
      childId: childId ?? this.childId,
      dni: dni ?? this.dni,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      age: age ?? this.age,
      birthDate: birthDate ?? this.birthDate,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      aptoFisicoUrl: aptoFisicoUrl ?? this.aptoFisicoUrl,
      aptoFisicoExpiry: aptoFisicoExpiry ?? this.aptoFisicoExpiry,
      hasPendingDebt: hasPendingDebt ?? this.hasPendingDebt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      termsVersion: termsVersion ?? this.termsVersion,
      assignedCategories: assignedCategories ?? this.assignedCategories,
    );
  }



  /// Check if user has not completed registration (e.g. Google Sign In missing phones)
  bool get isRegistrationIncomplete {
    if (role == 'directivo' || role == 'secretario') return false; // Admins don't need this flow
    if (role == 'jugador') return termsAcceptedAt == null; // Players only need to accept terms
    return phone1 == null || phone1!.isEmpty || termsAcceptedAt == null;
  }

  /// Check if user is the Director (directivo)
  bool get isDirector => role == 'directivo';

  /// Check if user is a Secretario
  bool get isSecretario => role == 'secretario';

  /// Check if user has administrative rights (Director or Secretario)
  bool get isAdmin => role == 'secretario' || role == 'directivo';

  /// Calculate current age based on birthDate
  int? get currentAge {
    if (birthDate != null) {
      final now = DateTime.now();
      int calculatedAge = now.year - birthDate!.year;
      if (now.month < birthDate!.month ||
          (now.month == birthDate!.month && now.day < birthDate!.day)) {
        calculatedAge--;
      }
      return calculatedAge;
    }
    return age;
  }

  /// Check if user is a coach (DT)
  bool get isCoach => role == 'dt';

  /// Check if user is parent/player
  bool get isNormalUser => role == 'tutor' || role == 'jugador';

  /// Check if user is socio
  bool get isSocio => role == 'socio';

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
      'status': status,
      'emailVerified': emailVerified,
      'category': category,
      'childId': childId,
      'dni': dni,
      'weight': weight,
      'height': height,
      'age': age,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'fatherName': fatherName,
      'motherName': motherName,
      'aptoFisicoUrl': aptoFisicoUrl,
      'aptoFisicoExpiry': aptoFisicoExpiry != null
          ? Timestamp.fromDate(aptoFisicoExpiry!)
          : null,
      'hasPendingDebt': hasPendingDebt,
      'avatarUrl': avatarUrl,
      'phone1': phone1,
      'phone2': phone2,
      'termsAcceptedAt': termsAcceptedAt != null
          ? Timestamp.fromDate(termsAcceptedAt!)
          : null,
      'termsVersion': termsVersion,
      'assignedCategories': assignedCategories,
    };
  }
}
