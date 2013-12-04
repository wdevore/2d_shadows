library shadows;

import 'dart:html';
import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

part 'geometry/edge.dart';
part 'geometry/utilities.dart';
part 'geometry/polygon.dart';
part 'geometry/vertex.dart';

part 'shadowvertex.dart';
part 'light.dart';
part 'lightsweep.dart';

void main() {
  CanvasElement canvas = querySelector("#area");
  ShadowSweep app = new ShadowSweep(canvas);
  scheduleMicrotask(app.initialize);
}

Element notes = querySelector("#fps");
num fpsAverage;
Element mousePosX = querySelector("#mousePosX");
Element mousePosY = querySelector("#mousePosY");
Element debug1 = querySelector("#debug1");
Element debug2 = querySelector("#debug2");
Element debug3 = querySelector("#debug3");
Element testButton = querySelector("#testButton");
InputElement txtTestCase = querySelector("#txtTestCase");

/// Display the animation's FPS in a div.
void showFps(num fps) {
  if (fpsAverage == null) fpsAverage = fps;
  fpsAverage = fps * 0.05 + fpsAverage * 0.95;
  notes.text = "${fpsAverage.round()} fps";
}

void showMousePos(Vector2 p) {
  mousePosX.text = "${p.x.toStringAsPrecision(8)}";
  mousePosY.text = "${p.y.toStringAsPrecision(8)}";
}

void showMousePosByComponent(double x, double y) {
  mousePosX.text = "${x.toStringAsPrecision(8)}";
  mousePosY.text = "${y.toStringAsPrecision(8)}";
}

void showDebug1(String msg) {
  debug1.text = msg;
}

void showDebug2(String msg) {
  debug2.text = msg;
}

void showDebug3(String msg) {
  debug3.text = msg;
}

class ShadowSweep {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  CanvasElement canvas;

  num width;
  num height;

  num renderTime;

  List<Polygon> casters = new List<Polygon>();

  double previousPointX = -1.0;
  double previousPointY = -1.0;
  bool mouseDown = false;
  bool mouseOnLight = false;

  math.Random random = new math.Random(100);

  LightSweep light = new LightSweep(100.0, 32);

  bool tmode = false;

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  ShadowSweep(this.canvas);

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  void initialize() {
    /*
     * Canvas space is oriented as:
     *
     * 0,0
     *    ---------------> +X
     *    |
     *    |
     *    |
     *    |
     *    v +Y
     */

    Rectangle rect = canvas.parent.client;
    print("rect ${rect.width} x ${rect.height}");

    // Used for clearing rectangle.
    width = rect.width;
    height = rect.height;
    canvas.width = width;

    runTest(15);

//    light.position = new Vector2(630.69992, 100.40002);
//    light.position = new Vector2(590.69992, 100.40002);
//    light.position = new Vector2(368.69992, 230.40002);
    light.position = new Vector2(334.69992, 313.40002);

    light.build(casters);

    // Bind listeners.
//    canvas.onClick.listen(
//        (event) => canvasClick(event)
//        );
    canvas.onMouseDown.listen(
        (event) => canvasMouseDown(event)
        );
    canvas.onMouseMove.listen(
        (event) => canvasMouseMove(event)
        );
    canvas.onMouseUp.listen(
        (event) => canvasMouseUp(event)
        );
    window.onKeyUp.listen(
        (event) => canvasKeyUp(event)
        );

    testButton.onClick.listen(
        (event) => testButtonClick(event)
        );
    requestRedraw();
  }

  void draw(num _) {
    num time = new DateTime.now().millisecondsSinceEpoch;
    if (renderTime != null) showFps(1000 / (time - renderTime));
    renderTime = time;

    CanvasRenderingContext2D context = canvas.context2D;
    drawBackground(context);

    for(Polygon poly in casters) {
      poly.draw(context);
    }

    light.build(casters);
    light.draw(context);

    requestRedraw();
  }

  void testButtonClick(MouseEvent event) {
    int test = int.parse(txtTestCase.value);
    runTest(test);
  }

  void canvasKeyUp(KeyboardEvent event) {
    KeyEvent ke = new KeyEvent.wrap(event);

    //print("key code: ${ke.keyCode}");
    switch (ke.keyCode) {
      case 84: // T
        print("Choose test: 0-9");
        casters.clear();
        tmode = !tmode;
        break;
    }

    if (!tmode)
      return;

    light.keyboardEvent(ke);
  }

  void canvasMouseDown(MouseEvent event) {
    Point p = event.offset;
    if (light.isPointOnCenter(p)) {
      previousPointX = p.x.toDouble();
      previousPointY = p.y.toDouble();
      mouseOnLight = true;
    }
    mouseDown = true;
    showMousePos(light.position);
  }

