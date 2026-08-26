import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme_colors.dart';
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
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final String status; // 'played', 'upcoming', 'live', 'programado'
  final VoidCallback? onTap;
  final bool isHero;

  const JNMatchCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogoUrl,
    this.awayLogoUrl,
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

  bool get _isUpcoming =>
      status == 'upcoming' ||
      status == 'programado' ||
      (status != 'played' && status != 'finalizado');

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
    if (isHero) return _buildHeroCard(context).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
    return _buildCompactCard(context).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildHeroCard(BuildContext context) {
    return JNCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.colors.surfaceLight,
          context.colors.surface,
          context.colors.primary.withValues(alpha: 0.08),
        ],
      ),
      border: Border.all(
        color: context.colors.primary.withValues(alpha: 0.3),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _isUpcoming
                      ? context.colors.primary.withValues(alpha: 0.15)
                      : context.colors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  _isUpcoming ? 'PRÓXIMO PARTIDO' : 'FINALIZADO',
                  style: context.typography.badge.copyWith(
                    color: _isUpcoming
                        ? context.colors.primary
                        : context.colors.success,
                  ),
                ),
              ),
              Text('$date · $time', style: context.typography.bodySmall),
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
                    _buildTeamIcon(context, homeTeam, homeLogoUrl),
                    const SizedBox(height: 8),
                    Text(
                      homeTeam,
                      style: context.typography.titleSmall.copyWith(
                        color: _isClubHome
                            ? context.colors.textPrimary
                            : context.colors.textSecondary,
                        fontWeight: _isClubHome
                            ? FontWeight.w700
                            : FontWeight.w400,
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
                          Text('$homeScore', style: context.typography.scoreMedium),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '-',
                              style: context.typography.scoreMedium.copyWith(
                                color: context.colors.textTertiary,
                              ),
                            ),
                          ),
                          Text('$awayScore', style: context.typography.scoreMedium),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VS',
                          style: context.typography.titleLarge.copyWith(
                            color: context.colors.textTertiary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),

              // Away team
              Expanded(
                child: Column(
                  children: [
                    _buildTeamIcon(context, awayTeam, awayLogoUrl),
                    const SizedBox(height: 8),
                    Text(
                      awayTeam,
                      style: context.typography.titleSmall.copyWith(
                        color: _isClubAway
                            ? context.colors.textPrimary
                            : context.colors.textSecondary,
                        fontWeight: _isClubAway
                            ? FontWeight.w700
                            : FontWeight.w400,
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
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: context.colors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(venue, style: context.typography.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
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
                    ? context.colors.win
                    : _result == 'draw'
                    ? context.colors.draw
                    : context.colors.loss,
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
                  style: context.typography.titleSmall.copyWith(
                    fontWeight: _isClubHome ? FontWeight.w700 : FontWeight.w400,
                    color: _isClubHome
                        ? context.colors.textPrimary
                        : context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  awayTeam,
                  style: context.typography.titleSmall.copyWith(
                    fontWeight: _isClubAway ? FontWeight.w700 : FontWeight.w400,
                    color: _isClubAway
                        ? context.colors.textPrimary
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Score or Time
          if (status == 'played' && homeScore != null)
            Column(
              children: [
                Text('$homeScore', style: context.typography.titleLarge),
                Text('$awayScore', style: context.typography.titleLarge),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: context.typography.titleSmall.copyWith(
                    color: context.colors.primary,
                  ),
                ),
                Text(date, style: context.typography.bodySmall),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTeamIcon(BuildContext context, String team, String? logoUrl) {
    final isClub = team.contains('Newbery');
    final String displayInitials = isClub
        ? 'JN'
        : (team.length >= 2 ? team.substring(0, 2).toUpperCase() : team.toUpperCase());

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isClub
            ? context.colors.primary.withValues(alpha: 0.15)
            : context.colors.surfaceVariant,
        border: isClub
            ? Border.all(
                color: context.colors.primary.withValues(alpha: 0.3),
                width: 2,
              )
            : null,
      ),
      child: ClipOval(
        child: logoUrl != null && logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                errorWidget: (context, url, error) => Center(
                  child: Text(
                    displayInitials,
                    style: context.typography.titleLarge.copyWith(
                      color: isClub ? context.colors.primary : context.colors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  displayInitials,
                  style: context.typography.titleLarge.copyWith(
                    color: isClub ? context.colors.primary : context.colors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}