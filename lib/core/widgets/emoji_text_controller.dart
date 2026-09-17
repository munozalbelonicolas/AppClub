import 'package:flutter/material.dart';

/// Un [TextEditingController] que colorea emojis de corazon (❤️, 🖤, etc.)
/// mientras el usuario escribe, sin alterar el valor `.text` almacenado.
///
/// Usalo como reemplazo directo de [TextEditingController] en cualquier
/// campo de texto libre donde se quiera soportar corazones con color.
class EmojiRichTextEditingController extends TextEditingController {
  EmojiRichTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final baseStyle = style ?? const TextStyle();
    final regex = RegExp(r'(❤️|❤|🖤|🤍|💚|💛|🧡|💙|💜|💔|💖|💗)');
    final spans = <InlineSpan>[];

    int lastMatchEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchedEmoji = match.group(0)!;
      switch (matchedEmoji) {
        case '❤️':
        case '❤':
        case '💖':
        case '💗':
          spans.add(
            TextSpan(
              text: matchedEmoji,
              style: baseStyle.copyWith(
                color: const Color(0xFFE53935),
                fontFamilyFallback: const [
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
              ),
            ),
          );
          break;
        case '🖤':
          spans.add(
            TextSpan(
              text: matchedEmoji,
              style: baseStyle.copyWith(
                color: const Color(0xFF1E1E1E),
                fontFamilyFallback: const [
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
              ),
            ),
          );
          break;
        default:
          spans.add(
            TextSpan(
              text: matchedEmoji,
              style: baseStyle.copyWith(
                fontFamilyFallback: const [
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
              ),
            ),
          );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}
