import 'package:flutter_test/flutter_test.dart';
import 'package:roboline_mobile/main.dart'; // Senin projenin ana dosyası

void main() {
  testWidgets('Uygulama basariyla basliyor mu testi', (
    WidgetTester tester,
  ) async {
    // Uygulamamızı test ortamında ayağa kaldırıyoruz
    await tester.pumpWidget(const RoboLineApp());

    // Uygulamanın ana sınıfının (RoboLineApp) ekrana başarıyla çizildiğini doğrula
    expect(find.byType(RoboLineApp), findsOneWidget);
  });
}
