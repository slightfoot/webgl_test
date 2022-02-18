import 'dart:collection';
import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl' as webgl;

import 'package:vector_math/vector_math.dart';
import 'package:webgltest/base.dart';

class TestWebGL extends BaseWebGL {
  late webgl.Shader _vs;
  late webgl.Shader _fs;
  late webgl.Program _shaderProgram;

  late webgl.Buffer _pyramidVertexPositionBuffer;
  late webgl.Buffer _pyramidVertexColorBuffer;
  late webgl.Buffer _cubeVertexPositionBuffer;
  late webgl.Buffer _cubeVertexColorBuffer;
  late webgl.Buffer _cubeVertexIndexBuffer;

  final _pMatrix = Matrix4.identity();
  final _mvMatrix = Matrix4.identity();
  final _mvMatrixStack = Queue<Matrix4>();

  late int _aVertexPosition;
  late int _aVertexColor;
  late webgl.UniformLocation _uPMatrix;
  late webgl.UniformLocation _uMVMatrix;

  double _rPyramid = 0.0;
  double _rCube = 0.0;

  TestWebGL(CanvasElement elm) {
    gl = elm.getContext('webgl') as webgl.RenderingContext;

    _initShaders();
    _initBuffers();

    gl.clearColor(1, 1, 1, 1.0);
    gl.enable(webgl.WebGL.DEPTH_TEST);
    resize(elm.width!, elm.height!);
  }

  void _initShaders() {
    // vertex shader source code. uPosition is our variable that we'll use to create animation
    String vsSource = """
    attribute vec3 aVertexPosition;
    attribute vec4 aVertexColor;
    
    uniform mat4 uMVMatrix;
    uniform mat4 uPMatrix;
  
    varying vec4 vColor;
    
    void main(void) {
        gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
        vColor = aVertexColor;
    }
    """;

    // fragment shader source code. uColor is our variable that we'll use to animate color
    String fsSource = """
    precision mediump float;
    
    varying vec4 vColor;
    
    void main(void) {
        gl_FragColor = vColor;
    }
    """;

    // vertex shader compilation
    _vs = gl.createShader(webgl.WebGL.VERTEX_SHADER);
    gl.shaderSource(_vs, vsSource);
    gl.compileShader(_vs);

    // fragment shader compilation
    _fs = gl.createShader(webgl.WebGL.FRAGMENT_SHADER);
    gl.shaderSource(_fs, fsSource);
    gl.compileShader(_fs);

    // attach shaders to a WebGL program
    _shaderProgram = gl.createProgram();
    gl.attachShader(_shaderProgram, _vs);
    gl.attachShader(_shaderProgram, _fs);
    gl.linkProgram(_shaderProgram);
    gl.useProgram(_shaderProgram);

    /**
     * Check if shaders were compiled properly. This is probably the most painful part
     * since there's no way to "debug" shader compilation
     */
    if (!(gl.getShaderParameter(_vs, webgl.WebGL.COMPILE_STATUS) as bool)) {
      print(gl.getShaderInfoLog(_vs));
    }

    if (!(gl.getShaderParameter(_fs, webgl.WebGL.COMPILE_STATUS) as bool)) {
      print(gl.getShaderInfoLog(_fs));
    }

    if (!(gl.getProgramParameter(_shaderProgram, webgl.WebGL.LINK_STATUS) as bool)) {
      print(gl.getProgramInfoLog(_shaderProgram));
    }

    _aVertexPosition = gl.getAttribLocation(_shaderProgram, "aVertexPosition");
    gl.enableVertexAttribArray(_aVertexPosition);

    _aVertexColor = gl.getAttribLocation(_shaderProgram, "aVertexColor");
    gl.enableVertexAttribArray(_aVertexColor);

    _uPMatrix = gl.getUniformLocation(_shaderProgram, "uPMatrix");
    _uMVMatrix = gl.getUniformLocation(_shaderProgram, "uMVMatrix");
  }

