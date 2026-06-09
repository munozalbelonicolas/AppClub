import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/jn_card.dart';
import '../../../../core/widgets/jn_badge.dart';

import '../../../../data/mock/mock_data.dart';

class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});
  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Comunicados'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Deportivo'),
            Tab(text: 'General'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnnouncementList(MockData.announcements),
          _buildAnnouncementList(MockData.announcements.where((a) => a['category'] == 'deportivo').toList()),
          _buildAnnouncementList(MockData.announcements.where((a) => a['category'] != 'deportivo').toList()),
        ],
      ),
    );
  }

  Widget _buildAnnouncementList(List<Map<String, dynamic>> announcements) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: announcements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ann = announcements[index];
        final isRead = ann['read'] as bool;

        return JNCard(
          border: !isRead
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1)
              : null,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(ann['title'] as String, style: AppTypography.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ann['body'] as String,
                style: AppTypography.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  JNBadge(
                    label: (ann['category'] as String).toUpperCase(),
                    type: ann['category'] == 'deportivo'
                        ? JNBadgeType.accent
                        : ann['category'] == 'administrativo'
                            ? JNBadgeType.info
                            : JNBadgeType.neutral,
                    small: true,
                  ),
                  if (ann['priority'] == 'high') ...[
                    const SizedBox(width: 6),
                    const JNBadge(label: 'IMPORTANTE', type: JNBadgeType.error, small: true),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(ann['date'] as String),
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ).animate(delay: (index * 80).ms).fadeIn(duration: 400.ms).slideX(begin: 0.03);
      },
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final day = int.parse(parts[2]);
    final month = int.parse(parts[1]);
    return '$day ${months[month]}';
  }
}
