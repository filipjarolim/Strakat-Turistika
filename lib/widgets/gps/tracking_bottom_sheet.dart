import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/tracking_summary.dart';
import '../ui/app_button.dart';

class TrackingBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final TrackingSummary? summary;
  final bool isTracking;
  final bool isPaused;
  final VoidCallback onToggleTracking;
  final VoidCallback onPauseTracking;
  final VoidCallback onStopTracking;
  final VoidCallback onCenterMap;
  final double sheetPosition; // 0.0 to 1.0 approx, to drive animations
  final double? currentSpeed;
  final double? currentAltitude;

  const TrackingBottomSheet({
    super.key,
    required this.scrollController,
    this.summary,
    this.currentSpeed,
    this.currentAltitude,
    required this.isTracking,
    this.isPaused = false,
    required this.onToggleTracking,
    required this.onPauseTracking,
    required this.onStopTracking,
    required this.onCenterMap,
    this.sheetPosition = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate opacities/sizes based on sheetPosition
    // If sheetPosition is low (collapsed ~0.15), show collapsed view
    // If high (>0.3), show expanded view
    
    // Simplification for initial implementation: 
    // consistently use the scroll view, but list elements change visibility/opacity
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(), // Prevent overscroll bounce at top
            children: [
               // Grip handle area
               Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Collapsed Header View (Always visible/pinned logic handled by layout or just first item)
              _buildCompactHeader(context),
              
              // Expanded Content (Stats Grid, Tools)
              // We can wrap this in Opacity or AnimatedOpacity based on sheet height if we had it directly,
              // or just let it scroll into view. 
              // For "smooth approach", nice transition is better.
              // Since we are inside DraggableScrollableSheet builder, we rely on having enough content to scroll.
              
              const SizedBox(height: 24),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistiky',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    
                    const SizedBox(height: 32),
                    
                    Text(
                      'Nástroje mapy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMapTools(context),
                    
                    const SizedBox(height: 100), // Bottom padding for scroll
                  ],
                ),
              ),
            ],
          ),
          
          // Floating Action Button (Start/Stop) - Custom positioned or part of header
          // The user wants "dynamic" feel. 
          // We can place the main button in the header for collapsed state, 
          // and morph it or keep it there.
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context) {
    // The "Pill" look
    final duration = summary?.duration ?? Duration.zero;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final distanceKm = (summary?.totalDistance ?? 0) / 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Main Stat (Time or Distance)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTracking ? 'Probíhá záznam' : 'Připraveno',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      isTracking 
                          ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
                          : '00:00:00',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${distanceKm.toStringAsFixed(2)} km',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          GestureDetector(
             onTap: onToggleTracking,
             child: AnimatedContainer(
               duration: const Duration(milliseconds: 300),
               width: 56,
               height: 56,
               decoration: BoxDecoration(
                 color: isTracking 
                    ? (isPaused ? Colors.orange : Colors.red)
                    : AppColors.primary,
                 borderRadius: BorderRadius.circular(18),
                 boxShadow: [
                   BoxShadow(
                     color: (isTracking ? Colors.red : AppColors.primary).withValues(alpha: 0.3),
                     blurRadius: 12,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: Icon(
                 isTracking ? (isPaused ? Icons.play_arrow : Icons.pause) : Icons.play_arrow,
                 color: Colors.white,
                 size: 28,
               ),
             ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsGrid() {
    final speed = (currentSpeed ?? 0) * 3.6; // m/s to km/h
    final altitude = currentAltitude ?? 0;
    final avgSpeed = (summary?.averageSpeed ?? 0) * 3.6;

    return Column(
      children: [
        Row(
          children: [
             Expanded(child: _buildStatItem('Rychlost', speed.toStringAsFixed(1), 'km/h', Icons.speed)),
             const SizedBox(width: 12),
             Expanded(child: _buildStatItem('Výška', altitude.toStringAsFixed(0), 'm n.m.', Icons.landscape)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
             Expanded(child: _buildStatItem('Průměrná', avgSpeed.toStringAsFixed(1), 'km/h', Icons.timelapse)),
             // Add more stats or placeholder
             const SizedBox(width: 12),
             Expanded(child: Container()), 
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapTools(BuildContext context) {
    return Row(
      children: [
        // "Centrovat" button removed as it is already on the map
        Expanded(child: Container()), 
        const SizedBox(width: 12),
         // Add more tools like Layer switcher if needed
         Expanded(
           child: AppButton(
            onPressed: onStopTracking,
            text: 'Ukončit',
            icon: Icons.stop_rounded,
            type: AppButtonType.destructiveOutline,
            size: AppButtonSize.medium,
          ),
         ),
      ],
    );
  }
}
