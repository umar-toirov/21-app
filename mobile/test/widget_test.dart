import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ilm_mode/app.dart';

void main() {
  testWidgets('App smoke test placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: IlmModeApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
