part of shadows;

class Polygon {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  static int _genId = 0;  // unique id.

  List<Vertex> vertices = new List<Vertex>();
  List<Edge> edgeList = new List<Edge>();

  bool _closed = false;

  /// A unique id to distinguish between other Polygons.
  int id = -1;
  String name = "";  

  int _vertexIndex = -1;

  String edgeColor = "#724a16";
  String normalColor = "white";
  
  bool showNormals = true;

  bool active = false;

  double _prevX;
  double _prevY;
  Vertex _prevVertex;

  // ----------------------------------------------------------
  // Factories
  // ----------------------------------------------------------
  factory Polygon() {
    Polygon p = new Polygon.withId(_genId++);
    return p;
  }

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  Polygon.withId(this.id);

  // ----------------------------------------------------------
  // Properties
  // ----------------------------------------------------------

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  Vertex getVertex(int index) => vertices[index];

  void begin() {
    _vertexIndex = 0;
    vertices.clear();
    edgeList.clear();
  }

  void end() {
  }

  void appendEdge() {
    Edge e = new Edge(_vertexIndex, _vertexIndex + 1);
    e.polygonId = id;
    e.calc(vertices[_vertexIndex].vertex, vertices[_vertexIndex + 1].vertex);
    _vertexIndex += 1;
    edgeList.add(e);
  }

  void close() {
    Edge e = new Edge(_vertexIndex, 0);
    e.polygonId = id;
    Vertex v0 = vertices[0];
    e.calc(vertices[_vertexIndex].vertex, v0.vertex);

    v0.prevEdgeId = e.id;
    vertices[_vertexIndex].nextEdgeId = vertices.length - 1;

    v0.shared = Vertex.SHARED;
    vertices[_vertexIndex].shared = Vertex.SHARED;

    edgeList.add(e);
    _closed = true;
  }

  void startEdgeWithDoubles(double p0X, double p0Y, double p1X, double p1Y) {
    Edge e = new Edge.reset(_vertexIndex, _vertexIndex + 1);
    e.polygonId = id;
    e.calcWithDoubles(p0X, p0Y, p1X, p1Y);
    edgeList.add(e);

    Vertex v = new Vertex(p0X, p0Y);
    v.prevEdgeId = null;
    v.nextEdgeId = e.id;
    vertices.add(v);

    v = new Vertex(p1X, p1Y);
    v.prevEdgeId = e.id;
    v.nextEdgeId = e.id;    // also used for NON-SHARED
    vertices.add(v);

    _prevX = p1X;
    _prevY = p1Y;
    _prevVertex = v;

    _vertexIndex += 1;
  }

  void appendEdgeWithDouble(double pX, double pY) {
    Edge e = new Edge(_vertexIndex, _vertexIndex + 1);
    e.polygonId = id;
    e.calcWithDoubles(_prevX, _prevY, pX, pY);
    edgeList.add(e);

    _prevVertex.nextEdgeId = e.id;

    Vertex v = new Vertex(pX, pY);
    v.prevEdgeId = e.id;
    v.nextEdgeId = null;

    if (vertices.length > 1) {
      vertices[vertices.length - 1].shared = Vertex.SHARED;
    }

    vertices.add(v);

    _prevX = pX;
    _prevY = pY;
    _prevVertex = v;

    _vertexIndex++;
  }

  void draw(CanvasRenderingContext2D context) {
    // First draw edges
    if (vertices.length > 0) {
      context..lineWidth = 1
             ..strokeStyle = edgeColor;

      Vertex p = vertices[0];
      context..beginPath()
             ..moveTo(p.vertex.x, p.vertex.y);

      Iterable<Vertex> subList = vertices.getRange(1, vertices.length);
      for(Vertex p in subList) {
        context.lineTo(p.vertex.x, p.vertex.y);
      }

      if (_closed)
        context.closePath();

      context.stroke();
    }
    
    for(Edge edge in edgeList) {
      if (edge.culled) {
        context.strokeStyle = edge.culledColor;
        Vertex v0 = vertices[edge.p0];
        Vertex v1 = vertices[edge.p1];
        context..beginPath()
               ..moveTo(v0.vertex.x, v0.vertex.y)
               ..lineTo(v1.vertex.x, v1.vertex.y)
               ..stroke();
      }
    }

    // Now draw normals.
    if (showNormals) {
      context.lineWidth = 2;

      for(Edge e in edgeList) {
        context.strokeStyle = e.normalColor;

        Vector2 normal = e.normal;
        Vector2 midPoint = e.mid;

        context..beginPath()
          ..moveTo(midPoint.x, midPoint.y)
          ..lineTo(midPoint.x + (normal.x * 15.0), midPoint.y + (normal.y * 15.0))
          ..stroke();
      }
    }
  }

  /// Returns a printable string
  String toString() {
    StringBuffer s = new StringBuffer();
    s.writeln("polygon '$name' id: ${id}");
    int i = 0;
    for(Vertex vt in vertices) {
      s.writeln("  ${i} >> ${vt}");
      i++;
    }
    return s.toString();
  }

  String toMedString() {
    StringBuffer s = new StringBuffer();
    s.write(this);
    s.writeln("  Edges:");
    for(Edge e in edgeList) {
      s.writeln("    " + e.toString());
    }
    return s.toString();
  }

}