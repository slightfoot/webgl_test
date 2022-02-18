import 'dart:async';
import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl' as webgl;

import 'package:vector_math/vector_math.dart';
import 'package:webgltest/base.dart';

class TestWebGL extends BaseWebGL {
  late webgl.Program _shaderProgram;
  late webgl.Buffer _cubeVertexPositionBuffer;
  late webgl.Buffer _cubeVertexTextureCoordBuffer;
  late webgl.Buffer _cubeVertexIndexBuffer;

  late final List<webgl.Texture> _textures;

  final _pMatrix = Matrix4.identity();
  final _mvMatrix = Matrix4.identity();

  late int _aVertexPosition;
  late int _aTextureCoord;
  late webgl.UniformLocation _uPMatrix;
  late webgl.UniformLocation _uMVMatrix;
  late webgl.UniformLocation _samplerUniform;

  double _xRot = 0.0, _xSpeed = 0.0, _yRot = 0.0, _ySpeed = 0.0, _zPos = -5.0;
  int _filter = 0;

  final _currentlyPressedKeys = List.filled(128, false);

  TestWebGL(CanvasElement elm) {
    gl = elm.getContext('webgl') as webgl.RenderingContext;
    gl.clearColor(1, 1, 1, 1.0);
    gl.enable(webgl.WebGL.DEPTH_TEST);

    document.onKeyDown.listen(_handleKeyDown);
    document.onKeyUp.listen(_handleKeyUp);
  }

  void _handleKeyDown(KeyboardEvent event) {
    if ("F".codeUnitAt(0) == event.keyCode) {
      _filter++;
      if (_filter == 3) {
        _filter = 0;
      }
    } else {
      _currentlyPressedKeys[event.keyCode] = true;
    }
  }

  void _handleKeyUp(KeyboardEvent event) {
    _currentlyPressedKeys[event.keyCode] = false;
  }

  Future<void> init() async {
    _initShaders();
    _initBuffers();
    await _initTexture();
  }

  void _initShaders() {
    // vertex shader source code.
    String vsSource = """
    attribute vec3 aVertexPosition;
    attribute vec4 aTextureCoord;
    
    uniform mat4 uMVMatrix;
    uniform mat4 uPMatrix;
    
    varying vec4 vTextureCoord;
    
    void main(void) {
        gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
        vTextureCoord = aTextureCoord;
    }
    """;

    // fragment shader source code.
    String fsSource = """
    precision mediump float;
    
    varying vec4 vTextureCoord;
    
    uniform sampler2D uSampler;
    
    void main(void) {
        gl_FragColor = texture2D(uSampler, vec2(vTextureCoord.s, vTextureCoord.t));
    }
    """;

    // vertex shader compilation
    final vs = gl.createShader(webgl.WebGL.VERTEX_SHADER);
    gl.shaderSource(vs, vsSource);
    gl.compileShader(vs);

    // fragment shader compilation
    final fs = gl.createShader(webgl.WebGL.FRAGMENT_SHADER);
    gl.shaderSource(fs, fsSource);
    gl.compileShader(fs);

    // attach shaders to a WebGL program
    _shaderProgram = gl.createProgram();
    gl.attachShader(_shaderProgram, vs);
    gl.attachShader(_shaderProgram, fs);
    gl.linkProgram(_shaderProgram);
    gl.useProgram(_shaderProgram);

    /**
     * Check if shaders were compiled properly. This is probably the most painful part
     * since there's no way to "debug" shader compilation
     */
    if (!(gl.getShaderParameter(vs, webgl.WebGL.COMPILE_STATUS) as bool)) {
      print(gl.getShaderInfoLog(vs));
    }

    if (!(gl.getShaderParameter(fs, webgl.WebGL.COMPILE_STATUS) as bool)) {
      print(gl.getShaderInfoLog(fs));
    }

    if (!(gl.getProgramParameter(_shaderProgram, webgl.WebGL.LINK_STATUS) as bool)) {
      print(gl.getProgramInfoLog(_shaderProgram));
    }

    _aVertexPosition = gl.getAttribLocation(_shaderProgram, "aVertexPosition");
    gl.enableVertexAttribArray(_aVertexPosition);

    _aTextureCoord = gl.getAttribLocation(_shaderProgram, "aTextureCoord");
    gl.enableVertexAttribArray(_aTextureCoord);

    _uPMatrix = gl.getUniformLocation(_shaderProgram, "uPMatrix");
    _uMVMatrix = gl.getUniformLocation(_shaderProgram, "uMVMatrix");
    _samplerUniform = gl.getUniformLocation(_shaderProgram, "uSampler");
  }

