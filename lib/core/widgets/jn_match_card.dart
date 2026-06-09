import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'jn_card.dart';

/// Match card showing teams, score, date, and status
class JNMatchCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final String date;
  final String time;
  final String venue;
  final String status; // 'played', 'upcoming', 'live'
  final VoidCallback? onTap;
  final bool isHero;

  const JNMatchCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    required this.date,
    required this.time,
    this.venue = '',
    this.status = 'upcoming',
    this.onTap,
    this.isHero = false,
  });

  bool get _isClubHome => homeTeam.contains('Newbery');
  bool get _isClubAway => awayTeam.contains('Newbery');

  String get _result {
    if (status != 'played' || homeScore == null) return '';
    if (_isClubHome) {
      if (homeScore! > awayScore!) return 'win';
      if (homeScore! < awayScore!) return 'loss';
    } else {
      if (awayScore! > homeScore!) return 'win';
      if (awayScore! < homeScore!) return 'loss';
    }
    return 'draw';
  }

  @override
  Widget build(BuildContext context) {
    if (isHero) return _buildHeroCard();
    return _buildCompactCard();
  }

  Widget _buildHeroCard() {
    return JNCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceLight,
          AppColors.surface,
          AppColors.primary.withValues(alpha: 0.08),
        ],
      ),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.3),
        width: 1,
      ),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        children: [
          // Status & Date header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'upcoming'
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  status == 'upcoming' ? 'PRÓXIMO PARTIDO' : 'FINALIZADO',
                  style: AppTypography.badge.copyWith(
                    color: status == 'upcoming' ? AppColors.primary : AppColors.success,
                  ),
                ),
              ),
              Text(
                '$date · $time',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Teams & Score
          Row(
            children: [
              // Home team
              Expanded(
                child: Column(
                  children: [
                    _buildTeamIcon(homeTeam),
                    const SizedBox(height: 8),
                    Text(
                      homeTeam,
                      style: AppTypography.titleSmall.copyWith(
                        color: _isClubHome ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: _isClubHome ? FontWeight.w700 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Score or VS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: status == 'played' && homeScore != null
                    ? Row(
                        children: [
                          Text('$homeScore', style: AppTypography.scoreMedium),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('-', style: AppTypography.scoreMedium.copyWith(color: AppColors.textTertiary)),
                          ),
                          Text('$awayScore', style: AppTypography.scoreMedium),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VS',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),

              // Away team
              Expanded(
                child: Column(
                  children: [
                    _buildTeamIcon(awayTeam),
                    const SizedBox(height: 8),
                    Text(
                      awayTeam,
                      style: AppTypography.titleSmall.copyWith(
                        color: _isClubAway ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: _isClubAway ? FontWeight.w700 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (venue.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(venue, style: AppTypography.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactCard() {
    return JNCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Result indicator
          if (status == 'played')
            Container(
              width: 3,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _result == 'win'
                    ? AppColors.win
                    : _result == 'draw'
                        ? AppColors.draw
                        : AppColors.loss,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // Teams
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homeTeam,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: _isClubHome ? FontWeight.w700 : FontWeight.w400,
                    color: _isClubHome ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  awayTeam,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: _isClubAway ? FontWeight.w700 : FontWeight.w400,
                    color: _isClubAway ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Score or Time
          if (status == 'played' && homeScore != null)
            Column(
              children: [
                Text('$homeScore', style: AppTypography.titleLarge),
                Text('$awayScore', style: AppTypography.titleLarge),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(time, style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
                Text(date, style: AppTypography.bodySmall),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTeamIcon(String team) {
    final isClub = team.contains('Newbery');
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isClub ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceVariant,
        border: isClub
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          isClub ? 'JN' : team.substring(0, 2).toUpperCase(),
          style: AppTypography.titleLarge.copyWith(
            color: isClub ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
