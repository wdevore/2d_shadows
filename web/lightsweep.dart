part of shadows;

/**
 * LightSweep uses a sweeping method to calculate the shadow
 * vertices.
 *
 * It starts at 0 degrees and moves CCW.
 * Because HTML canvas has the Y axis downwards a CCW movements
 * requires that a negative angle given to the cos,sin methods.
 *
 * The sweep happens in two phases:
 * 1:
 *    A: Cull out edges that aren't completely inside Rim
 *    B: Trim edges that intersect the Rim replacing original edge.
 * 2: Run sweep edge-list creating shadow vertices.
 *
 * As the angle sweeps we check to see if any vertices a < the
 * nextAngle.
 * 
 * Sorting:
 * When we cull edges we collect culled vertices. These vertices are then sorted.
 * However, when sorted the edges that reference those vertices will be "out of sync".
 * But we can't modify the caster edges. We want to leave the original edges unmodified.
 * 
 * Edges are used to check for occlusion of other vertices.
 * Vertices are for building the light Rim.
 */
class LightSweep {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  double _radius;
  int _segments;
  
  double _theta_inc;
  final double TPI = 2.0 * math.PI;

  Polygon rim = new Polygon();

  /// Typical "yellow"
  String _color;

  Vector2 position;

  double selectRadius;
  bool dirty = true;

  List<Edge> _culledEdgeList = new List<Edge>();

  List<Vertex> _culledVertices = new List<Vertex>();
  List<Vertex> _shadowVertices = new List<Vertex>();

  // Cache vars
  Vector2 _lightRay = new Vector2.zero();
  Vector2 _lightRayEndPoint = new Vector2.zero();
  Vector2 _xAxis = new Vector2(1.0, 0.0);
  Vector2 _vector = new Vector2.zero();
  Vector2 _normal = new Vector2.zero();
  Vector2 _intersect1 = new Vector2.zero();
  Vector2 _intersect2 = new Vector2.zero();
  Vector2 _intersection = new Vector2.zero();
  Vector2 _currentIntersection = new Vector2.zero();
  Vertex _vertex = new Vertex(0.0, 0.0);

  // Debug stuff
  bool showVertices = false;
  bool showLightRim = false;
  bool showShadowedEdgeSegs = false;
  
  // ----------------------------------------------------------
  // Factories
  // ----------------------------------------------------------
  factory LightSweep() {
    LightSweep l = new LightSweep._withRadiusSegments(100.0, 16);
    l.color = "#646500";
    l.selectRadius = l.radius / 10.0;
    l.rim.showNormals = false;
    l._theta_inc = 2.0 * math.PI / l.segments;
    return l;
  }
  
  factory LightSweep.withRadAndSegs(double radius, int segments) {
    LightSweep l = new LightSweep._withRadiusSegments(radius, segments);
    l.color = "#646500";
    l.selectRadius = radius / 10.0;
    l.rim.showNormals = false;
    l._theta_inc = 2.0 * math.PI / segments;
    return l;
  }

  // ----------------------------------------------------------
  // setter/getters
  // ----------------------------------------------------------
  int get segments => _segments;
  void set segments(int segs) {
    _segments = segs;
    _theta_inc = 2.0 * math.PI / segments;
    dirty = true;
  }

  double get radius => _radius;
  void set radius(double rad) {
    _radius = rad;
    dirty = true;
  }

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  LightSweep._withRadiusSegments(this._radius, this._segments);

  // ----------------------------------------------------------
  // Properties
  // ----------------------------------------------------------
  set color(value) {
    _color = value;
    rim.edgeColor = _color;
  }

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  void build(List<Polygon> casters) {
    if (dirty) {
      dirty = false;

      _buildRim();

      _cullAndTrim(casters);

      _shadowVertices.clear();
      _buildVertices();
    }
  }

  void _buildRim() {
    rim.begin();
    double theta = 2.0 * math.PI;

    // Note: Canvas +Y axis is oriented downwards.
    // So for CCW we decrement theta starting from 2PI.
    for(int i = 0; i < segments; i++) {
      double x = radius * math.cos(theta) + position.x;
      double y = radius * math.sin(theta) + position.y;
      rim.vertices.add(new Vertex(x, y));
      theta -= _theta_inc;
    }

    for(int i = 0; i < segments - 1; i++) {
      rim.appendEdge();
    }
    rim.close();
  }

