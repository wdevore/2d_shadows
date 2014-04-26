part of shadows;

/**
 * A minified affine transform.
 *  column major (form used by this class)
 *     x'   |a c tx| |x|
 *     y' = |b d ty| |y|
 *     1    |0 0  1| |1|
 *  or
 *  Row major
 *                           |a  b   0|
 *     |x' y' 1| = |x y 1| x |c  d   0|
 *                           |tx ty  1|
 *  
 */
class AffineTransform {
  double a, b, c, d;
  double tx, ty;
  
  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  AffineTransform(this.a, this.b, this.c, this.d, this.tx, this.ty);

  AffineTransform.Identity() {
    a = d = 1.0;
    b = c = tx = ty = 0.0;
  }
  
  // ----------------------------------------------------------
  // Operators
  // ----------------------------------------------------------
  bool operator ==(AffineTransform t) {
    return (a == t.a && b == t.b && c == t.c && d == t.d && tx == t.tx && ty == t.ty);
  }

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  void toIdentity() {
    a = d = 1.0;
    b = c = tx = ty = 0.0;
  }
  
  Point ApplyToPoint(Point point) {
    Point p = new Point((a * point.x) + (c * point.y) + tx, (b * point.x) + (d * point.y) + ty);
    return p;
  }

  void set(double a, double b, double c, double d, double tx, double ty) {
    this.a = a;
    this.b = b;
    this.c = c;
    this.d = d;
    this.tx = tx;
    this.ty = ty;
  }
  
  void setWithAT(AffineTransform t) {
    this.a = t.a;
    this.b = t.b;
    this.c = t.c;
    this.d = t.d;
    this.tx = t.tx;
    this.ty = t.ty;
  }
  
  /// Concatenate translation
  void translate(double x, double y)
  {
    tx += (a * x) + (c * y);
    ty += (b * x) + (d * y);
  }

  /// Concatenate scale
  void scale(double sx, double sy) {
    a *= sx;
    b *= sx;
    c *= sy;
    d *= sy;
  }
  
  /**
   * Concatenate rotation
   * A rotate affine transform. Y axis downwards.
   *     |cos  sin|   CW
   *     |-sin cos|
   *     
   * A rotate affine transform. Y axis upwards.
   *     |cos  -sin|   CW
   *     |sin   cos|
   *     
   *     |a  c|    |cos  -sin|
   *     |b  d|  x |sin   cos|
   *     
   * x' = x*cos - y*sin
   * y' = x*sin + y*cos
   */
  void rotate(double angle) {
    double sin = math.sin(angle);
    double cos = math.cos(angle);
    double _a = a;
    double _b = b;
    double _c = c;
    double _d = d;
    
    /*
     * |a1 c1|   |a2 c2|   |a1a2 + a1b2, a1c2 + c1d2|
     * |b1 d1| x |b2 d2| = |b1a2 + d1b2, b1c2 + d1d2|
     * 
     * +Y upwards
     * Another way to view it is in perspective of the coordinate
     * system. The system is rotating CW which means the object
     * appears to rotate in the opposite direction.
     * |_a, _c|   |cos, -sin|   |_acos + _csin, _a(-sin) + _ccos|
     * |_b, _d| x |sin,  cos| = |_bcos + _dsin, _b(-sin) + _dcos|
     */
    a = _a * cos + _c * sin;
    b = _b * cos + _d * sin;
    c = _c * cos - _a * sin;
    d = _d * cos - _b * sin;
    
    /*
     * // +Y downwards
     * |_a, _c|   |cos,  sin|   |_acos + _c(-sin), _a(sin) + _ccos|
     * |_b, _d| x |-sin, cos| = |_bcos + _d(-sin), _b(sin) + _dcos|
     */
//    a = _a * cos - _c * sin;
//    b = _b * cos - _d * sin;
//    c = _c * cos + _a * sin;
//    d = _d * cos + _b * sin;
  }

  /**
   * A minified affine transform.
   *     |a c tx|
   *     |b d ty|
   *     |0 0  1|
   *     
   *     |- y -|
   *     |x - -|
   *     |0 0 1|
   */
  /// Concatenate skew/shear
  /// [x] and [y] are in radians
  void skew(double x, double y) {
    c += math.tan(y);
    b += math.tan(x);
  }
  
  void concatenate(AffineTransform t) {
    double _a = a;
    double _b = b;
    double _c = c;
    double _d = d;
    double _tx = tx;
    double _ty = ty;
    
    a = _a * t.a + _b * t.c;
    b = _a * t.b + _b * t.d;
    c = _c * t.a + _d * t.c;
    d = _c * t.b + _d * t.d;
    tx = (_tx * t.a) + (_ty * t.c) + t.tx;
    ty = (_tx * t.b) + (_ty * t.d) + t.ty;
  }
  
  void invert() {
    double determinant = 1.0 / (a * d - b * c);
    double _a = a;
    double _b = b;
    double _c = c;
    double _d = d;
    double _tx = tx;
    double _ty = ty;

    a =  determinant * _d;
    b = -determinant * _b;
    c = -determinant * _c;
    d =  determinant * _a;
    tx = determinant * (_c * _ty - _d * _tx);
    ty = determinant * (_b * _tx - _a * _ty);
  }
  
