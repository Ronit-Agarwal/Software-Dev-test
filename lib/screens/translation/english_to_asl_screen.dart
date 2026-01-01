import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/models/asl_translation.dart';
import 'package:signsync/services/asl_sequence_exporter.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/translation/asl_sequence_player.dart';

class EnglishToAslScreen extends ConsumerStatefulWidget {
  const EnglishToAslScreen({super.key});

  @override
  ConsumerState<EnglishToAslScreen> createState() => _EnglishToAslScreenState();
}

class _EnglishToAslScreenState extends ConsumerState<EnglishToAslScreen> {
  final _controller = TextEditingController();
  AslTranslationResult? _result;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initSpeech());
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onError: (e) => LoggerService.warn('STT error: $e'),
        onStatus: (s) => LoggerService.debug('STT status: $s'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      LoggerService.warn('Speech-to-text unavailable: $e');
      _speechReady = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_speech.stop());
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final translator = ref.read(aslTranslationServiceProvider);
    final res = await translator.translate(text);

    setState(() => _result = res);
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) return;

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      listenMode: stt.ListenMode.confirmation,
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _controller.text = r.recognizedWords;
        });
      },
    );
  }

  Future<void> _exportGif() async {
    final glosses = _result?.glosses ?? const <String>[];
    if (glosses.isEmpty) return;

    final file = await AslSequenceExporter.exportGif(glosses: glosses);
    if (!mounted) return;

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported: ${file.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dictSize = ref.watch(aslTranslationServiceProvider).dictionarySize;

    return Scaffold(
      appBar: AppBar(
        title: const Text('English → ASL'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export as GIF',
            onPressed: (_result?.glosses.isNotEmpty ?? false) ? _exportGif : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        children: [
          Text(
            'Dictionary: $dictSize+ entries',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Enter English text',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              IconButton.filled(
                onPressed: _speechReady ? _toggleListening : null,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                tooltip: _listening ? 'Stop' : 'Speak',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          FilledButton.icon(
            onPressed: _translate,
            icon: const Icon(Icons.translate),
            label: const Text('Translate'),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          AslSequencePlayer(glosses: _result?.glosses ?? const []),
          const SizedBox(height: AppConstants.spacingLg),
          _buildResultDetails(),
        ],
      ),
    );
  }

  Widget _buildResultDetails() {
    final res = _result;
    if (res == null) {
      return Text(
        'Enter a phrase and tap Translate.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tokens: ${res.tokens.join(' · ')}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppConstants.spacingSm),
        Text('Gloss: ${res.glosses.join(' ')}', style: Theme.of(context).textTheme.bodyMedium),
        if (res.unknownTokens.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'Unknown: ${res.unknownTokens.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
          ),
        ],
      ],
    );
  }
}
