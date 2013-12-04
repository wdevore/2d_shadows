part of shadows;

class Edge {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  static int _genId = 0;  // unique id.

  int p0;
  int p1;

  /// A unique id to distinguish between other edges from different polygons.
  int id;

  // Used for making self-checks.
  int polygonId;
  
  Vector2 normal = new Vector2.zero();
  // Just a visual component.
  Vector2 mid = new Vector2.zero();

  /// ----------------------------------------------------
  /// Culled vars
  static const bool INFRONT = true;
  // This light is behind the edge so the edge is facing away from the light.
  static const bool BEHIND = false;
  /// The light is either in-front of or behind the edge defined by the Normal.
  /// INFRONT = true
  /// BEHIND = false
  bool facing;

  // Culled end points for this edge.
  Vector2 cP0 = new Vector2.zero();
  Vector2 cP1 = new Vector2.zero();
  /// ----------------------------------------------------

  // Debug stuff
  String normalColor = "white";
  String defaultColor = "white";
  bool culled = false;
  String culledColor = "#00aa00";
  String notCulledColor = "00ff00";
  
  // ----------------------------------------------------------
  // Factories
  // ----------------------------------------------------------
  factory Edge(int p0, int p1) {
    Edge e = new Edge._withPoints(p0, p1);
    e.id = _genId++;
    return e;
  }

  factory Edge.reset(int p0, int p1) {
    Edge e = new Edge._withPoints(p0, p1);
    _genId = 0;
    e.id = _genId++;
    return e;
  }

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  Edge._withPoints(this.p0, this.p1);

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  void calc(Vector2 p0, Vector2 p1) {
    calcWithDoubles(p0.x, p0.y, p1.x, p1.y);
  }

  void calcWithDoubles(double p0X, double p0Y, double p1X, double p1Y) {
    normal.x = p1X - p0X;
    normal.y = p1Y - p0Y;
    normal.normalize();

    // Vector2.scaleOrthogonalInto produces a CCW normal
    // However, I want a CW normal which means x,y ==> -y,x.
    // Why? Because canvas's coordinate system has +Y going downward.
    double t = normal.x;
    normal.x = -normal.y;
    normal.y = t;

    // Now mid point
    mid.x = (p0X + p1X) * 0.5;
    mid.y = (p0Y + p1Y) * 0.5;
  }

  /// Returns a printable string
  String toString() {
    StringBuffer s = new StringBuffer();
    s.write("id:[$id], polyId: $polygonId ");
    s.write("Indexes{$p0, $p1} ");

    if (facing != null)
      s.write(facing ? "In-front" : "Behind ");

    return s.toString();
  }
  String toMedString(List<Vertex> vertices) => "edge id: ${id}, Indexs{${p0}, ${p1}}, vertex:(${vertices[p0]}, ${vertices[p1]})";
  String toLongString() => "edge id: ${id}, N:${normal}, M:${mid}, Indexs{${p0}, ${p1}}";

}