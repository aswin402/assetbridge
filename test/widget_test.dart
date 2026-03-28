import 'package:assetbridge/app.dart';
import 'package:assetbridge/core/database/app_database.dart';
import 'package:assetbridge/core/database/database_provider.dart';
import 'package:assetbridge/features/library/library_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('AssetBridge shell shows title and empty state', (WidgetTester tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          packsStreamProvider.overrideWithValue(const AsyncData([])),
          allAssetsStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const AssetBridgeApp(),
      ),
    );
    await tester.pump();

    expect(find.text('AssetBridge'), findsOneWidget);
    expect(find.text('No packs yet'), findsOneWidget);
    expect(find.text('PACKS'), findsOneWidget);
  });
}
