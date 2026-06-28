import 'package:flutter_test/flutter_test.dart';

import 'package:sanket/main.dart';

void main() {
  testWidgets('shows Sanket branding and home experience', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Sanket'), findsWidgets);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Speech to Sign'), findsOneWidget);
    expect(find.textContaining('Conversation'), findsNothing);
  });
}
