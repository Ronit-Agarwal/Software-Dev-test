import 'dart:async';

import 'package:flutter/material.dart';
import 'package:signsync/utils/constants.dart';

class AslSequencePlayer extends StatefulWidget {
  final List<String> glosses;
  final Duration perSign;

  const AslSequencePlayer({
    super.key,
    required this.glosses,
    this.perSign = const Duration(milliseconds: 650),
  });

  @override
  State<AslSequencePlayer> createState() => _AslSequencePlayerState();
}

class _AslSequencePlayerState extends State<AslSequencePlayer> {
  Timer? _timer;
  int _index = 0;
  bool _isPlaying = false;

  @override
  void didUpdateWidget(covariant AslSequencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glosses != widget.glosses) {
      _stop();
      setState(() => _index = 0);
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _play() {
    if (widget.glosses.isEmpty) return;
    _timer?.cancel();
    setState(() => _isPlaying = true);

    _timer = Timer.periodic(widget.perSign, (_) {
      if (!mounted) return;

      final isLast = _index >= widget.glosses.length - 1;
      if (isLast) {
        _timer?.cancel();
        _timer = null;
        setState(() => _isPlaying = false);
        return;
      }

      setState(() {
        _index = (_index + 1).clamp(0, widget.glosses.length - 1);
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  void _toggle() {
    if (_isPlaying) {
      _stop();
    } else {
      _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glosses = widget.glosses;
    final current = glosses.isEmpty ? '—' : glosses[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ASL Sequence',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              glosses.isEmpty ? '' : '${_index + 1}/${glosses.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              current,
              key: ValueKey(current),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Restart',
              onPressed: glosses.isEmpty
                  ? null
                  : () {
                      _stop();
                      setState(() => _index = 0);
                    },
              icon: const Icon(Icons.restart_alt),
            ),
            FilledButton.icon(
              onPressed: glosses.isEmpty ? null : _toggle,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? 'Pause' : 'Play'),
            ),
            IconButton(
              tooltip: 'Step',
              onPressed: glosses.isEmpty
                  ? null
                  : () {
                      _stop();
                      setState(() {
                        _index = (_index + 1).clamp(0, glosses.length - 1);
                      });
                    },
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
      ],
    );
  }
}
