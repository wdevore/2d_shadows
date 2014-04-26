part of shadows;

double _S;
double _T;

const double EPSILON = 0.0000001192092896;

double angleBetween(Vector2 a, Vector2 b) {
  a.normalize();
  b.normalize();
  double angle = math.atan2(a.cross(b), a.dot(b));

  if (angle.abs() < 0.00001)
    return 0.0;

  return angle;
}

bool polygonContainsPoint(List<Vertex> vertices, Vector2 p) {
  int i = 0;
  int j;
  bool c = false;
  int nvert = vertices.length;
  for (j = nvert - 1; i < nvert; j = i++) {
    if ( ((vertices[i].vertex.y > p.y) != (vertices[j].vertex.y > p.y)) &&
     (p.x < (vertices[j].vertex.x-vertices[i].vertex.x) * (p.y - vertices[i].vertex.y) /
            (vertices[j].vertex.y-vertices[i].vertex.y) + vertices[i].vertex.x) ) {
      c = !c;
    }
  }
  return c;
}

bool segmentIntersect(Vector2 A, Vector2 B,
                      Vector2 C, Vector2 D,
                      Vector2 I)
{

  int intersect = lineIntersect(A, B, C, D);
  if( intersect == 0
      && (_S >= 0.0 && _S <= 1.0 && _T >= 0.0 && _T <= 1.0) ) {

    // Point of intersection
    I.x = A.x + _S * (B.x - A.x);
    I.y = A.y + _S * (B.y - A.y);

    return true;
  }

  return false;
}

int lineIntersect(Vector2 A, Vector2 B,
                   Vector2 C, Vector2 D)
{
    // FAIL: Line undefined
    if ( ((A.x == B.x) && (A.y == B.y)) || ((C.x == D.x) && (C.y == D.y)) )
    {
        return 3;
    }
    double BAx = B.x - A.x;
    double BAy = B.y - A.y;
    double DCx = D.x - C.x;
    double DCy = D.y - C.y;
    double ACx = A.x - C.x;
    double ACy = A.y - C.y;

    double denom = (DCy * BAx) - (DCx * BAy);

    _S = (DCx * ACy) - (DCy * ACx);
    _T = (BAx * ACy) - (BAy * ACx);

    if (denom.abs() < EPSILON) {
        if (_S == 0 || _T == 0) {
            // Lines incident
            return 1;
        }
        // Lines parallel and not incident
        return 2;
    }

    _S = _S / denom;
    _T = _T / denom;

    return 0;
}

double distanceBetweenByVector(Vector2 p0, Vector2 p1) {
  return distanceBetweenByDouble(p0.x, p0.y, p1.x, p1.y);
}

double distanceBetweenByDouble(double p0X, double p0Y, double p1X, double p1Y) {
  double dx = p0X - p1X;
  double dy = p0Y - p1Y;
  return math.sqrt(dx * dx + dy * dy);
}

/**
 * [x] and [y] is the point.
 * [x1, y1, x2, y2] is the line segment.
 */
double pointToLineDistance(double x, double y, double x1, double y1, double x2, double y2) {
  double A = x - x1;
  double B = y - y1;
  double C = x2 - x1;
  double D = y2 - y1;

  double dot = A * C + B * D;
  double len_sq = C * C + D * D;
  double param = dot / len_sq;

  double xx, yy;

  if (param < 0.0 || (x1 == x2 && y1 == y2)) {
      xx = x1;
      yy = y1;
  }
  else if (param > 1.0) {
      xx = x2;
      yy = y2;
  }
  else {
      xx = x1 + param * C;
      yy = y1 + param * D;
  }

  double dx = x - xx;
  double dy = y - yy;

  return math.sqrt(dx * dx + dy * dy);
}

//bool polygonContainsPoint2(List<Point<double>> vertices, Point<double> p) {
//  int i;
//  int length = vertices.length;
//  int j = length - 1 ;
//  bool oddNodes = false;
//
//  for (i = 0; i < length; i++) {
//    if ((vertices[i].y < p.y && vertices[j].y >= p.y)
//        || ((vertices[j].y < p.y && vertices[i].y >= p.y)
//            && (vertices[i].x <= p.x || vertices[j].x <= p.x))) {
//      oddNodes ^= (vertices[i].x + (p.y - vertices[i].y) /
//          (vertices[j].y - vertices[i].y) * (vertices[j].x - vertices[i].x) < p.x);
//    }
//
//    j = i;
//  }
//
//  return oddNodes;
//}


