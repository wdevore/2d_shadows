part of shadows;

int VertexComparator(Vertex a, Vertex b) {
  return a.radialPos.compareTo(b.radialPos);
}

class Vertex {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  Vector2 vertex;

  static const bool VISITED = true;
  static const bool NOTVISITED = false;
  /// Used for the culling phase. We only want to process a vertex once.
  /// VISITED = true
  /// NOTVISITED = false
  bool visited = NOTVISITED;

  static const bool SHARED = true;
  static const bool NOTSHARED = false;
  /// Used for the building phase. we only want to evaluate a vertex once.
  /// SHARED = true
  /// NOTSHARED = false
  bool shared = NOTSHARED;

  static const bool RIM = true;
  static const bool EDGE = false;
  /// What kind of vertex is it.
  /// RIM = true
  /// EDGE = false
  bool type = EDGE;

  // It is used during radial sorting of the culled vertices.
  double radialPos = 0.0;

  // Used for SHARED vertices.
  int prevEdgeId;
  int nextEdgeId;
  bool prevFacing;
  bool nextFacing;
  
  // used for NON-SHARED vertices
  int edgeId;
  
  // This is used for self-checking across multiple polygons. 
  int polygonId;
  
  // An Edge has an End and Start that is defined relative to a radial sweep
  // that rotates CCW such that the radial sweep will "touch" the EDGE_START
  // first and the EDGE_END last.
  // This is independent of p0 or p1. Either end point can be a Start or End.
  static const int EDGE_END = 0;
  static const int EDGE_START = 1;
  /// EDGE_END = 0
  /// EDGE_START = 1
  int endType;

  // ----------------------------------------------------------
  // Factories
  // ----------------------------------------------------------
  factory Vertex(double x, double y) {
    Vertex v = new Vertex.withPoints(x, y);
    return v;
  }

  factory Vertex.withVector(Vector2 vec) {
    Vertex v = new Vertex.withPoints(vec.x, vec.y);
    return v;
  }

  factory Vertex.withDoublesAndRadial(double x, double y, double radial) {
    Vertex v = new Vertex.withPoints(x, y);
    v.radialPos = radial;
    return v;
  }

  factory Vertex.withVectorAndRadial(Vector2 vec, double radial) {
    Vertex v = new Vertex.withDoublesAndRadial(vec.x, vec.y, radial);
    return v;
  }

  factory Vertex.withVertex(Vertex ver) {
    Vertex v = new Vertex.withPoints(ver.vertex.x, ver.vertex.y);
    v.radialPos = ver.radialPos;
    v.endType = ver.endType;
    v.prevEdgeId = ver.prevEdgeId;
    v.nextEdgeId = ver.nextEdgeId;
    v.prevFacing = ver.prevFacing;
    v.nextFacing = ver.nextFacing;
    v.shared = ver.shared;
    v.visited = ver.visited;
    return v;
  }

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  Vertex.withPoints(double x, double y) {
    vertex = new Vector2(x, y);
    radialPos = 0.0;
  }

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  void reset() {
    visited = Vertex.NOTVISITED;
  }

  /// Returns a printable string
  String toString() {
    StringBuffer s = new StringBuffer();
    s.write("vertex:[${vertex.x.toStringAsPrecision(4)}, ${vertex.y.toStringAsPrecision(4)}] ");
    s.write("radial:${radialPos.toStringAsPrecision(4)} ");
    s.write("edgeId:$edgeId, polyId: $polygonId ");
    s.write(prevEdgeId == null ? "pEdgeId:-, " : "pEdgeId:${prevEdgeId}, ");
    s.write(nextEdgeId == null ? "nEdgeId:-, " : "nEdgeId:${nextEdgeId}, ");
    s.write(type == Vertex.RIM ? "type:RIM " : "type:EDGE ");
    if (endType != null)
      s.write(endType == Vertex.EDGE_END ? "endType:END   " : "endType:START ");

    if (visited == Vertex.VISITED)
      s.write("visited ");
    if (shared == Vertex.SHARED)
      s.write("shared ");

    return s.toString();
  }

}