  /**
   * Converts either from or to pre or post multiplication.
   *     a c
   *     b d
   * to
   *     a b
   *     c d
   */
  void transpose() {
    double _c = c;
   
    c = b;
    b = _c;
    // tx and ty are implied for partial 2x3 matrices
  }
  
  String toString() {
    StringBuffer s = new StringBuffer();
    s.writeln("|${a.toStringAsFixed(2)}, ${b.toStringAsFixed(2)}, ${tx.toStringAsFixed(2)}|");
    s.writeln("|${c.toStringAsFixed(2)}, ${d.toStringAsFixed(2)}, ${ty.toStringAsFixed(2)}|");
    return s.toString();
  }
}

/// Returns a pooled object.
Point PointApplyAffineTransform(Point point, AffineTransform t) {
  return new Point(
      (t.a * point.x) + (t.c * point.y) + t.tx,
      (t.b * point.x) + (t.d * point.y) + t.ty);
}

AffineTransform AffineTransformTranslate(AffineTransform t, double tx, double ty) {
  return new AffineTransform(
      t.a, 
      t.b, 
      t.c, 
      t.d, 
      t.tx + t.a * tx + t.c * ty, 
      t.ty + t.b * tx + t.d * ty);
}

AffineTransform AffineTransformScale(AffineTransform t, double sx, double sy) {
  return new AffineTransform(
      t.a * sx, 
      t.b * sx, 
      t.c * sy, 
      t.d * sy, 
      t.tx, 
      t.ty);
}

/**
 * Concatenate rotation
 * A rotate affine transform. Y axis downwards.
 *     |cos  sin|   CW
 *     |-sin cos|
 *     
 * A rotate affine transform. Y axis upwards.
 *     |cos  -sin|   CW
 *     |sin   cos|
 *     
 *     |a  c|    |cos  -sin|
 *     |b  d|  x |sin   cos|
 *     
 * x' = x*cos - y*sin
 * y' = x*sin + y*cos
 */
AffineTransform AffineTransformRotate(AffineTransform t, double anAngle) {
  double sin = math.sin(anAngle);
  double cos = math.cos(anAngle);

  // +Y upwards
//  AffineTransform at = new AffineTransform._poolable(
//      t.a * cos + t.c * sin,
//      t.b * cos + t.d * sin,
//      t.c * cos - t.a * sin,
//      t.d * cos - t.b * sin,
//      t.tx,
//      t.ty);

  // +Y downwards
  AffineTransform at = new AffineTransform(
      t.a * cos - t.c * sin,
      t.b * cos - t.d * sin,
      t.c * cos + t.a * sin,
      t.d * cos + t.b * sin,
      t.tx,
      t.ty);

  return at;
}

/**
 * Concatenate `t2' to `t1' and return the result: t' = t1 * t2
 * returns a [Poolable]ed [AffineTransform].     
 */
AffineTransform affineTransformMultiply(AffineTransform t1, AffineTransform t2) {
  AffineTransform t = new AffineTransform(
      t1.a * t2.a + t1.b * t2.c,
      t1.a * t2.b + t1.b * t2.d,
      t1.c * t2.a + t1.d * t2.c, 
      t1.c * t2.b + t1.d * t2.d,
      t1.tx * t2.a + t1.ty * t2.c + t2.tx,
      t1.tx * t2.b + t1.ty * t2.d + t2.ty);
  return t;
}

/**
 * Multiply [tA] x [tB] and place in [tB]
 */
void affineTransformMultiplyTo(AffineTransform tA, AffineTransform tB) {
  double a = tA.a * tB.a + tA.b * tB.c;
  double b = tA.a * tB.b + tA.b * tB.d;
  double c = tA.c * tB.a + tA.d * tB.c; 
  double d = tA.c * tB.b + tA.d * tB.d;
  double tx = tA.tx * tB.a + tA.ty * tB.c + tB.tx;
  double ty = tA.tx * tB.b + tA.ty * tB.d + tB.ty;
  tB.a = a;
  tB.b = b;
  tB.c = c;
  tB.d = d;
  tB.tx = tx;
  tB.ty = ty;
}

/* Return true if `t1' and `t2' are equal, false otherwise. */
bool AffineTransformEqualToTransform(AffineTransform t1, AffineTransform t2) {
  return (t1.a == t2.a && t1.b == t2.b && t1.c == t2.c && t1.d == t2.d && t1.tx == t2.tx && t1.ty == t2.ty);
}

AffineTransform AffineTransformInvert(AffineTransform t) {
  double determinant = 1.0 / (t.a * t.d - t.b * t.c);

  AffineTransform at = new AffineTransform(
      determinant * t.d,
     -determinant * t.b,
     -determinant * t.c,
      determinant * t.a,
      determinant * (t.c * t.ty - t.d * t.tx),
      determinant * (t.b * t.tx - t.a * t.ty) );
  
  return at;
}

void AffineTransformInvertTo(AffineTransform t, AffineTransform to) {
  double determinant = 1.0 / (t.a * t.d - t.b * t.c);

   to.a = determinant * t.d;
   to.b = -determinant * t.b;
   to.c = -determinant * t.c;
   to.d = determinant * t.a;
   to.tx = determinant * (t.c * t.ty - t.d * t.tx);
   to.ty = determinant * (t.b * t.tx - t.a * t.ty);
}