  void canvasMouseUp(MouseEvent event) {
    mouseDown = false;
    mouseOnLight = false;
  }

  void canvasMouseMove(MouseEvent event) {
    Point p = event.offset;
    if (mouseDown && mouseOnLight) {
      double dx = p.x.toDouble() - previousPointX;
      double dy = p.y.toDouble() - previousPointY;
      light.moveBy(dx, dy);
    }
    previousPointX = p.x.toDouble();
    previousPointY = p.y.toDouble();
    showDebug1("${previousPointX}, ${previousPointY}");
    showMousePosByComponent(light.position.x, light.position.y);
  }

  void canvasClick(MouseEvent event) {
    Point p = event.offset;

    double x = p.x.toDouble();
    double y = p.y.toDouble();

    if (previousPointX >= 0.0) {
      //poly.addEdgeWithDoubles(previousPointX, previousPointY, x, y);
    }

    previousPointX = x;
    previousPointY = y;

    showMousePosByComponent(p.x.toDouble(), p.y.toDouble());
  }

  void drawBackground(CanvasRenderingContext2D context) {
    context.clearRect(0, 0, width, height);
  }

  void requestRedraw() {
    window.requestAnimationFrame(draw);
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // Test cases
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  void runTest(int test) {
    casters.clear();

    switch (test) {
      case 1:
        buildTest1();
        light.dirty = true;
        break;
      case 2:
        buildTest2();
        light.dirty = true;
        break;
      case 3:
        buildTest3();
        light.dirty = true;
        break;
      case 4:
        buildTest4();
        light.dirty = true;
        break;
      case 5:
        buildTest5();
        light.dirty = true;
        break;
      case 6:
        buildTest6();
        light.dirty = true;
        break;
      case 7:
        buildTest7();
        light.dirty = true;
        break;
      case 8:
        buildTest8();
        light.dirty = true;
        break;
      case 9:
        buildTest9();
        light.dirty = true;
        break;
      case 10:
        buildTest10();
        light.dirty = true;
        break;
      case 11:
        buildTest11();
        light.dirty = true;
        break;
      case 12:
        buildTestStrip_12();
        light.dirty = true;
        break;
      case 13:
        buildBoxStrip_13();
        light.dirty = true;
        break;
      case 14:
        buildBoxAndStrip_14();
        light.dirty = true;
        break;
      case 15:
        buildBoxAndStripAndLine_15();
        light.dirty = true;
        break;
      case 16:
        buildX_16();
        light.dirty = true;
        break;
      case 17:
        buildH_17();
        light.dirty = true;
        break;
    }
    
    print("test case: $test");
    for(Polygon p in casters) {
      print(p.toMedString());
    }
    print("----------------------");

  }
  
  void buildTest1() {
    Polygon poly;

    poly = new Polygon();
    poly.name = "horizon";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 190.0, 300.0, 190.0);
    casters.add(poly);

    poly = new Polygon();
    poly.name = "vert";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(330.0, 190.0, 330.0, 250.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest1b() {
    Polygon poly;

    poly = new Polygon();
    poly.name = "vert1";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(550.0, 190.0, 550.0, 250.0);
    casters.add(poly);

    poly = new Polygon();
    poly.name = "vert1";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(250.0, 270.0, 250.0, 150.0);
    casters.add(poly);
    
    poly.end();
  }

  void buildTest2() {
    Polygon poly;

    // +Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 185.0,
        300.0, 185.0);
    casters.add(poly);

    // -X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(325.0, 200.0,
        325.0, 300.0);
    casters.add(poly);

    // +X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(215.0, 300.0,
        215.0, 200.0);
    casters.add(poly);

    // -Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(300.0, 295.0,
        230.0, 295.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest3() {
    Polygon poly;

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 190.0,
        300.0, 190.0);
    casters.add(poly);
    print(poly.toMedString());

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(250.0, 200.0,
        320.0, 200.0);
    casters.add(poly);

    print(poly.toMedString());
    // +X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(210.0, 300.0,
        210.0, 200.0);
    casters.add(poly);

    // -X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(330.0, 200.0,
        330.0, 300.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest4() {
    Polygon poly;

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 190.0,
        300.0, 190.0);
    casters.add(poly);

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(250.0, 170.0,
        320.0, 170.0);
    casters.add(poly);

    // +X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(320.0, 190.0,
        390.0, 190.0);
    casters.add(poly);

    // -X
