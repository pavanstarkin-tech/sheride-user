import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_user/app.dart';

void main() {
  testWidgets('SheRide User App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SheRideUserApp());
    expect(find.byType(SheRideUserApp), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