  // This method culls out any edges that are completely outside of the light-polygon.
  // Any that are completely inside or intersect the light-polygon are added
  // to a list for processing during the build-shadow-vertice phase.
  void _cullAndTrim(List<Polygon> casters) {
    _culledEdgeList.clear();

    // Reset the vertices before disposing of them because some of them are
    // actual end-point vertices and not allocated intersections.
    // TODO switch to pools.
    for(Vertex v in _culledVertices)
      v.reset();
    _culledVertices.clear();

    for(Polygon caster in casters) {
      if (caster.active) {

        List<Edge> edgeList = caster.edgeList;

        // iterate through the edges
        for(Edge edge in edgeList) {
          edge.culled = false; // debug stuff

          edge.facing = _isEdgeFacingLight(edge);

          // Convert index to vertex
          Vertex p0 = caster.getVertex(edge.p0);
          Vertex p1 = caster.getVertex(edge.p1);

          // See if this edge intersects Rim.
          int intersectCount = _calcRimIntersects(p0.vertex, p1.vertex, _intersect1, _intersect2);

          switch (intersectCount) {
            case 0:
              bool containsP0 = polygonContainsPoint(rim.vertices, p0.vertex);
              bool containsP1 = polygonContainsPoint(rim.vertices, p1.vertex);
              // No intersects with Rim.
              // It isn't enough that there wasn't an intersect because the edge
              // could simply be completely inside the light-polygon.
              // If it is completely outside it doesn't get added to the list.
              if (containsP0 && containsP1) {
                // Edge is completely INSIDE of Rim.
                _setFacing(p0, p1, edgeList);
                
                if (edge.facing == Edge.INFRONT) {
                  _addCulledEdge(p1, p0, caster, edge);
                }
                else {
                  _addCulledEdge(p0, p1, caster, edge);
                }
              }
              else {
                edge.culled = true; // debug stuff
              }
              break;
            case 1:
              bool containsP0 = polygonContainsPoint(rim.vertices, p0.vertex);
              bool containsP1 = polygonContainsPoint(rim.vertices, p1.vertex);
              // Only 1 intersect with the Rim.
              // Which also means one of the end points is outside and the other inside.
              // We take intersection and form new Edge and add to edge list.

              // The end point on the "inside" is untouched. The end point on the "outside"
              // is "moved" to the intersection.
              Vertex v = new Vertex.withVector(_intersect1);

              _setFacing(p0, p1, edgeList);

              if (containsP0) {
                // contains p0. p1 was trimmed off and has now become "v". We need to capture
                // p1's data and clone it to "v".
                v.prevEdgeId = p1.prevEdgeId;
                v.nextEdgeId = p1.prevEdgeId;
                
                if (edge.facing == Edge.INFRONT) {
                  _addCulledEdge(v, p0, caster, edge);
                }
                else {
                  _addCulledEdge(p0, v, caster, edge);
                }
              }
              else {
                // contains P1. But we need to retain p0's edge info.
                v.prevEdgeId = p0.prevEdgeId;
                v.nextEdgeId = p0.nextEdgeId;
                
                if (edge.facing == Edge.INFRONT) {
                  _addCulledEdge(p1, v, caster, edge);
                }
                else {
                  _addCulledEdge(v, p1, caster, edge);
                }
              }
              break;
            case 2:
              // There was 2 intersects with the Rim.
              _setFacing(p0, p1, edgeList);

              // @DEPRECATED it doesn't matter the order for 2 intersects.
              // We need to determine which side each intersect is on relative to the edge.
              // The distance from the intersect to an end point is used to determine it.
              // The intersect that is closest to p0 becomes an "end" endType.
              // The intersect that is closest to p1 becomes an "start" endType.
              // Note: when d0 > d1 then the light is on the Normal's side, or that the edge
              // is facing the light.
//              double distance0 = distanceBetweenByVector(_intersect1, p0.vertex);
//              double distance1 = distanceBetweenByVector(_intersect2, p0.vertex);
//
              Vertex v1 = new Vertex.withVector(_intersect1);
              Vertex v2 = new Vertex.withVector(_intersect2);
//
//              v1.prevEdgeId = edge.id;
//              v1.nextEdgeId = edge.id;
//              v2.prevEdgeId = edge.id;
//              v2.nextEdgeId = edge.id;
              
//              if (distance0 < distance1) {
                // intersect1 is closer to p0.
                _addCulledEdge(v2, v1, caster, edge);
//              }
//              else {
//                // v1 is considered p1
//                _addCulledEdge(v1, v2, caster, edge);
//              }
              break;
          }

        } // end For edges
      }
    } // end For casters

  }

