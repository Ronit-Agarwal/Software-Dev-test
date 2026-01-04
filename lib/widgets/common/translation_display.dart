import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/models/asl_sign.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Translation display widget for showing ASL sign detection results.
///
/// This widget displays the current detected sign, its confidence,
/// and the history of recent signs.
class TranslationDisplayWidget extends ConsumerWidget {
  final AslSign? currentSign;
  final List<AslSign> signHistory;

  const TranslationDisplayWidget({
    super.key,
    this.currentSign,
    required this.signHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Current Sign Display
          if (currentSign != null)
            _buildCurrentSignDisplay(context, currentSign!)
          else
            _buildNoSignDisplay(context),

          const Divider(height: 1),

          // Recent Signs History
          Expanded(
            child: _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSignDisplay(BuildContext context, AslSign sign) {
    final confidenceColor = _getConfidenceColor(sign.confidence);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        children: [
          // Main Display
          Row(
            children: [
              // Letter/Word Display
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: confidenceColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  border: Border.all(
                    color: confidenceColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    sign.letter.isNotEmpty ? sign.letter : sign.word[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: confidenceColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              // Sign Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sign.word,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (sign.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sign.description,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Confidence Indicator
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: AppConstants.iconSizeSm,
                          color: confidenceColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(sign.confidence * 100).toStringAsFixed(1)}% confident',
                          style: TextStyle(
                            color: confidenceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoSignDisplay(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        children: [
          Icon(
            Icons.sign_language,
            size: AppConstants.iconSizeXl,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            'Detecting signs...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence: --',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Hold your hands clearly in view of the camera.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return signHistory.isEmpty
        ? Center(
            child: Text(
              'No recent signs',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            itemCount: signHistory.length,
            itemBuilder: (context, index) {
              final sign = signHistory[index];
              return _buildHistoryItem(sign);
            },
          );
  }

  Widget _buildHistoryItem(AslSign sign) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
      child: Row(
        children: [
          // Confidence indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getConfidenceColor(sign.confidence),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          // Letter
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Center(
              child: Text(
                sign.letter.isNotEmpty ? sign.letter : sign.word[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          // Word and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sign.word,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  sign.timestamp.relativeTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Confidence percentage
          Text(
            '${(sign.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: _getConfidenceColor(sign.confidence),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.signConfidenceHigh;
    if (confidence >= 0.6) return AppColors.signConfidenceMedium;
    return AppColors.signConfidenceLow;
  }
}

/// A large sign display for prominent showing.
class LargeSignDisplay extends StatelessWidget {
  final AslSign sign;
  final double size;

  const LargeSignDisplay({
    super.key,
    required this.sign,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          sign.letter.isNotEmpty ? sign.letter : sign.word,
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
