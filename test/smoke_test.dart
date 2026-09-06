import 'package:flutter_test/flutter_test.dart';
import 'package:wasira/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const WasiraApp());
    expect(find.text('Wasira'), findsOneWidget);
  });
}