//    poly = new Polygon();
//    poly.begin();
//    poly.active = true;
//    poly.addEdgeWithPoints(330.0, 200.0,
//        330.0, 300.0);
//    casters.add(poly);

    poly.end();
  }

  void buildTest5() {
    Polygon poly;

//    poly = new Polygon();
//    poly.active = true;
//    poly.begin();
//    poly.addEdgeWithPoints(230.0, 190.0,
//        300.0, 190.0);
//    casters.add(poly);

//    poly = new Polygon();
//    poly.active = true;
//    poly.begin();
//    poly.addEdgeWithPoints(250.0, 170.0,
//        320.0, 170.0);
//    casters.add(poly);

    // +X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(320.0, 190.0,
        390.0, 190.0);
    casters.add(poly);

    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(330.0, 200.0,
        330.0, 300.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest6() {
    Polygon poly;

    // +Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 185.0,
        300.0, 185.0);
    casters.add(poly);

    // -X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(325.0, 200.0,
        325.0, 300.0);
    casters.add(poly);

    // +X
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(215.0, 300.0,
        215.0, 180.0);
    casters.add(poly);

    // -Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(300.0, 290.0,
        230.0, 290.0);
    casters.add(poly);

    // diag -,+
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(310.0, 140.0,
        370.0, 220.0);
    casters.add(poly);

    // diag +,-
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 370.0,
        150.0, 290.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest7() {
    Polygon poly;

    // +Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 185.0,
        300.0, 185.0);
    casters.add(poly);

    // shift down +y
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(270.0, 165.0,
        340.0, 165.0);
    casters.add(poly);

    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(310.0, 145.0,
        380.0, 145.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest8() {
    Polygon poly;

    // +Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 185.0,
        300.0, 185.0);
    casters.add(poly);

    // shift down +y
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(270.0, 165.0,
        340.0, 165.0);
    casters.add(poly);

    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(310.0, 145.0,
        380.0, 145.0);
    casters.add(poly);

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(340.0, 185.0,
        420.0, 185.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest9() {
    Polygon poly;

    // +Y
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 185.0,
        300.0, 185.0);
    casters.add(poly);

    // shift down +y
    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(301.0, 185.0,
        301.0, 285.0);
    casters.add(poly);

    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(299.0, 184.0, 302.0, 184.0);
    casters.add(poly);

    poly = new Polygon();
    poly.begin();
    poly.active = true;
    poly.startEdgeWithDoubles(302.0, 183.0, 302.0, 185.0);
    casters.add(poly);

    poly.end();
  }
  void buildTest10() {
    Polygon poly;

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 190.0, 300.0, 190.0);
    casters.add(poly);

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(250.0, 170.0, 350.0, 170.0);
    casters.add(poly);

    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(220.0, 150.0, 400.0, 150.0);
    casters.add(poly);

    poly.end();
  }

  void buildTest11() {
    Polygon poly;

    // diag -,+
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(370.0, 110.0, 450.0, 190.0);
    casters.add(poly);

    // diag +,-
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 370.0,
        150.0, 290.0);
    casters.add(poly);

    // diag +,+
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(130.0, 170.0, 230.0, 90.0);
    casters.add(poly);

    // diag -,-
    poly = new Polygon();
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(450.0, 300.0, 350.0, 360.0);
    casters.add(poly);

    poly.end();
  }

  void buildTestStrip_12() {
    Polygon poly;

    poly = new Polygon();
    poly.name = "TestStrip12";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(230.0, 300.0, 300.0, 300.0);
    poly.appendEdgeWithDouble(350.0, 450.0);
    poly.appendEdgeWithDouble(500.0, 300.0);
    casters.add(poly);

    poly.end();
  }

  void buildBoxStrip_13() {
    Polygon poly;

    poly = new Polygon();
    poly.name = "BoxStrip13";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(330.0, 100.0, 500.0, 100.0);
    poly.appendEdgeWithDouble(500.0, 250.0);
    poly.appendEdgeWithDouble(330.0, 250.0);
    poly.close();
    casters.add(poly);

    poly.end();
  }

  void buildBoxAndStrip_14() {
    buildTestStrip_12();
    buildBoxStrip_13();
  }

  void buildBoxAndStripAndLine_15() {
    buildTestStrip_12();
    buildBoxStrip_13();
    buildTest1b();
  }

  void buildX_16() {
    Polygon poly;

    poly = new Polygon();
    poly.name = "horz";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(300.0, 190.0, 500.0, 190.0);
    casters.add(poly);

    poly = new Polygon();
    poly.name = "vert";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(400.0, 100.0, 400.0, 390.0);
    casters.add(poly);

    poly.end();
  }
  
  void buildH_17() {
    Polygon poly;

    poly = new Polygon();
    poly.name = "horz";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(400.0, 190.0, 600.0, 190.0);
    casters.add(poly);

    poly = new Polygon();
    poly.name = "vert";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(400.0, 100.0, 400.0, 390.0);
    casters.add(poly);

    poly = new Polygon();
    poly.name = "vert";
    poly.active = true;
    poly.begin();
    poly.startEdgeWithDoubles(600.0, 100.0, 600.0, 390.0);
    casters.add(poly);

    poly.end();
  }
}
