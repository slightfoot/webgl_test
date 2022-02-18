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
  late webgl.Buffer _cubeVertexNormalBuffer;

  late webgl.Texture _texture;

  final _pMatrix = Matrix4.identity();
  final _mvMatrix = Matrix4.identity();

  late int _aVertexPosition;
  late int _aTextureCoord;
  late int _aVertexNormal;
  late webgl.UniformLocation _uPMatrix;
  late webgl.UniformLocation _uMVMatrix;
  late webgl.UniformLocation _uNMatrix;
  late webgl.UniformLocation _uSampler;
  late webgl.UniformLocation _uUseLighting;
  late webgl.UniformLocation _uLightingDirection;
  late webgl.UniformLocation _uAmbientColor;
  late webgl.UniformLocation _uDirectionalColor;

  late InputElement _elmLighting;
  late InputElement _elmAmbientR, _elmAmbientG, _elmAmbientB;
  late InputElement _elmLightDirectionX, _elmLightDirectionY, _elmLightDirectionZ;
  late InputElement _elmDirectionalR, _elmDirectionalG, _elmDirectionalB;

  double _xRot = 0.0, _xSpeed = 0.0, _yRot = 0.0, _ySpeed = 0.0, _zPos = -5.0;

  final _currentlyPressedKeys = List.filled(128, false);

  final options = """
    <input type="checkbox" id="lighting" checked><label for="lighting">Use lighting</label><br>
    <input type="range" id="ambientR" min="0" max="100"><label>Ambiant red</label><br>
    <input type="range" id="ambientG" min="0" max="100"><label>Ambiant green</label><br>
    <input type="range" id="ambientB" min="0" max="100"><label>Ambian blue</label><br>
    <input type="range" id="lightDirectionX" min="0" max="100"><label>Light direct x</label><br>
    <input type="range" id="lightDirectionY" min="0" max="100"><label>Light direction y</label><br>
    <input type="range" id="lightDirectionZ" min="0" max="100"><label>Light direction z</label><br>
    <input type="range" id="directionalR" min="0" max="100"><label>Directional light red</label><br>
    <input type="range" id="directionalG" min="0" max="100"><label>Directional light green</label><br>
    <input type="range" id="directionalB" min="0" max="100"><label>Directional light blue</label><br>
  """;

  TestWebGL(CanvasElement elm) {
    gl = elm.getContext('webgl') as webgl.RenderingContext;
    gl.clearColor(1, 1, 1, 1.0);
    gl.enable(webgl.WebGL.DEPTH_TEST);

    document.onKeyDown.listen(_handleKeyDown);
    document.onKeyUp.listen(_handleKeyUp);
  }

  void _handleKeyDown(KeyboardEvent event) {
    _currentlyPressedKeys[event.keyCode] = true;
  }

  void _handleKeyUp(KeyboardEvent event) {
    _currentlyPressedKeys[event.keyCode] = false;
  }

  Future<void> init() async {
    _initShaders();
    _initBuffers();
    await _initTexture();

    _elmLighting = document.querySelector("#lighting") as InputElement;
    _elmAmbientR = document.querySelector("#ambientR") as InputElement;
    _elmAmbientG = document.querySelector("#ambientG") as InputElement;
    _elmAmbientB = document.querySelector("#ambientB") as InputElement;
    _elmLightDirectionX = document.querySelector("#lightDirectionX") as InputElement;
    _elmLightDirectionY = document.querySelector("#lightDirectionY") as InputElement;
    _elmLightDirectionZ = document.querySelector("#lightDirectionZ") as InputElement;
    _elmDirectionalR = document.querySelector("#directionalR") as InputElement;
    _elmDirectionalG = document.querySelector("#directionalG") as InputElement;
    _elmDirectionalB = document.querySelector("#directionalB") as InputElement;
  }

  void _initShaders() {
    // vertex shader source code.
    String vsSource = """
    attribute vec3 aVertexPosition;
    attribute vec3 aVertexNormal;
    attribute vec2 aTextureCoord;
  
    uniform mat4 uMVMatrix;
    uniform mat4 uPMatrix;
    uniform mat3 uNMatrix;
  
    uniform vec3 uAmbientColor;
  
    uniform vec3 uLightingDirection;
    uniform vec3 uDirectionalColor;
  
    uniform bool uUseLighting;
  
    varying vec2 vTextureCoord;
    varying vec3 vLightWeighting;
  
    void main(void) {
      gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
      vTextureCoord = aTextureCoord;
 
      if (!uUseLighting) {
        vLightWeighting = vec3(1.0, 1.0, 1.0);
      } else {
        vec3 transformedNormal = uNMatrix * aVertexNormal;
        float directionalLightWeighting = max(dot(transformedNormal, uLightingDirection), 0.0);
        vLightWeighting = uAmbientColor + uDirectionalColor * directionalLightWeighting;
      }
    }
    """;

    // fragment shader source code.
    String fsSource = """
    precision mediump float;
    
    varying vec2 vTextureCoord;
    varying vec3 vLightWeighting;
    
    uniform sampler2D uSampler;
    
    void main(void) {
       vec4 textureColor = texture2D(uSampler, vec2(vTextureCoord.s, vTextureCoord.t));
       gl_FragColor = vec4(textureColor.rgb * vLightWeighting, textureColor.a);
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

    _aVertexNormal = gl.getAttribLocation(_shaderProgram, "aVertexNormal");
    gl.enableVertexAttribArray(_aVertexNormal);

    _uPMatrix = gl.getUniformLocation(_shaderProgram, "uPMatrix");
    _uMVMatrix = gl.getUniformLocation(_shaderProgram, "uMVMatrix");
    _uNMatrix = gl.getUniformLocation(_shaderProgram, "uNMatrix");
    _uSampler = gl.getUniformLocation(_shaderProgram, "uSampler");
    _uUseLighting = gl.getUniformLocation(_shaderProgram, "uUseLighting");
    _uAmbientColor = gl.getUniformLocation(_shaderProgram, "uAmbientColor");
    _uLightingDirection = gl.getUniformLocation(_shaderProgram, "uLightingDirection");
    _uDirectionalColor = gl.getUniformLocation(_shaderProgram, "uDirectionalColor");
  }

  void _initBuffers() {
    // create cube
    _cubeVertexPositionBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexPositionBuffer);
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList([
        // Front face
        -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0,
        // Back face
        -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0,
        // Top face
        -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0,
        // Bottom face
        -1.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0,
        // Right face
        1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0,
        // Left face
        -1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0,
      ]),
      webgl.WebGL.STATIC_DRAW,
    );

    _cubeVertexTextureCoordBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexTextureCoordBuffer);
    final textureCoords = <double>[
      // Front face
      0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0,
      // Back face
      1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0,
      // Top face
      0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0,
      // Bottom face
      1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0,
      // Right face
      1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0,
      // Left face
      0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0,
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

    _cubeVertexNormalBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexNormalBuffer);
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList([
        // Front face
        0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
        // Back face
        0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0,
        // Top face
        0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0,
        // Bottom face
        0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0,
        // Right face
        1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0,
        // Left face
        -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0,
      ]),
      webgl.WebGL.STATIC_DRAW,
    );
  }

  Future<void> _initTexture() async {
    final textureLoaded = Completer<void>();

    _texture = gl.createTexture();
    final image = Element.tag('img') as ImageElement;
    image.onLoad.listen((e) {
      _handleLoadedTexture(_texture, image);
      textureLoaded.complete();
    });
    image.src = "images/crate.gif";
    return textureLoaded.future;
  }

  void _handleLoadedTexture(webgl.Texture texture, ImageElement img) {
    gl.pixelStorei(webgl.WebGL.UNPACK_FLIP_Y_WEBGL, 1);

    gl.bindTexture(webgl.WebGL.TEXTURE_2D, texture);
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
    //final normalMatrix = _mvMatrix.toInverseMat3();
    final normalMatrix = _mvMatrix.getRotation();
    normalMatrix.transpose();
    gl.uniformMatrix3fv(_uNMatrix, false, normalMatrix.storage);
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

    // normals
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexNormalBuffer);
    gl.vertexAttribPointer(_aVertexNormal, 3, webgl.WebGL.FLOAT, false, 0, 0);

    gl.activeTexture(webgl.WebGL.TEXTURE0);
    gl.bindTexture(webgl.WebGL.TEXTURE_2D, _texture);
    gl.uniform1i(_uSampler, 0);

    // draw lighting?
    final drawLighting = _elmLighting.checked ?? false;
    gl.uniform1i(_uUseLighting, drawLighting ? 1 : 0);
    if (drawLighting) {
      final ar = _elmAmbientR.valueAsNumber ?? 0;
      final ag = _elmAmbientG.valueAsNumber ?? 0;
      final ab = _elmAmbientB.valueAsNumber ?? 0;
      gl.uniform3f(_uAmbientColor, ar / 100, ag / 100, ab / 100);

      final x = _elmLightDirectionX.valueAsNumber ?? 0;
      final y = _elmLightDirectionY.valueAsNumber ?? 0;
      final z = _elmLightDirectionZ.valueAsNumber ?? 0;
      final lightingDirection = Vector3(x / 100, y / 100, z / 100);
      final adjustedLD = lightingDirection.normalized();
      gl.uniform3fv(_uLightingDirection, adjustedLD.storage);

      final dr = _elmDirectionalR.valueAsNumber ?? 0;
      final dg = _elmDirectionalG.valueAsNumber ?? 0;
      final db = _elmDirectionalB.valueAsNumber ?? 0;
      gl.uniform3f(_uDirectionalColor, dr / 100, dg / 100, db / 100);
    }

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
      _cubeVertexNormalBuffer,
    ]);
    freePrograms([_shaderProgram]);
    freeTextures([_texture]);
    freeVertexAttributes([
      _aVertexPosition,
      _aTextureCoord,
      _aVertexNormal,
    ]);
    super.shutdown();
  }
}
