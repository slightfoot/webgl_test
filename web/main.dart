import 'dart:html';

import 'package:webgltest/test.dart';

void main() {
  final glTest = TestWebGL(document.querySelector('#output') as CanvasElement);
  glTest.start();
}
