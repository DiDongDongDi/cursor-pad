import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cursor_pad/app/app.dart';

void main() {
  testWidgets('App renders browser shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CursorPadApp(),
      ),
    );

    expect(find.byType(CursorPadApp), findsOneWidget);
  });
}