  void _buildVertices() {
    if (_culledVertices.length == 0) {
      _buildBasicRim();
      return;
    }

    for(Vertex vt in _culledVertices)
      vt.reset();

    double angle = 0.0;
    double nextAngle = _theta_inc;

    // Sort the culled and trimmed edge vertices.
    _culledVertices.sort(VertexComparator);

    Iterator<Vertex> itr = _culledVertices.iterator;
    bool moreVertices = itr.moveNext();
    // We need to know if we handled an edge vertex between rim sections.
    // Rim sections are defined by angle and nextAngle.
    // We may not have handled any edge vertices if they were occluded.
    // Note: just because they were culled doesn't mean they are visible.
    //       All of them could be occluded between rim sections.
    bool processedEdgeVertex = false;
    bool occluded;

    do {
      if (moreVertices) {
        Vertex culledVertex = itr.current;

        // Process edge vertices until an edge's radial exceeds the current nextAngle.
        if (culledVertex.radialPos < nextAngle) {
          // Process a Rim vertex first before group of edge vertices.
          _handleRimVertex(angle);
          do {
            if (culledVertex.radialPos > nextAngle) {
              break;
            }

            if (culledVertex.shared == Vertex.SHARED)
              occluded = _handleSharedVertex(culledVertex);
            else
              occluded = _handleEdgeVertex(culledVertex);

            // If the vertex wasn't occluded then it was processed.
            // We need to know this because all the culled vertices for this
            // "group" may have been occluded. But if just 1 vertex was
            // processed then we don' want to add a trailing Rim vertex
            // Because it will be picked on the next loop.
            if (!occluded)
              processedEdgeVertex = true; // track that a vertex was added

            moreVertices = itr.moveNext();
            culledVertex = itr.current;
          } while (moreVertices);
        }
      }

      // If we didn't add an edge vertex then we simply keep adding Rim vertices.
      if (!processedEdgeVertex) {
        _handleRimVertex(angle);
      }

      // Reset processing flag for next potential group of culled edge vetices.
      processedEdgeVertex = false;

      // Move to the next section.
      // angle and nextAngle create a range to check for edge vertices.
      angle += _theta_inc;
      nextAngle = angle + _theta_inc;
    } while (angle < TPI);
  }

  void _setFacing(Vertex p0, Vertex p1, List<Edge> edgeList) {
    if (p0.shared == Vertex.SHARED && p0.visited == Vertex.NOTVISITED) {
      Edge prevEdge = edgeList[p0.prevEdgeId];
      Edge nextEdge = edgeList[p0.nextEdgeId];
      p0.prevFacing = _isEdgeFacingLight(prevEdge);
      p0.nextFacing = _isEdgeFacingLight(nextEdge);
    }

    if (p1.shared == Vertex.SHARED && p1.visited == Vertex.NOTVISITED) {
      Edge prevEdge = edgeList[p1.prevEdgeId];
      Edge nextEdge = edgeList[p1.nextEdgeId];
      p1.prevFacing = _isEdgeFacingLight(prevEdge);
      p1.nextFacing = _isEdgeFacingLight(nextEdge);
    }
  }

  bool _handleRimVertex(double angle) {
    // A Rim vertex is either in shadow or not.
    // If it is not in shadow then it is not occluded.
    _vertex.vertex.setValues(radius * math.cos(-angle) + position.x, radius * math.sin(-angle) + position.y);
    _vertex.radialPos = angle;
    _vertex.type = Vertex.RIM;

    bool occluded = _evaluateVertex(_vertex, _currentIntersection);

    if (!occluded) {
      Vertex v = new Vertex.withVertex(_vertex);
      _shadowVertices.add(v);
    }

    return occluded;
  }

