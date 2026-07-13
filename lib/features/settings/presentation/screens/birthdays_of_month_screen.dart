import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_avatar.dart';

class BirthdaysOfMonthScreen extends ConsumerStatefulWidget {
  const BirthdaysOfMonthScreen({super.key});

  @override
  ConsumerState<BirthdaysOfMonthScreen> createState() => _BirthdaysOfMonthScreenState();
}

class _BirthdaysOfMonthScreenState extends ConsumerState<BirthdaysOfMonthScreen> {
  final List<String> _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Cumpleaños del Mes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<int>(
              dropdownColor: context.colors.surface,
              value: _selectedMonth,
              isExpanded: true,
              items: List.generate(12, (index) {
                return DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text(_months[index], style: context.typography.bodyLarge),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedMonth = val;
                  });
                }
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'jugador')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: context.colors.error)));
                }

                final allDocs = snapshot.data?.docs ?? [];
                final birthdayDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['birthDate'] == null) return false;
                  final DateTime birthDate = (data['birthDate'] as Timestamp).toDate();
                  return birthDate.month == _selectedMonth;
                }).toList();

                birthdayDocs.sort((a, b) {
                  final dateA = (a.data() as Map<String, dynamic>)['birthDate'] as Timestamp;
                  final dateB = (b.data() as Map<String, dynamic>)['birthDate'] as Timestamp;
                  return dateA.toDate().day.compareTo(dateB.toDate().day);
                });

                if (birthdayDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay cumpleaños registrados este mes.',
                      style: context.typography.bodyLarge.copyWith(color: context.colors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: birthdayDocs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = birthdayDocs[index].data() as Map<String, dynamic>;
                    final DateTime birthDate = (data['birthDate'] as Timestamp).toDate();
                    final int age = DateTime.now().year - birthDate.year;

                    return ListTile(
                      leading: JNAvatar(
                        imageUrl: data['photoUrl'],
                        name: '${data['name'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
                        size: 40,
                      ),
                      title: Text('${data['name'] ?? ''} ${data['lastName'] ?? ''}', style: context.typography.titleSmall),
                      subtitle: Text(
                        'Día ${birthDate.day} - Cumple $age años\nCat: ${data['category'] ?? 'N/A'}',
                        style: context.typography.bodySmall.copyWith(color: context.colors.textSecondary),
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