  void _initBuffers() {
    // create triangle
    _pyramidVertexPositionBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _pyramidVertexPositionBuffer);
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList([
        // Front face
        0.0, 1.0, 0.0,
        -1.0, -1.0, 1.0,
        1.0, -1.0, 1.0,
        // Right face
        0.0, 1.0, 0.0,
        1.0, -1.0, 1.0,
        1.0, -1.0, -1.0,
        // Back face
        0.0, 1.0, 0.0,
        1.0, -1.0, -1.0,
        -1.0, -1.0, -1.0,
        // Left face
        0.0, 1.0, 0.0,
        -1.0, -1.0, -1.0,
        -1.0, -1.0, 1.0,
      ]),
      webgl.WebGL.STATIC_DRAW,
    );

    _pyramidVertexColorBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _pyramidVertexColorBuffer);
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList([
        // Front face
        1.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        // Right face
        1.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        // Back face
        1.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        // Left face
        1.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
      ]),
      webgl.WebGL.STATIC_DRAW,
    );

    // create square
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

    final colors2 = <List<double>>[
      [1.0, 0.0, 0.0, 1.0], // Front face
      [1.0, 1.0, 0.0, 1.0], // Back face
      [0.0, 1.0, 0.0, 1.0], // Top face
      [1.0, 0.5, 0.5, 1.0], // Bottom face
      [1.0, 0.0, 1.0, 1.0], // Right face
      [0.0, 0.0, 1.0, 1.0], // Left face
    ];
    // each cube face (6 faces for one cube) consists of 4 points of the
    // same color where each color has 4 components RGBA
    // therefore I need 4 * 4 * 6 long list of doubles
    final unpackedColors = List.generate(4 * 4 * colors2.length, (int index) {
      // index ~/ 16 returns 0-5, that's color index
      // index % 4 returns 0-3 that's color component for each color
      return colors2[index ~/ 16][index % 4];
    }, growable: false);

    _cubeVertexColorBuffer = gl.createBuffer();
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexColorBuffer);
    gl.bufferData(
      webgl.WebGL.ARRAY_BUFFER,
      Float32List.fromList(unpackedColors),
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

  void resize(int width, int height) {
    print('resize: $width x $height');
    gl.viewport(0, 0, width, height);
    // field of view is 45°, width-to-height ratio, hide things closer than 0.1 or further than 100
    _pMatrix.setFrom(makePerspectiveMatrix(radians(45.0), width / height, 0.1, 100.0));
  }

  void _mvPushMatrix() {
    _mvMatrixStack.addFirst(_mvMatrix.clone());
  }

  void _mvPopMatrix() {
    if (_mvMatrixStack.isEmpty) {
      throw Exception('Invalid popMatrix!');
    }
    _mvMatrix.setFrom(_mvMatrixStack.removeFirst());
  }

  void _updateMatrixUniforms() {
    gl.uniformMatrix4fv(_uPMatrix, false, _pMatrix.storage);
    gl.uniformMatrix4fv(_uMVMatrix, false, _mvMatrix.storage);
  }

  @override
  void render([double time = 0]) {
    gl.clear(webgl.WebGL.COLOR_BUFFER_BIT | webgl.WebGL.DEPTH_BUFFER_BIT);

    _mvMatrix.setIdentity();
    _mvMatrix.translate(Vector3(-1.5, 0.0, -7.0));

    _mvPushMatrix();
    _mvMatrix.rotate(Vector3(0.0, 1.0, 0.0), radians(_rPyramid));

    // draw triangle
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _pyramidVertexPositionBuffer);
    gl.vertexAttribPointer(_aVertexPosition, 3, webgl.WebGL.FLOAT, false, 0, 0);
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _pyramidVertexColorBuffer);
    gl.vertexAttribPointer(_aVertexColor, 4, webgl.WebGL.FLOAT, false, 0, 0);
    _updateMatrixUniforms();
    gl.drawArrays(webgl.WebGL.TRIANGLES, 0, 12);

    _mvPopMatrix();

    _mvMatrix.translate(Vector3(3.0, 0.0, 0.0));

    _mvPushMatrix();
    _mvMatrix.rotate(Vector3(1.0, 1.0, 1.0), radians(_rCube));

    // draw square
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexPositionBuffer);
    gl.vertexAttribPointer(_aVertexPosition, 3, webgl.WebGL.FLOAT, false, 0, 0);
    gl.bindBuffer(webgl.WebGL.ARRAY_BUFFER, _cubeVertexColorBuffer);
    gl.vertexAttribPointer(_aVertexColor, 4, webgl.WebGL.FLOAT, false, 0, 0);
    _updateMatrixUniforms();
    gl.bindBuffer(webgl.WebGL.ELEMENT_ARRAY_BUFFER, _cubeVertexIndexBuffer);
    gl.drawElements(webgl.WebGL.TRIANGLES, 36, webgl.WebGL.UNSIGNED_SHORT, 0);

    _mvPopMatrix();

    // rotate
    _rPyramid += (90 * time) / 1000.0;
    _rCube += (75 * time) / 1000.0;
  }

  @override
  void shutdown() {
    freeBuffers([
      _pyramidVertexPositionBuffer,
      _pyramidVertexColorBuffer,
      _cubeVertexPositionBuffer,
      _cubeVertexColorBuffer,
      _cubeVertexIndexBuffer,
    ]);
    freePrograms([_shaderProgram]);
    freeVertexAttributes(2);
    super.shutdown();
  }
}