  // For shared vertices we skip both edges but process the vertex
  // once against all the other vertices.
  bool _handleSharedVertex(Vertex v) {
    bool occluded = false;

    // We need to know how to handle it relative to the
    // Edges the vertex is associated with.
    // If the light is on the same side for both adjacent edges then the shared-vertex
    // doesn't shadow either against adjacent edge. We simply add the vertex
    // to the shadow list.

    if (v.prevFacing != v.nextFacing) {
      // The light is on different sides of each shared edge.
      // This means that one of the edges is potentially casting a shadow or
      // even occluded. So it is handled just like any other edge vertex.
      occluded = _handleEdgeVertex(v);
    }
    else {
      // Light is on the same side of both edges.
      // In this case we perform a standard vertex evaluate to see if it is occluded.
      // But there won't be a project Rim vertex because both edges combine to
      // block each other thus preventing light from projecting onto the Rim.
      // So there is only one vertex to add and that is the shared vertex.
      v.type = Vertex.EDGE;

      occluded = _evaluateVertex(v, _currentIntersection);

      if (!occluded) {
        Vertex nv = new Vertex.withVertex(v);
        _shadowVertices.add(nv);
      }
    }

    v.visited = Vertex.VISITED;

    return occluded;
  }

  bool _handleEdgeVertex(Vertex v) {
    v.type = Vertex.EDGE;
    bool occluded = _evaluateVertex(v, _currentIntersection);

    if (!occluded) {
      Vertex intersectionVt = new Vertex.withVectorAndRadial(_currentIntersection, v.radialPos);
      intersectionVt.endType = v.endType;

      // Depending on which side of the edge the light is on the "add" order
      // changes. Because this algorithm sweeps CCW start edges always
      // add the intersect first then the given vertex.
      if (v.endType == Vertex.EDGE_START) {
        _shadowVertices.add(intersectionVt);
        Vertex nv = new Vertex.withVertex(v);
        _shadowVertices.add(nv);
      }
      else {
        Vertex nv = new Vertex.withVertex(v);
        _shadowVertices.add(nv);
        _shadowVertices.add(intersectionVt);
      }
    }

    return occluded;
  }

  /**
   * This method only checks the culled edges. It does check for intersections
   * with the Rim because that happened during the cull phase.
   * So if this method only cares about intersections that are closer
   * to the light that the [vertex]'s distance to the light.
   * This is the core method to handling vertices. It takes a [vertex]
   * and scans all the edges (except the edge associated with the [vertex]) and
   * checks for an intersection. It stops when it has run out of edges or it
   * detects that the [vertex] is occluded by another edge.
   * In addition it tracks distance between each intersect and keeps the smallest one.
   * However, if the distance is smaller than the distance from [vertex]-to-light
   * then that means we found an intersection closer to the light meaning there
   * is an edge "blocking" the current [vertex] (aka it is occluded).
   */
  bool _evaluateVertex(Vertex vertex, Vector2 intersection) {
    _formLightRayEndPoint(vertex.vertex, _lightRayEndPoint);

    bool vertexOccluded = false;

    double vertexToLightDistance = distanceBetweenByVector(position, vertex.vertex);

    double currentDistance = double.MAX_FINITE;
    bool intersectionOccurred = false;

    // Iterate through the edges skipping the edge that belongs to the passed "vertex".
    // Note: a shared vertex is associated with 2 edges.
    for(Edge edge in _culledEdgeList) {
      // Skip self-checks for Edge type vertices. Rim types don't have edges so we
      // don't bother self-checking.
      if (_skipEdge(vertex, edge)) {
        continue;
      }

      // Okay, we have a an Edge that isn't associated with the currently evaluating "vertex".
      // Does this vertex's light-ray intersect this Edge? If it does then we compare the distance
      // with the last distance.

      // Now we take a light-ray (formed between the "vertex" and light position)
      // and check for an intersection on the current edge.
      bool intersect = segmentIntersect(position, _lightRayEndPoint, edge.cP0, edge.cP1, _intersection);

      if (intersect) {
        // Note that an intersection occurred. This means that the current vertex won't
        // be projecting onto the Rim. It may be projecting onto another edge.
        // We can't stop though because there may be closer edges and we always
        // want the closer edge.
        intersectionOccurred = true;

        // The light-ray intersected with current edge.
        // This means the "vertex" is projecting either onto the Rim or onto another 
        // Edge farther away from the light.
        double newDistance = distanceBetweenByVector(_intersection, position);

        // Is this intersection closer to the light than the "vertex" being evaluated.
        // If the intersection is closer to the light then the vertex is occluded
        // by the edge that caused the intersection.
        if (newDistance < vertexToLightDistance) {
          // this "vertex" is occluded by current edge we are scanning.
          vertexOccluded = true;
          // There is no point to scanning further.
          break;
        }

        // Else is this intersection is closer to the light than the previous intersection.
        if (newDistance < currentDistance) {
          // This intersection is closer. Track it.
          currentDistance = newDistance;
          intersection.setFrom(_intersection);
        }
      }

    } // end For Edge

    if (!intersectionOccurred && !vertexOccluded && vertex.type == Vertex.EDGE) {
      // No intersection occurred with other culled edges in the culled edge list.
      // And because the vertex isn't occluded it will project a shadow vertex onto
      // the Rim.
      // We really don't care if it was shared or not.
        _calcRimIntersect(_lightRayEndPoint, intersection);
    }
    
    return vertexOccluded;
  }

