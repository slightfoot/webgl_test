import 'dart:async';
import 'dart:html';
import 'dart:web_gl';

abstract class BaseWebGL {
  late RenderingContext gl;
  Completer<void>? shutdownCompleter;
  int? _animFrameId;
  double? _elapsedTime;
  bool _stop = false;

  void render([double time = 0]);

  void start() {
    _renderFrame();
  }

  void _renderFrame() {
    if (_stop) {
      final animFrameId = _animFrameId;
      if (animFrameId != null) {
        window.cancelAnimationFrame(animFrameId);
      }
      shutdown();
    } else {
      _animFrameId = window.requestAnimationFrame((num time) {
        //print('render $time');
        _elapsedTime ??= time.toDouble();
        render(time - _elapsedTime!);
        _elapsedTime = time.toDouble();
        _renderFrame();
      });
    }
  }

  Future<void> stop() {
    _stop = true;
    shutdownCompleter = Completer<void>();
    return shutdownCompleter!.future;
  }

  void shutdown() {
    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
    gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, null);
    gl.bindRenderbuffer(WebGL.RENDERBUFFER, null);
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, null);
    shutdownCompleter?.complete();
  }

  void freeBuffers(List<Buffer> buffers) {
    for (var buf in buffers) {
      gl.deleteBuffer(buf);
    }
  }

  void freePrograms(List<Program> programs) {
    for (var program in programs) {
      gl.deleteProgram(program);
    }
  }

  void freeShaders(List<Shader> shaders) {
    for (var shader in shaders) {
      gl.deleteShader(shader);
    }
  }

  void freeVertexAttributes(List<int> attribs) {
    for (var attr in attribs) {
      gl.disableVertexAttribArray(attr);
    }
  }

  void freeTextures(List<Texture> textures) {
    for (int i = 0; i < textures.length; i++) {
      var tex = textures[i];
      gl.activeTexture(WebGL.TEXTURE0 + i);
      gl.bindTexture(WebGL.TEXTURE_2D, null);
      gl.bindTexture(WebGL.TEXTURE_CUBE_MAP, null);
      gl.deleteTexture(tex);
    }
  }
}
