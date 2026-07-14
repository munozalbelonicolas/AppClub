import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_session.dart';

/// Provider for managing the current user session
final currentUserProvider = StateProvider<UserSession?>((ref) => null);

/// Provider for managing the selected child for parents (Tutors)
final selectedChildProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