  bool _skipEdge(Vertex v, Edge e) {
    if (v.type == Vertex.EDGE) {
      if (v.shared == Vertex.SHARED) {
        if (e.id == v.prevEdgeId || e.id == v.nextEdgeId) {
          if (e.polygonId == v.polygonId)
            return true; // Skip
        }
      }
      else {
        if (e.id == v.edgeId && e.polygonId == v.polygonId) {
          return true; // Skip
        }
      }
    }

    return false; // Dont' skip
  }

  /**
   * We need to determine if the edge is facing the light so we
   * can determine with order to add edge-end-points and the associated
   * project vertex.
   * Because our algorithm works in a CCW order when we "enter" an edge
   * we want to add the projected-vertex first and then the edge vertex.
   * When we "exit" an edge we always want to add the project-vertex
   * first then the edge end point.
   * Knowing which side the light is on helps us in determining what to do.
   */
  bool _isEdgeFacingLight(Edge edge) {
    // Form a ray that points towards the Light and compare
    // this with Edge's normal.
    Vector2 ray = new Vector2(position.x - edge.mid.x, position.y - edge.mid.y);

    // if dot == 1, they are facing exactly the same direction
    // if dot == -1, they are facing exactly the opposite direction
    // if dot > 0, they are facing roughly the same direction
    // if dot < 0, they are facing roughly the opposite direction
    // Because the Ray is non-normalized the dot product also
    // represents the distance of the Light from the edge.
    double dot = edge.normal.dot(ray);

    if (dot < 0.0)
      return false; // The edge is facing away from light. So the light is behind the edge.

    return true;
  }

  void _formLightRayEndPoint(Vector2 vertex, Vector2 endPoint) {
    endPoint.setValues(vertex.x - position.x, vertex.y - position.y);
    endPoint.normalize();
    endPoint.scale(radius + (radius * 0.1));
    endPoint.setValues(endPoint.x + position.x, endPoint.y + position.y);
  }

  void _buildBasicRim() {
    for(double nextAngle = 0.0; nextAngle < TPI; nextAngle += _theta_inc) {
      _vector.setValues(radius * math.cos(-nextAngle) + position.x, radius * math.sin(-nextAngle) + position.y);
      Vertex nv = new Vertex.withVectorAndRadial(_vector, nextAngle);
      _shadowVertices.add(nv);
    }
  }

  void _addCulledEdge(Vertex v0, Vertex v1, Polygon p, Edge edge) {
    _calcRadialPos(v0);
    _calcRadialPos(v1);

    if (v0.visited == Vertex.NOTVISITED) {
      v0.visited = Vertex.VISITED;
      _culledVertices.add(v0);
    }
    if (v1.visited == Vertex.NOTVISITED) {
      v1.visited = Vertex.VISITED;
      _culledVertices.add(v1);
    }

    // Store the culled edge with the edge itself.
    edge.cP0.x = v0.vertex.x;
    edge.cP0.y = v0.vertex.y;
    edge.cP1.x = v1.vertex.x;
    edge.cP1.y = v1.vertex.y;

    v0.endType = Vertex.EDGE_START;
    v1.endType = Vertex.EDGE_END;
    
    v0.edgeId = edge.id;
    v1.edgeId = edge.id;
    
    v0.polygonId = p.id;
    v1.polygonId = p.id;
    
    _culledEdgeList.add(edge);
  }

