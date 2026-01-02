import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// A widget that visualizes audio frequency spectrum.
class SpectrumVisualizer extends StatelessWidget {
  final List<double> spectrum;
  final bool isListening;

  const SpectrumVisualizer({
    super.key,
    required this.spectrum,
    this.isListening = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          spectrum.length,
          (index) => _buildBar(context, spectrum[index], index),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, double value, int index) {
    // Dynamic height based on spectrum value
    final double height = isListening ? (value * 100).clamp(4.0, 100.0) : 4.0;
    
    // Dynamic color based on frequency (index)
    final Color color = Color.lerp(
      AppColors.primary,
      AppColors.secondary,
      index / spectrum.length,
    ) ?? AppColors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(isListening ? 0.8 : 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}
