import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_management/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SubscriptionApp());
    expect(find.text('My Subscriptions'), findsOneWidget);
  });
}
