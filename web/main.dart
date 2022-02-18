import 'dart:html';

import 'package:webgltest/test.dart';

void main() {
  final glTest = TestWebGL(document.querySelector('#output') as CanvasElement);
  final options = document.querySelector('#options')!;
  options.innerHtml = glTest.options;
  options.style.display = 'block';
  glTest.init().then((_) => glTest.start());
}
