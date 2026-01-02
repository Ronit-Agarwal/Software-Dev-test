import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../models/asl_sign.dart';
import '../../utils/constants.dart';
import '../../core/theme/colors.dart';

/// A widget that plays a sequence of ASL sign animations.
class AslSequencePlayer extends StatefulWidget {
  final List<AslSign> sequence;
  final VoidCallback? onComplete;
  final bool autoPlay;

  const AslSequencePlayer({
    super.key,
    required this.sequence,
    this.onComplete,
    this.autoPlay = true,
  });

  @override
  State<AslSequencePlayer> createState() => _AslSequencePlayerState();
}

class _AslSequencePlayerState extends State<AslSequencePlayer> {
  int _currentIndex = 0;
  bool _isPlaying = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && widget.sequence.isNotEmpty) {
      _startPlayback();
    }
  }

  @override
  void didUpdateWidget(AslSequencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sequence != oldWidget.sequence) {
      _stopPlayback();
      _currentIndex = 0;
      if (widget.autoPlay && widget.sequence.isNotEmpty) {
        _startPlayback();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPlayback() {
    setState(() {
      _isPlaying = true;
    });
    _playNext();
  }

  void _stopPlayback() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _playNext() {
    if (_currentIndex < widget.sequence.length) {
      // In a real app, we'd wait for the Lottie animation to finish.
      // Here we simulate with a timer based on average sign duration.
      final duration = widget.sequence[_currentIndex].duration ?? const Duration(milliseconds: 1500);
      
      _timer = Timer(duration, () {
        if (mounted) {
          setState(() {
            if (_currentIndex < widget.sequence.length - 1) {
              _currentIndex++;
              _playNext();
            } else {
              _isPlaying = false;
              widget.onComplete?.call();
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sequence.isEmpty) {
      return const Center(
        child: Text('No signs in sequence'),
      );
    }

    final currentSign = widget.sequence[_currentIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animation Container
        Container(
          height: 300,
          width: 300,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariantLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Lottie Animation (Placeholder)
              // In a real app, this would load: 'assets/animations/asl/${currentSign.word}.json'
              Icon(
                Icons.front_hand, // Placeholder icon
                size: 100,
                color: AppColors.primary.withOpacity(0.5),
              ),
              
              // Animated Sign Text
              Positioned(
                bottom: AppConstants.spacingMd,
                child: Text(
                  currentSign.word.toUpperCase(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              
              // Progress Indicator
              Positioned(
                top: AppConstants.spacingMd,
                right: AppConstants.spacingMd,
                child: Text(
                  '${_currentIndex + 1} / ${widget.sequence.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppConstants.spacingMd),
        
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              onPressed: () {
                if (_isPlaying) {
                  _stopPlayback();
                } else {
                  if (_currentIndex == widget.sequence.length - 1) {
                    setState(() => _currentIndex = 0);
                  }
                  _startPlayback();
                }
              },
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 48,
            ),
            IconButton(
              onPressed: _currentIndex < widget.sequence.length - 1 
                ? () => setState(() => _currentIndex++) 
                : null,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
      ],
    );
  }
}
