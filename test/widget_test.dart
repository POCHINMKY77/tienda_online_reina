// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tienda_online_reina/main.dart'; // Tu archivo principal

void main() {
  // Test actualizado para verificar que la app de la tienda carga la pantalla de Login
  testWidgets(
    'La aplicación carga la pantalla de inicio de sesión de la tienda',
    (WidgetTester tester) async {
      // 1. Corregimos el error: Reemplazamos 'MyApp()' con 'TiendaOnlineReinaApp()'
      await tester.pumpWidget(const TiendaOnlineReinaApp());

      // 2. Verificamos elementos clave de la pantalla de Login:
      // Debe encontrar el título de la tienda
      expect(find.text('TIENDA REINA'), findsOneWidget);

      // Debe encontrar el título de la sección de autenticación
      expect(find.text('Iniciar Sesión'), findsOneWidget);

      // Debe encontrar el botón para entrar
      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
    },
  );
}
