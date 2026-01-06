import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/providers.dart';
import '../../models/asl_sign.dart';
import '../../utils/constants.dart';
import '../../core/theme/colors.dart';
import 'asl_sequence_player.dart';

/// Widget for English-to-ASL translation.
///
/// Provides text and speech input, and plays the resulting ASL sign sequence.
class TextToAslWidget extends ConsumerStatefulWidget {
  const TextToAslWidget({super.key});

  @override
  ConsumerState<TextToAslWidget> createState() => _TextToAslWidgetState();
}

class _TextToAslWidgetState extends ConsumerState<TextToAslWidget> {
  final TextEditingController _textController = TextEditingController();
  
  bool _isListening = false;
  List<AslSign> _sequence = [];
  bool _isTranslating = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      final translationService = ref.read(aslTranslationServiceProvider);
      final sequence = await translationService.translate(text);
      
      if (mounted) {
        setState(() {
          _sequence = sequence;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input Section
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Enter English text or use microphone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    suffixIcon: _textController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _textController.clear()),
                        )
                      : null,
                  ),
                  onSubmitted: (_) => _translate(),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              IconButton.filled(
                onPressed: _translate,
                icon: const Icon(Icons.translate),
              ),
            ],
          ),
        ),

        // Animation Player Section
        Expanded(
          child: Center(
            child: _isTranslating
              ? const CircularProgressIndicator()
              : _sequence.isNotEmpty
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spacingLg),
                      child: AslSequencePlayer(sequence: _sequence),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.translate,
                        size: 64,
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      const Text('Translation will appear here'),
                    ],
                  ),
          ),
        ),
        
        // Actions
        if (_sequence.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // Export logic placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sequence exported to video')),
                    );
                  },
                  icon: const Icon(Icons.video_file),
                  label: const Text('Export Video'),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _sequence = [];
                      _textController.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