  void _initBuffers() {
    // create cube
    _cubeVertexPositionBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexPositionBuffer);
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList([
        // Front face
        -1.0, -1.0, 1.0,
        1.0, -1.0, 1.0,
        1.0, 1.0, 1.0,
        -1.0, 1.0, 1.0,
        // Back face
        -1.0, -1.0, -1.0,
        -1.0, 1.0, -1.0,
        1.0, 1.0, -1.0,
        1.0, -1.0, -1.0,
        // Top face
        -1.0, 1.0, -1.0,
        -1.0, 1.0, 1.0,
        1.0, 1.0, 1.0,
        1.0, 1.0, -1.0,
        // Bottom face
        -1.0, -1.0, -1.0,
        1.0, -1.0, -1.0,
        1.0, -1.0, 1.0,
        -1.0, -1.0, 1.0,
        // Right face
        1.0, -1.0, -1.0,
        1.0, 1.0, -1.0,
        1.0, 1.0, 1.0,
        1.0, -1.0, 1.0,
        // Left face
        -1.0, -1.0, -1.0,
        -1.0, -1.0, 1.0,
        -1.0, 1.0, 1.0,
        -1.0, 1.0, -1.0,
      ]),
      webgl.WebGL.STATIC_DRAW,
    );

    _cubeVertexTextureCoordBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexTextureCoordBuffer);
    final textureCoords = <double>[
      // Front face
      0.0, 0.0,
      1.0, 0.0,
      1.0, 1.0,
      0.0, 1.0,

      // Back face
      1.0, 0.0,
      1.0, 1.0,
      0.0, 1.0,
      0.0, 0.0,

      // Top face
      0.0, 1.0,
      0.0, 0.0,
      1.0, 0.0,
      1.0, 1.0,

      // Bottom face
      1.0, 1.0,
      0.0, 1.0,
      0.0, 0.0,
      1.0, 0.0,

      // Right face
      1.0, 0.0,
      1.0, 1.0,
      0.0, 1.0,
      0.0, 0.0,

      // Left face
      0.0, 0.0,
      1.0, 0.0,
      1.0, 1.0,
      0.0, 1.0,
    ];
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList(textureCoords),
      webgl.WebGL.STATIC_DRAW,
    );

    _cubeVertexIndexBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ELEMENT_ARRAY_BUFFER, _cubeVertexIndexBuffer);
    final _cubeVertexIndices = <int>[
      0, 1, 2, 0, 2, 3, // Front face
      4, 5, 6, 4, 6, 7, // Back face
      8, 9, 10, 8, 10, 11, // Top face
      12, 13, 14, 12, 14, 15, // Bottom face
      16, 17, 18, 16, 18, 19, // Right face
      20, 21, 22, 20, 22, 23 // Left face
    ];
    gl.bufferData(
      webgl.WebGL.ELEMENT_ARRAY_BUFFER,
      Uint16List.fromList(_cubeVertexIndices),
      webgl.WebGL.STATIC_DRAW,
    );
  }

  Future<void> _initTexture() async {
    final textureLoaded = Completer<void>();

    _textures = List.generate(3, (index) => gl.createTexture());
    final image = Element.tag('img') as ImageElement;
    image.onLoad.listen((e) {
      _handleLoadedTexture(_textures, image);
      textureLoaded.complete();
    });
    image.src = "images/crate.gif";
    return textureLoaded.future;
  }

  void _handleLoadedTexture(List<webgl.Texture> textures, ImageElement img) {
    gl.pixelStorei(
        webgl.WebGL.UNPACK_FLIP_Y_WEBGL, 1); // second argument must be an int (no boolean)

    gl.bindTexture(webgl.WebGL.TEXTURE_2D, textures[0]);
    gl.texImage2D(webgl.WebGL.TEXTURE_2D, 0, webgl.WebGL.RGBA, webgl.WebGL.RGBA,
        webgl.WebGL.UNSIGNED_BYTE, img);
    gl.texParameteri(webgl.WebGL.TEXTURE_2D, webgl.WebGL.TEXTURE_MAG_FILTER, webgl.WebGL.NEAREST);
    gl.texParameteri(webgl.WebGL.TEXTURE_2D, webgl.WebGL.TEXTURE_MIN_FILTER, webgl.WebGL.NEAREST);

    gl.bindTexture(webgl.WebGL.TEXTURE_2D, textures[1]);
    gl.texImage2D(webgl.WebGL.TEXTURE_2D, 0, webgl.WebGL.RGBA, webgl.WebGL.RGBA,
        webgl.WebGL.UNSIGNED_BYTE, img);
    gl.texParameteri(webgl.WebGL.TEXTURE_2D, webgl.WebGL.TEXTURE_MAG_FILTER, webgl.WebGL.LINEAR);
    gl.texParameteri(webgl.WebGL.TEXTURE_2D, webgl.WebGL.TEXTURE_MIN_FILTER, webgl.WebGL.LINEAR);

    gl.bindTexture(webgl.WebGL.TEXTURE_2D, textures[2]);
    gl.texImage2D(webgl.WebGL.TEXTURE_2D, 0, webgl.WebGL.RGBA, webgl.WebGL.RGBA,
        webgl.WebGL.UNSIGNED_BYTE, img);
    gl.texParameteri(webgl.WebGL.TEXTURE_2D, webgl.WebGL.TEXTURE_MAG_FILTER, webgl.WebGL.LINEAR);
    gl.texParameteri(
        webgl.WebGL.TEXTURE_2D, webgl.WebGL.TEXTURE_MIN_FILTER, webgl.WebGL.LINEAR_MIPMAP_NEAREST);
    gl.generateMipmap(webgl.WebGL.TEXTURE_2D);

    gl.bindTexture(webgl.WebGL.TEXTURE_2D, null);
  }

  void _updateMatrixUniforms() {
    gl.uniformMatrix4fv(_uPMatrix, false, _pMatrix.storage);
    gl.uniformMatrix4fv(_uMVMatrix, false, _mvMatrix.storage);
  }

  void resizeCanvasToDisplaySize() {
    final width = gl.canvas.clientWidth;
    final height = gl.canvas.clientHeight;
    final needResize = gl.canvas.width != width || gl.canvas.height != height;
    if (needResize) {
      // print('resize: ${gl.canvas.width!} x ${gl.canvas.height} -> $width x $height');
      // Make the canvas the same size
      gl.canvas.width = width;
      gl.canvas.height = height;
      gl.viewport(0, 0, width, height);
      // field of view is 45°, width-to-height ratio, hide things closer than 0.1 or further than 100
      _pMatrix.setFrom(makePerspectiveMatrix(radians(45.0), width / height, 0.1, 100.0));
    }
  }

  @override
  void render([double time = 0]) {
    resizeCanvasToDisplaySize();

    gl.clear(webgl.WebGL.COLOR_BUFFER_BIT | webgl.WebGL.DEPTH_BUFFER_BIT);

    _mvMatrix.setIdentity();
    _mvMatrix.translate(Vector3(0.0, 0.0, _zPos));

    _mvMatrix.rotate(Vector3(1.0, 0.0, 0.0), radians(_xRot));
    _mvMatrix.rotate(Vector3(0.0, 1.0, 0.0), radians(_yRot));

    // vertices
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexPositionBuffer);
    gl.vertexAttribPointer(_aVertexPosition, 3, webgl.WebGL.FLOAT, false, 0, 0);

    // texture
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexTextureCoordBuffer);
    gl.vertexAttribPointer(_aTextureCoord, 2, webgl.WebGL.FLOAT, false, 0, 0);

    gl.activeTexture(webgl.WebGL.TEXTURE0);
    gl.bindTexture(webgl.WebGL.TEXTURE_2D, _textures[_filter]);
    gl.uniform1i(_samplerUniform, 0);

    gl.bindBuffer(webgl.WebGL.ELEMENT_ARRAY_BUFFER, _cubeVertexIndexBuffer);
    _updateMatrixUniforms();
    gl.drawElements(webgl.WebGL.TRIANGLES, 36, webgl.WebGL.UNSIGNED_SHORT, 0);

    // rotate
    _animate(time);
    _handleKeys();
  }

  void _animate(double time) {
    _xRot += (_xSpeed * time) / 1000.0;
    _yRot += (_ySpeed * time) / 1000.0;
  }

  void _handleKeys() {
    // Page Up
    if (_currentlyPressedKeys.elementAt(33)) {
      _zPos -= 0.05;
    }
    // Page Down
    if (_currentlyPressedKeys.elementAt(34)) {
      _zPos += 0.05;
    }
    // Left cursor key
    if (_currentlyPressedKeys.elementAt(37)) {
      _ySpeed -= 1;
    }
    // Right cursor key
    if (_currentlyPressedKeys.elementAt(39)) {
      _ySpeed += 1;
    }
    // Up cursor key
    if (_currentlyPressedKeys.elementAt(38)) {
      _xSpeed -= 1;
    }
    // Down cursor key
    if (_currentlyPressedKeys.elementAt(40)) {
      _xSpeed += 1;
    }
  }

  @override
  void shutdown() {
    freeBuffers([
      _cubeVertexPositionBuffer,
      _cubeVertexTextureCoordBuffer,
      _cubeVertexIndexBuffer,
    ]);
    freePrograms([_shaderProgram]);
    freeTextures(_textures);
    freeVertexAttributes(2);
    super.shutdown();
  }
}
