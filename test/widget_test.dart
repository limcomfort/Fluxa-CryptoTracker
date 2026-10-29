import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_tracker/main.dart';

void main() {
  testWidgets('Fluxa boots to the Markets tab', (tester) async {
    await tester.pumpWidget(const FluxaApp());
    await tester.pump(const Duration(milliseconds: 400));
    // The market summary strip only exists on the Markets tab.
    expect(find.text('Капитализация'), findsOneWidget);
  });
}
