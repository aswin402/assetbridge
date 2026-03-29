import 'dart:convert';
import 'dart:io';

/// Converts a Sketch component layer (from unzipped JSON) to an SVG string
/// that Lunacy accepts as native vectors when copy-pasted.
class SketchToSvg {
  /// Convert a component by ID from a page JSON file.
  static Future<String?> componentToSvg({
    required String rootPath,
    required String pagePath,
    required String componentId,
  }) async {
    final pageFile = File(pagePath);
    if (!await pageFile.exists()) return null;

    Map<String, dynamic> pageJson;
    try {
      pageJson = jsonDecode(await pageFile.readAsString());
    } catch (_) {
      return null;
    }

    // Search top-level layers AND one level deep (wrapped groups)
    final layer = _findLayer(pageJson['layers'] as List<dynamic>?, componentId);
    if (layer == null) return null;

    return _layerToSvgString(layer);
  }

  /// Convert a layer map directly (used when we already have layerData).
  static Future<String?> artboardToSvg(Map<String, dynamic> layer) async {
    return _layerToSvgString(layer);
  }

  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _findLayer(
      List<dynamic>? layers, String targetId) {
    if (layers == null) return null;
    for (final l in layers) {
      if (l is! Map<String, dynamic>) continue;
      if (l['do_objectID'] == targetId) return l;
      // Search one level deep inside groups
      final sub = l['layers'] as List<dynamic>?;
      if (sub != null) {
        final found = _findLayer(sub, targetId);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String _layerToSvgString(Map<String, dynamic> layer) {
    final frame = _getFrame(layer);
    final w = frame['width']!;
    final h = frame['height']!;

    final buf = StringBuffer();
    buf.write('<svg xmlns="http://www.w3.org/2000/svg" '
        'width="${_n(w)}" height="${_n(h)}" '
        'viewBox="0 0 ${_n(w)} ${_n(h)}">');

    _writeLayer(layer, buf, offsetX: 0, offsetY: 0, isRoot: true);

    buf.write('</svg>');
    return buf.toString();
  }

  static void _writeLayer(
    Map<String, dynamic> layer,
    StringBuffer buf, {
    required double offsetX,
    required double offsetY,
    bool isRoot = false,
  }) {
    final visible = layer['isVisible'] as bool? ?? true;
    if (!visible) return;

    final cls = layer['_class'] as String? ?? '';
    if (cls == 'slice') return;

    final frame = _getFrame(layer);
    final x = isRoot ? 0.0 : (frame['x']! + offsetX);
    final y = isRoot ? 0.0 : (frame['y']! + offsetY);
    final w = frame['width']!;
    final h = frame['height']!;

    // Style is nested under 'style' key in this kit's format
    final style = layer['style'] as Map<String, dynamic>?;

    final opacity = _getOpacity(layer, style);
    final opacityAttr = opacity < 0.999 ? ' opacity="${_n(opacity)}"' : '';

    final rotation = (layer['rotation'] as num?)?.toDouble() ?? 0.0;
    final cx = x + w / 2;
    final cy = y + h / 2;
    final transformAttr = rotation != 0.0
        ? ' transform="rotate(${_n(-rotation)} ${_n(cx)} ${_n(cy)})"'
        : '';

    switch (cls) {
      case 'rectangle':
        final fill = _fill(style);
        final stroke = _stroke(style);
        final r = (layer['cornerRadius'] as num?)?.toDouble() ?? 0.0;
        final rxAttr = r > 0 ? ' rx="${_n(r)}"' : '';
        buf.write('<rect x="${_n(x)}" y="${_n(y)}" '
            'width="${_n(w)}" height="${_n(h)}"'
            '$rxAttr$fill$stroke$opacityAttr$transformAttr/>');

      case 'oval':
        final fill = _fill(style);
        final stroke = _stroke(style);
        buf.write('<ellipse cx="${_n(x + w / 2)}" cy="${_n(y + h / 2)}" '
            'rx="${_n(w / 2)}" ry="${_n(h / 2)}"'
            '$fill$stroke$opacityAttr$transformAttr/>');

      case 'shapePath':
        final d = _pointsToD(layer, x, y, w, h);
        if (d == null) return;
        final fill = _fill(style);
        final stroke = _stroke(style);
        buf.write('<path d="$d"$fill$stroke$opacityAttr$transformAttr/>');

      case 'shapeGroup':
        final fill = _fill(style);
        final stroke = _stroke(style);
        final sublayers = layer['layers'] as List<dynamic>? ?? [];
        final paths = <String>[];
        for (final child in sublayers) {
          if (child is! Map<String, dynamic>) continue;
          final cf = _getFrame(child);
          final d = _pointsToD(
            child,
            x + cf['x']!,
            y + cf['y']!,
            cf['width']!,
            cf['height']!,
          );
          if (d != null) paths.add(d);
        }
        if (paths.isEmpty) return;
        buf.write('<path d="${paths.join(' ')}"'
            '$fill$stroke$opacityAttr$transformAttr/>');

      case 'text':
        _writeText(layer, buf, x, y, opacityAttr);

      case 'group':
      case 'artboard':
      case 'symbolMaster':
      case 'symbolInstance':
      default:
        final sublayers = layer['layers'] as List<dynamic>?;
        if (sublayers == null || sublayers.isEmpty) return;
        buf.write('<g$opacityAttr$transformAttr>');
        for (final child in sublayers) {
          if (child is! Map<String, dynamic>) continue;
          _writeLayer(child, buf, offsetX: x, offsetY: y);
        }
        buf.write('</g>');
    }
  }

  // ---------------------------------------------------------------------------
  // Points → SVG path d
  // ---------------------------------------------------------------------------

  static String? _pointsToD(
    Map<String, dynamic> layer,
    double x,
    double y,
    double w,
    double h,
  ) {
    final points = layer['points'] as List<dynamic>?;
    if (points == null || points.isEmpty) return null;

    final isClosed = layer['isClosed'] as bool? ?? true;
    final buf = StringBuffer();
    bool first = true;

    for (var i = 0; i < points.length; i++) {
      final pt = points[i] as Map<String, dynamic>;
      final pos = _pt(pt['point'] as String?, w, h, x, y);
      if (pos == null) continue;

      if (first) {
        buf.write('M ${_n(pos[0])} ${_n(pos[1])}');
        first = false;
      }

      final nextIdx = (i + 1) % points.length;
      if (!isClosed && nextIdx == 0) break;

      final ptNext = points[nextIdx] as Map<String, dynamic>;
      final nextPos = _pt(ptNext['point'] as String?, w, h, x, y);
      if (nextPos == null) continue;

      final curveMode = pt['curveMode'] as int? ?? 1;
      if (curveMode == 1) {
        buf.write(' L ${_n(nextPos[0])} ${_n(nextPos[1])}');
      } else {
        final cp1 = _pt(pt['curveFrom'] as String?, w, h, x, y);
        final cp2 = _pt(ptNext['curveTo'] as String?, w, h, x, y);
        if (cp1 != null && cp2 != null) {
          buf.write(' C ${_n(cp1[0])} ${_n(cp1[1])}'
              ' ${_n(cp2[0])} ${_n(cp2[1])}'
              ' ${_n(nextPos[0])} ${_n(nextPos[1])}');
        } else {
          buf.write(' L ${_n(nextPos[0])} ${_n(nextPos[1])}');
        }
      }
    }

    if (isClosed && !first) buf.write(' Z');
    return first ? null : buf.toString();
  }

  static List<double>? _pt(
      String? raw, double w, double h, double ox, double oy) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[{}]'), '').trim();
    final parts = cleaned.split(',');
    if (parts.length < 2) return null;
    final nx = double.tryParse(parts[0].trim());
    final ny = double.tryParse(parts[1].trim());
    if (nx == null || ny == null) return null;
    return [ox + nx * w, oy + ny * h];
  }

  // ---------------------------------------------------------------------------
  // Style helpers — handles BOTH direct fill and style-wrapped fill
  // ---------------------------------------------------------------------------

  static String _fill(Map<String, dynamic>? style) {
    final fills = style?['fills'] as List<dynamic>?;
    if (fills == null || fills.isEmpty) return ' fill="none"';

    for (final f in fills) {
      if (f is! Map<String, dynamic>) continue;
      if (!(f['isEnabled'] as bool? ?? true)) continue;

      final fillType = f['fillType'] as int? ?? 0;
      if (fillType == 0) {
        // Solid color
        final c = f['color'] as Map<String, dynamic>?;
        if (c == null) continue;
        final hex = _hex(c);
        final a = (c['alpha'] as num?)?.toDouble() ?? 1.0;
        return a < 0.999
            ? ' fill="$hex" fill-opacity="${_n(a)}"'
            : ' fill="$hex"';
      }
      if (fillType == 1) {
        // Gradient — use first stop color as approximation
        final grad = f['gradient'] as Map<String, dynamic>?;
        final stops = grad?['stops'] as List<dynamic>?;
        if (stops != null && stops.isNotEmpty) {
          final first = stops.first as Map<String, dynamic>?;
          final c = first?['color'] as Map<String, dynamic>?;
          if (c != null) return ' fill="${_hex(c)}"';
        }
      }
    }
    return ' fill="none"';
  }

  static String _stroke(Map<String, dynamic>? style) {
    final borders = style?['borders'] as List<dynamic>?;
    if (borders == null || borders.isEmpty) return '';
    for (final b in borders) {
      if (b is! Map<String, dynamic>) continue;
      if (!(b['isEnabled'] as bool? ?? true)) continue;
      final c = b['color'] as Map<String, dynamic>?;
      if (c == null) continue;
      final thickness = (b['thickness'] as num?)?.toDouble() ?? 1.0;
      return ' stroke="${_hex(c)}" stroke-width="${_n(thickness)}"';
    }
    return '';
  }

  static double _getOpacity(
      Map<String, dynamic> layer, Map<String, dynamic>? style) {
    // opacity can be on contextSettings OR directly on style
    final ctx = layer['contextSettings'] as Map<String, dynamic>?;
    if (ctx != null) {
      final op = (ctx['opacity'] as num?)?.toDouble();
      if (op != null) return op;
    }
    final styleCtx = style?['contextSettings'] as Map<String, dynamic>?;
    if (styleCtx != null) {
      final op = (styleCtx['opacity'] as num?)?.toDouble();
      if (op != null) return op;
    }
    return 1.0;
  }

  static void _writeText(
    Map<String, dynamic> layer,
    StringBuffer buf,
    double x,
    double y,
    String opacityAttr,
  ) {
    final attrStr = layer['attributedString'] as Map<String, dynamic>?;
    final text = attrStr?['string'] as String? ?? '';
    if (text.isEmpty) return;

    final attrs = (attrStr?['attributes'] as List<dynamic>?)
        ?.firstOrNull as Map<String, dynamic>?;
    final styleAttrs = attrs?['attributes'] as Map<String, dynamic>?;

    final fontAttrs =
        (styleAttrs?['MSAttributedStringFontAttribute'] as Map<String, dynamic>?)?
            ['attributes'] as Map<String, dynamic>?;
    final fontSize = (fontAttrs?['size'] as num?)?.toDouble() ?? 14.0;

    final colorMap = styleAttrs?['MSAttributedStringColorAttribute']
        as Map<String, dynamic>?;
    final color = colorMap != null ? _hex(colorMap) : '#000000';

    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    buf.write('<text x="${_n(x)}" y="${_n(y + fontSize)}" '
        'font-size="${_n(fontSize)}" fill="$color"$opacityAttr>'
        '$escaped</text>');
  }

  // ---------------------------------------------------------------------------
  // Frame / number helpers
  // ---------------------------------------------------------------------------

  static Map<String, double> _getFrame(Map<String, dynamic> layer) {
    final frame = layer['frame'] as Map<String, dynamic>?;
    return {
      'x': (frame?['x'] as num?)?.toDouble() ?? 0,
      'y': (frame?['y'] as num?)?.toDouble() ?? 0,
      'width': (frame?['width'] as num?)?.toDouble() ?? 0,
      'height': (frame?['height'] as num?)?.toDouble() ?? 0,
    };
  }

  static String _hex(Map<String, dynamic> c) {
    final r = ((c['red'] as num?)?.toDouble() ?? 0) * 255;
    final g = ((c['green'] as num?)?.toDouble() ?? 0) * 255;
    final b = ((c['blue'] as num?)?.toDouble() ?? 0) * 255;
    return '#'
        '${r.round().toRadixString(16).padLeft(2, '0')}'
        '${g.round().toRadixString(16).padLeft(2, '0')}'
        '${b.round().toRadixString(16).padLeft(2, '0')}';
  }

  static String _n(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}