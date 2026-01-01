import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:signsync/core/logging/logger_service.dart';

class AslSequenceExporter {
  static Future<File?> exportGif({
    required List<String> glosses,
    int width = 480,
    int height = 480,
    int msPerFrame = 450,
  }) async {
    if (glosses.isEmpty) return null;

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/signsync_asl_${DateTime.now().millisecondsSinceEpoch}.gif');

      final anim = img.Animation();

      for (final g in glosses) {
        final frame = img.Image(width: width, height: height);
        final bg = _colorFromString(g);
        img.fill(frame, color: bg);

        // Draw a simple blocky label (A-Z/0-9/space/-)
        _drawText(frame, 24, height ~/ 2 - 24, g, scale: 3);

        anim.addFrame(frame);
        anim.frames.last.duration = msPerFrame;
      }

      final bytes = Uint8List.fromList(img.encodeGifAnimation(anim));
      await file.writeAsBytes(bytes, flush: true);
      LoggerService.info('Exported ASL GIF: ${file.path}');
      return file;
    } catch (e, stack) {
      LoggerService.error('Failed to export ASL GIF', error: e, stackTrace: stack);
      return null;
    }
  }

  static img.Color _colorFromString(String s) {
    final hash = s.codeUnits.fold<int>(0, (a, b) => a + b);
    final r = 80 + (hash * 53) % 140;
    final g = 80 + (hash * 97) % 140;
    final b = 80 + (hash * 193) % 140;
    return img.ColorRgb8(r, g, b);
  }

  static const Map<String, List<int>> _font5x7 = {
    'A': [0x1E, 0x05, 0x05, 0x1E],
    'B': [0x1F, 0x15, 0x15, 0x0A],
    'C': [0x0E, 0x11, 0x11, 0x11],
    'D': [0x1F, 0x11, 0x11, 0x0E],
    'E': [0x1F, 0x15, 0x15, 0x11],
    'F': [0x1F, 0x05, 0x05, 0x01],
    'G': [0x0E, 0x11, 0x15, 0x1D],
    'H': [0x1F, 0x04, 0x04, 0x1F],
    'I': [0x11, 0x1F, 0x11],
    'J': [0x18, 0x10, 0x11, 0x0F],
    'K': [0x1F, 0x04, 0x0A, 0x11],
    'L': [0x1F, 0x10, 0x10, 0x10],
    'M': [0x1F, 0x02, 0x04, 0x02, 0x1F],
    'N': [0x1F, 0x02, 0x04, 0x1F],
    'O': [0x0E, 0x11, 0x11, 0x0E],
    'P': [0x1F, 0x05, 0x05, 0x02],
    'Q': [0x0E, 0x11, 0x19, 0x1E],
    'R': [0x1F, 0x05, 0x0D, 0x12],
    'S': [0x12, 0x15, 0x15, 0x09],
    'T': [0x01, 0x1F, 0x01],
    'U': [0x0F, 0x10, 0x10, 0x0F],
    'V': [0x07, 0x08, 0x10, 0x08, 0x07],
    'W': [0x1F, 0x08, 0x04, 0x08, 0x1F],
    'X': [0x1B, 0x04, 0x04, 0x1B],
    'Y': [0x03, 0x04, 0x18, 0x04, 0x03],
    'Z': [0x19, 0x15, 0x13],
    '0': [0x0E, 0x11, 0x11, 0x0E],
    '1': [0x12, 0x1F, 0x10],
    '2': [0x19, 0x15, 0x12],
    '3': [0x11, 0x15, 0x0A],
    '4': [0x07, 0x04, 0x1F, 0x04],
    '5': [0x17, 0x15, 0x09],
    '6': [0x0E, 0x15, 0x1D],
    '7': [0x01, 0x1D, 0x03],
    '8': [0x0A, 0x15, 0x0A],
    '9': [0x17, 0x15, 0x0E],
    '-': [0x04, 0x04, 0x04],
    ' ': [0x00],
  };

  static void _drawText(img.Image image, int x, int y, String text, {int scale = 2}) {
    final color = img.ColorRgb8(255, 255, 255);
    var cursorX = x;
    var cursorY = y;

    final upper = text.toUpperCase();
    for (final ch in upper.split('')) {
      final glyph = _font5x7[ch] ?? _font5x7[' ']!;
      final glyphWidth = glyph.length;

      for (int col = 0; col < glyph.length; col++) {
        final bits = glyph[col];
        for (int row = 0; row < 7; row++) {
          final on = (bits & (1 << row)) != 0;
          if (!on) continue;

          final px = cursorX + col * scale;
          final py = cursorY + row * scale;

          for (int dx = 0; dx < scale; dx++) {
            for (int dy = 0; dy < scale; dy++) {
              final tx = px + dx;
              final ty = py + dy;
              if (tx >= 0 && tx < image.width && ty >= 0 && ty < image.height) {
                image.setPixel(tx, ty, color);
              }
            }
          }
        }
      }

      cursorX += (glyphWidth + 1) * scale;
      if (cursorX > image.width - 10) {
        cursorX = x;
        cursorY += 10 * scale;
      }
    }
  }
}
