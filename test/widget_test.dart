import 'package:flutter_test/flutter_test.dart';

import 'package:filmcam_papi/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FilmCamApp());
    expect(find.text('FilmCam Papi'), findsOneWidget);
  });
}
