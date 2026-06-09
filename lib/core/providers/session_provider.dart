import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_session.dart';

/// Provider for managing the current user session
final currentUserProvider = StateProvider<UserSession?>((ref) => null);

/// Mock users corresponding to the login screen selection
class SessionMocks {
  SessionMocks._();

  static final Map<String, UserSession> users = {
    'padre': const UserSession(
      id: 'usr_padre_01',
      name: 'Carlos',
      lastName: 'Gutiérrez',
      email: 'carlos.gutierrez@email.com',
      role: 'padre',
      category: 'Sub-12',
      childId: 'ply_001',
    ),
    'dt': const UserSession(
      id: 'usr_dt_01',
      name: 'Pablo',
      lastName: 'Ramírez',
      email: 'pablo.ramirez@email.com',
      role: 'dt',
      category: 'Sub-12',
    ),
    'secretario': const UserSession(
      id: 'usr_sec_01',
      name: 'Jorge',
      lastName: 'Newbery',
      email: 'secretaria@jorgenewbery.com',
      role: 'secretario',
    ),
    'directivo': const UserSession(
      id: 'usr_dir_01',
      name: 'Lorena',
      lastName: 'Gómez',
      email: 'directiva@jorgenewbery.com',
      role: 'directivo',
    ),
  };
}
