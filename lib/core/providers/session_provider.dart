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
      dni: '38123456',
      weight: '78 kg',
      height: '1.75 m',
      age: 42,
      fatherName: 'Ramón Gutiérrez',
      motherName: 'Isabel Díaz',
      hasPendingDebt: true, // test warning
    ),
    'dt': const UserSession(
      id: 'usr_dt_01',
      name: 'Pablo',
      lastName: 'Ramírez',
      email: 'pablo.ramirez@email.com',
      role: 'dt',
      category: 'Sub-12',
      dni: '30456789',
      weight: '82 kg',
      height: '1.80 m',
      age: 38,
    ),
    'secretario': const UserSession(
      id: 'usr_sec_01',
      name: 'Jorge',
      lastName: 'Newbery',
      email: 'secretaria@jorgenewbery.com',
      role: 'secretario',
      dni: '25123456',
      weight: '75 kg',
      height: '1.70 m',
      age: 55,
    ),
    'directivo': const UserSession(
      id: 'usr_dir_01',
      name: 'Lorena',
      lastName: 'Gómez',
      email: 'directiva@jorgenewbery.com',
      role: 'directivo',
      dni: '28123456',
      weight: '62 kg',
      height: '1.65 m',
      age: 48,
    ),
  };
}
