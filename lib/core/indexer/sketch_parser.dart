import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class SketchComponent {
  SketchComponent({
    required this.id,
    required this.name,
    required this.pagePath,
    required this.pageId,
    required this.layerData,
  });

  final String id;
  final String name;
  final String pagePath;
  final String pageId;
  // Full layer JSON so SketchToSvg can convert without re-reading the file
  final Map<String, dynamic> layerData;

  @override
  String toString() => 'SketchComponent(name: $name, id: $id)';
}

class SketchParser {
  /// Parses a Sketch library directory for components.
  ///
  /// Strategy:
  /// 1. Look at top-level layers of each page
  /// 2. If a top-level layer is a GROUP (not artboard/symbol), drill one level
  ///    deeper — kits like this one wrap everything in a single named group
  /// 3. Collect artboard, symbolMaster, AND named groups as components
  static Future<List<SketchComponent>> parseLibrary(Directory dir) async {
    final components = <SketchComponent>[];
    final seen = <String>{};

    final pagesDir = Directory(p.join(dir.path, 'pages'));
    if (!await pagesDir.exists()) return [];

    await for (final entity in pagesDir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.json')) continue;

      String content;
      try {
        content = await entity.readAsString();
      } catch (_) {
        continue;
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final pageId = json['do_objectID'] as String? ?? '';
      if (pageId.isEmpty) continue;

      final topLayers = json['layers'] as List<dynamic>?;
      if (topLayers == null) continue;

      for (final raw in topLayers) {
        if (raw is! Map<String, dynamic>) continue;

        final cls = raw['_class'] as String?;
        final id = raw['do_objectID'] as String?;
        final name = raw['name'] as String?;
        if (id == null || name == null) continue;

        // Artboard or symbol master at top level → index directly
        if (cls == 'artboard' || cls == 'symbolMaster') {
          if (!seen.contains(id)) {
            seen.add(id);
            components.add(SketchComponent(
              id: id,
              name: name,
              pagePath: entity.path,
              pageId: pageId,
              layerData: raw,
            ));
          }
          continue;
        }

        // Top-level group → this kit wraps components inside a group.
        // Drill one level deeper to find the real components.
        if (cls == 'group') {
          final sublayers = raw['layers'] as List<dynamic>?;
          if (sublayers == null || sublayers.isEmpty) continue;

          // Check if children look like individual components (named groups)
          // or if there's another wrapper level
          final children = sublayers
              .whereType<Map<String, dynamic>>()
              .toList();

          // If children are all groups with no artboard/symbol, treat each
          // child group as a component
          for (final child in children) {
            final childCls = child['_class'] as String?;
            final childId = child['do_objectID'] as String?;
            final childName = child['name'] as String?;

            if (childId == null || childName == null) continue;
            if (seen.contains(childId)) continue;

            if (childCls == 'artboard' ||
                childCls == 'symbolMaster' ||
                childCls == 'group') {
              seen.add(childId);
              components.add(SketchComponent(
                id: childId,
                name: childName,
                pagePath: entity.path,
                pageId: pageId,
                layerData: child,
              ));
            }
          }
        }
      }
    }

    components.sort((a, b) => a.name.compareTo(b.name));
    return components;
  }
}