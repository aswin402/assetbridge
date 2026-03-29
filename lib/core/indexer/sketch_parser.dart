import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  final Map<String, dynamic> layerData;

  @override
  String toString() => 'SketchComponent(name: $name, id: $id)';
}

class SketchParser {
  static Future<List<SketchComponent>> parseLibrary(Directory dir) async {
    final components = <SketchComponent>[];
    final seen = <String>{};

    final pagesDir = Directory(p.join(dir.path, 'pages'));
    if (!await pagesDir.exists()) {
      if (kDebugMode) print('SketchParser: pages directory not found at ${pagesDir.path}');
      return [];
    }

    await for (final entity in pagesDir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.json')) continue;

      if (kDebugMode) print('SketchParser: Analyzing page at ${p.basename(entity.path)}');

      String content;
      try {
        content = await entity.readAsString();
      } catch (e) {
        if (kDebugMode) print('SketchParser: Failed to read: $e');
        continue;
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) print('SketchParser: Failed to parse JSON: $e');
        continue;
      }

      final pageId = json['do_objectID'] as String? ?? '';
      if (pageId.isEmpty) continue;

      final layers = json['layers'] as List<dynamic>?;
      if (layers == null) {
        if (kDebugMode) print('SketchParser: File has no layers key, skipping');
        continue;
      }

      _collectComponents(
        layers: layers,
        components: components,
        seen: seen,
        pagePath: entity.path,
        pageId: pageId,
      );
    }

    components.sort((a, b) => a.name.compareTo(b.name));
    if (kDebugMode) print('SketchParser: Finished indexing. Found ${components.length} components.');
    return components;
  }

  static void _collectComponents({
    required List<dynamic> layers,
    required List<SketchComponent> components,
    required Set<String> seen,
    required String pagePath,
    required String pageId,
    int depth = 0,
  }) {
    for (final raw in layers) {
      if (raw is! Map<String, dynamic>) continue;

      final cls = raw['_class'] as String?;
      final id = raw['do_objectID'] as String?;
      final name = raw['name'] as String?;
      if (id == null || name == null) continue;

      final children = (raw['layers'] as List<dynamic>?) ?? [];

      // ── Symbol Masters: always capture directly ──────────────────────────
      if (cls == 'symbolMaster') {
        if (!seen.contains(id)) {
          seen.add(id);
          components.add(SketchComponent(
            id: id,
            name: name,
            pagePath: pagePath,
            pageId: pageId,
            layerData: raw,
          ));
        }
        continue;
      }

      // ── Artboards ────────────────────────────────────────────────────────
      if (cls == 'artboard') {
        // If the artboard has multiple group children, treat children as items
        // (e.g. "Avatars" artboard wrapping "User 01a", "User 01b", ...)
        final groupChildren = children
            .whereType<Map<String, dynamic>>()
            .where((c) =>
                c['_class'] == 'group' ||
                c['_class'] == 'symbolMaster' ||
                c['_class'] == 'artboard')
            .toList();

        if (groupChildren.length > 1) {
          // Multiple named children → each child is a component
          if (kDebugMode) {
            print('SketchParser: Artboard "$name" has ${groupChildren.length} child components. Expanding.');
          }
          _collectComponents(
            layers: children,
            components: components,
            seen: seen,
            pagePath: pagePath,
            pageId: pageId,
            depth: depth + 1,
          );
        } else {
          // Single or no children → artboard itself is the component
          if (!seen.contains(id)) {
            seen.add(id);
            components.add(SketchComponent(
              id: id,
              name: name,
              pagePath: pagePath,
              pageId: pageId,
              layerData: raw,
            ));
          }
        }
        continue;
      }

      // ── Groups at top-most call level (direct page children) ─────────────
      if (cls == 'group' && depth == 0) {
        // A top-level group is likely a category wrapper; drill into it
        _collectComponents(
          layers: children,
          components: components,
          seen: seen,
          pagePath: pagePath,
          pageId: pageId,
          depth: depth + 1,
        );
        continue;
      }

      // ── Groups at deeper levels → treat as individual components ─────────
      if (cls == 'group' && depth > 0) {
        if (!seen.contains(id)) {
          seen.add(id);
          components.add(SketchComponent(
            id: id,
            name: name,
            pagePath: pagePath,
            pageId: pageId,
            layerData: raw,
          ));
        }
        continue;
      }
    }
  }
}