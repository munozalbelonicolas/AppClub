import 'package:flutter/material.dart';

/// Widget reutilizable que renderiza texto reemplazando emojis de corazón
/// por íconos vectoriales [Icons.favorite] con el color correcto.
///
/// Esto evita el problema de Android donde algunos emojis de corazón
/// (❤, 🖤, etc.) se renderizan en su forma "text presentation" (gris y
/// pequeña) en vez de la variante de color.
///
/// Úsalo como reemplazo directo de [Text] en cualquier lugar donde el
/// contenido pueda incluir emojis de corazón.
class EmojiRichText extends StatelessWidget {
  const EmojiRichText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.darkBackground = false,
  });

  /// El texto a renderizar (puede contener emojis de corazón).
  final String text;

  /// Estilo base del texto.
  final TextStyle? style;

  /// Alineación del texto.
  final TextAlign? textAlign;

  /// Máximo de líneas.
  final int? maxLines;

  /// Overflow del texto.
  final TextOverflow? overflow;

  /// Si el fondo es oscuro, ajusta el borde del corazón negro (🖤)
  /// para que se distinga del fondo.
  final bool darkBackground;

  static final _heartRegex =
      RegExp(r'(❤️|❤|🖤|🤍|💚|💛|🧡|💙|💜|💔|💖|💗)');

  /// Verifica si el texto contiene algún emoji de corazón.
  /// Útil para decidir si usar este widget o un Text() simple.
  static bool containsHeartEmoji(String text) => _heartRegex.hasMatch(text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty || !_heartRegex.hasMatch(text)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final fontSize = baseStyle.fontSize ?? 14.0;
    final spans = <InlineSpan>[];

    int lastMatchEnd = 0;
    for (final match in _heartRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final emoji = match.group(0)!;
      spans.add(_buildHeartSpan(emoji, fontSize, baseStyle, context));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  InlineSpan _buildHeartSpan(
    String emoji,
    double fontSize,
    TextStyle baseStyle,
    BuildContext context,
  ) {
    switch (emoji) {
      case '❤️':
      case '❤':
      case '💖':
      case '💗':
        return _iconSpan(
          color: const Color(0xFFE53935),
          size: fontSize + 4,
        );
      case '🖤':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.favorite,
                  color: darkBackground ? Colors.white70 : Colors.grey.shade400,
                  size: fontSize + 5.5,
                ),
                Icon(
                  Icons.favorite,
                  color: const Color(0xFF141414),
                  size: fontSize + 3.5,
                ),
              ],
            ),
          ),
        );
      case '🤍':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.black45,
                  size: fontSize + 5.5,
                ),
                Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: fontSize + 3.5,
                ),
              ],
            ),
          ),
        );
      case '💚':
        return _iconSpan(
          color: const Color(0xFF43A047),
          size: fontSize + 4,
        );
      case '💛':
        return _iconSpan(
          color: const Color(0xFFFFD600),
          size: fontSize + 4,
        );
      case '🧡':
        return _iconSpan(
          color: const Color(0xFFFF9100),
          size: fontSize + 4,
        );
      case '💙':
        return _iconSpan(
          color: const Color(0xFF2979FF),
          size: fontSize + 4,
        );
      case '💜':
        return _iconSpan(
          color: const Color(0xFFAA00FF),
          size: fontSize + 4,
        );
      default:
        return TextSpan(text: emoji, style: baseStyle);
    }
  }

  WidgetSpan _iconSpan({required Color color, required double size}) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Icon(
          Icons.favorite,
          color: color,
          size: size,
        ),
      ),
    );
  }
}