  void _calcRimIntersect(Vector2 lightRayEndPoint, Vector2 intersection) {
    for(Edge rimEdge in rim.edgeList) {
      Vertex rim0 = rim.getVertex(rimEdge.p0);
      Vertex rim1 = rim.getVertex(rimEdge.p1);

      bool intersected = segmentIntersect(position, lightRayEndPoint, rim0.vertex, rim1.vertex, intersection);

      if (intersected)
        break;
    }
  }

  /*
   * This method ignores parallel lines. Which means a caster can only
   * intersect an edge only once, but it can intersect two different edges.
   */
  int _calcRimIntersects(Vector2 p0, Vector2 p1, Vector2 intersect1, Vector2 intersect2) {
    int intersectCount = 0;

    List<Edge> rimEdges = rim.edgeList;

    Iterator<Edge> itr = rimEdges.iterator;
    bool moreEdges;
    Vector2 intersect = new Vector2.zero();

    do {
      moreEdges = itr.moveNext();

      while (moreEdges) {
        Edge rimEdge = itr.current;

        Vertex rim0 = rim.getVertex(rimEdge.p0);
        Vertex rim1 = rim.getVertex(rimEdge.p1);

        bool intersected = segmentIntersect(p0, p1, rim0.vertex, rim1.vertex, intersect);

        if (intersected) {
          if (intersectCount == 0) {
            intersect1.x = intersect.x;
            intersect1.y = intersect.y;
          } else {
            intersect2.x = intersect.x;
            intersect2.y = intersect.y;
          }
          intersectCount++;
          break;
        }

        moreEdges = itr.moveNext();
      }

      // If we found an intersect then there may be another intersect.
    } while (intersectCount < 2 && moreEdges);

    return intersectCount;
  }

  void _calcRadialPos(Vertex vertex) {
    _lightRay.setValues(vertex.vertex.x - position.x, vertex.vertex.y - position.y); // Points towards vertex.

    double angle = angleBetween(_lightRay, _xAxis);

    if (angle < 0.0)
      angle += math.PI * 2.0;

    vertex.radialPos = angle;
  }

  void draw(CanvasRenderingContext2D context) {
    // Draw rim first.
    if (showLightRim)
      rim.draw(context);

    // Draw inner drag circle
    context..beginPath()
           ..arc(position.x, position.y, radius / 10, 0, 2 * math.PI, false)
           ..fillStyle = '#ffff00'
           ..fill()
           ..lineWidth = 1
           ..strokeStyle = '#003300'
           ..stroke();

    // Draw cull and Trim Edges
    if (showShadowedEdgeSegs) {
      context..lineWidth = 1
             ..strokeStyle = "magenta";
      for(Edge edge in _culledEdgeList) {
        // Convert index to vertex
        context..beginPath()
               ..moveTo(edge.cP0.x, edge.cP0.y)
               ..lineTo(edge.cP1.x, edge.cP1.y)
               ..stroke();
      }
    }
    
    // Draw light shadow rim
    if (_shadowVertices.length > 0) {
      context..lineWidth = 1
             ..strokeStyle = "yellow";

      Vertex p = _shadowVertices[0];
      context..beginPath()
             ..moveTo(p.vertex.x, p.vertex.y);

      Iterable<Vertex> subList = _shadowVertices.getRange(1, _shadowVertices.length);
      for(Vertex p in subList) {
        context.lineTo(p.vertex.x, p.vertex.y);
      }
      context..closePath()
             ..stroke();
    }

    // Draw Rim vertices
    if (showVertices) {
      if (_shadowVertices.length > 0) {
        for(Vertex v in _shadowVertices) {
          context..fillStyle = '#ff0000'
                 ..fillRect(v.vertex.x - 2.5, v.vertex.y - 2.5, 5, 5);
        }
      }
    }
  }

  bool isPointOnCenter(Point location) {
    double distance = distanceBetweenByDouble(location.x.toDouble(), location.y.toDouble(), position.x, position.y);
    return distance < selectRadius;
  }

  void moveBy(double dx, double dy) {
    position.setValues(position.x + dx, position.y + dy);
    dirty = true;
  }

  void keyboardEvent(KeyEvent ke) {
    //print("key code: ${ke.keyCode}");
    switch (ke.keyCode) {
      case 49: // 1 key
        position.x -= 20.0;
        break;
      case 50: // 2 key
        position.x += 20.0;
        break;
    }

    dirty = true;
    //print(_edgeFocus);
  }
}