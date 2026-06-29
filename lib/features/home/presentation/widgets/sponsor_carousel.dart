import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/services/firestore_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class SponsorCarousel extends ConsumerStatefulWidget {
  const SponsorCarousel({super.key});

  @override
  ConsumerState<SponsorCarousel> createState() => _SponsorCarouselState();
}

class _SponsorCarouselState extends ConsumerState<SponsorCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _sponsorsList = [];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_sponsorsList.isEmpty) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _sponsorsList.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchSponsorUrl(String urlString, BuildContext context) async {
    if (urlString.isEmpty) return;
    
    try {
      // Ensure URL has a scheme
      if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
        urlString = 'https://$urlString';
      }
      
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el enlace del sponsor'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sponsorsAsync = ref.watch(sponsorsStreamProvider);

    return sponsorsAsync.when(
      data: (sponsors) {
        _sponsorsList = sponsors;
        if (sponsors.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 140,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        itemCount: sponsors.length,
                        itemBuilder: (context, index) {
                          final sponsor = sponsors[index];
                          return GestureDetector(
                            onTap: () {
                              final link = sponsor['linkUrl']?.toString() ?? '';
                              if (link.isNotEmpty) {
                                _launchSponsorUrl(link, context);
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Sponsor Image
                                _buildSponsorImage(sponsor['imageUrl'] ?? ''),
                                // Gradient Overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.7),
                                      ],
                                    ),
                                  ),
                                ),
                                // Sponsor Text
                                Positioned(
                                  bottom: 12,
                                  left: 16,
                                  right: 16,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SPONSOR OFICIAL',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        sponsor['name'] ?? '',
                                        style: AppTypography.titleLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Dot indicators inside the image
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: Row(
                          children: List.generate(
                            sponsors.length,
                            (index) => Container(
                              width: _currentPage == index ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? AppColors.accent
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scaleY(begin: 0.9);
      },
      loading: () => _buildShimmerLoading(),
      error: (err, stack) => _buildErrorState(err),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.surface,
      child: Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Center(
        child: Text(
          'Error al cargar sponsors',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildSponsorImage(String url) {
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: AppColors.surfaceLight,
        highlightColor: AppColors.surface,
        child: Container(color: AppColors.surfaceLight),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.surfaceLight,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            size: 36,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
