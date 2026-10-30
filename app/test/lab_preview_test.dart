import 'package:flutter_test/flutter_test.dart';
import 'package:uninews/main.dart' as app;

void main() {
  testWidgets(
    'unconfigured startup stays offline and labels fictional content',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      expect(find.text('IN DEVELOPMENT · LAB PREVIEW'), findsOneWidget);
      expect(find.text('FICTIONAL EXAMPLE · ACADEMIC'), findsOneWidget);
    },
  );
}
