part of shadows;

// @deprecated
// This was a firt attempt at shadows. It uses a very poor
// design and only support single segment polygons.
// lightSweep.dart is the actual working version.
class Light {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  final double radius;
  final int segments;

  double _theta_inc;

  Polygon rim = new Polygon();

  /// Typical "yellow"
  String _color;

  Vector2 position;

  double selectRadius;
  bool _dirty = true;

  List<ShadowVertex> _shadowVertices = new List<ShadowVertex>();
//  int _shadowVertexCount = 0;
  int _svCircularIndex;
  List<Vertex> _rimVertices = new List<Vertex>();

  // Cache vars
  Vector2 _lightRay = new Vector2.zero();
  Vector2 _lightRayEndPoint0 = new Vector2.zero();
  Vector2 _lightRayEndPoint1 = new Vector2.zero();
  ShadowVertex _shadowVertex = new ShadowVertex.withNoId();
  Vector2 _xAxis = new Vector2(1.0, 0.0);
  Vector2 _ray = new Vector2.zero();
  Vector2 _vertex = new Vector2.zero();
  Vector2 _normal = new Vector2.zero();
  Vector2 _intersect1 = new Vector2.zero();
  Vector2 _intersect2 = new Vector2.zero();
  Vector2 _intersection = new Vector2.zero();
  Vector2 _currentIntersection = new Vector2.zero();

  // Debug stuff
  int _casterCount = 0;
  int _casterFocus = 0;
  int _casterFocusIndexCount = 0;
  Vector2 lightRayEndPointVisual0 = new Vector2.zero();
  Vector2 lightRayEndPointVisual1 = new Vector2.zero();

  // ----------------------------------------------------------
  // Factories
  // ----------------------------------------------------------
  factory Light(double radius, int segments) {
    Light l = new Light._withRadiusSegments(radius, segments);
    l.color = "#646500";
    l.selectRadius = radius / 10.0;
    l.rim.showNormals = false;
    l._theta_inc = 2.0 * math.PI / segments;
    return l;
  }

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  Light._withRadiusSegments(this.radius, this.segments);

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
    if (_dirty) {
      _dirty = false;

      _casterCount = casters.length;
      _intersect1.setValues(-10.0, -10.0);
      _intersect2.setValues(-10.0, -10.0);
      _intersection.setValues(-10.0, -10.0);
      _lightRayEndPoint0.setValues(position.x, position.y);
      _lightRayEndPoint1.setValues(position.x, position.y);

      _buildRim();

      _shadowVertices.clear();

      _buildShadowVertices(casters);

//      print("shadowVertex count: ${_shadowVertices.length}");

      _rimVertices.clear();

      if (_shadowVertices.length == 0)
        return;

//      print("shadow vertices:");
//      for(ShadowVertex sv in _shadowVertices)
//        print(sv);
//      print("-----------------------");

      _shadowVertices.sort(SVComparator);

//      print("AFTER sort shadow vertices:");
//      for(ShadowVertex sv in _shadowVertices)
//        print(sv);
//      print("-----------------------");

      // or
      //_shadowVertices.sort((ShadowVertex a, ShadowVertex b) => a.radialPos.compareTo(b.radialPos));

      _buildShadowRim();

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

  void _buildShadowVertices(List<Polygon> casters) {
    // BEGIN debug stuff
    _casterFocusIndexCount = 0;
    // END debug stuff

    for(Polygon caster in casters) {
      if (caster.active) {

        List<Edge> edgeList = caster.edgeList;

        // iterate through the edges
        for(Edge edge in edgeList) {
          // Convert index to vertex
          Vertex p0 = caster.getVertex(edge.p0);
          Vertex p1 = caster.getVertex(edge.p1);

          // Is this edge facing the light.
          if (!_isEdgeFacingLight(edge)) {
            edge.normalColor = edge.defaultColor;
            continue; // Skip and go to next face.
          }

          edge.normalColor = "#11ff11";
          int intersectCount = _calcRimIntersects(p0.vertex, p1.vertex, _intersect1, _intersect2);

          switch (intersectCount) {
            case 0:
              // No intersects with Rim.
              // Now we need to know if the Edge is completely inside or outside.
              bool containsP0 = polygonContainsPoint(rim.vertices, p0.vertex);
              bool containsP1 = polygonContainsPoint(rim.vertices, p1.vertex);

              if (containsP0 && containsP1) {
                // Edge is completely INSIDE of Rim.

                // Evaluate p0 first.
                // Because we are moving CCW the p0's vertexType will be "End" = 1.
                _shadowVertex.clear();
                _formLightRayEndPoint(p0.vertex, _lightRayEndPoint0);

                bool occluded0 = _evaluateVertex(p0.vertex, edge, _lightRayEndPoint0, caster, casters, _shadowVertex);
                _shadowVertex.endType = 1; // "end"

                if (!occluded0) {
                  _addShadowVertex(_shadowVertex, p0.vertex);
                }

                // Because this is p1 and we are moving CCW, vertexType = 0 = "start"ing of shadow group.
                _shadowVertex.clear();
                _formLightRayEndPoint(p1.vertex, _lightRayEndPoint1);

                bool occluded1 = _evaluateVertex(p1.vertex, edge, _lightRayEndPoint1, caster, casters, _shadowVertex);
                _shadowVertex.endType = 0; // "start"

                if (!occluded1) {
                  _addShadowVertex(_shadowVertex, p1.vertex);
                }

                //showDebug1("${occluded0}, ${occluded1}");
              } else {
                // Edge is completely OUTSIDE of Rim.
              }
              break;
            case 1:
              // Only 1 intersect with the Rim.
              // Which also means one of the end points is outside and the other inside.
              // This intersect is pretty much just another vertex and it needs to be treated
              // just like any other vertex.

              // Is the "intersect" occluded by any of the casters.
              _formLightRayEndPoint(_intersect1, _lightRayEndPoint0);

              bool occluded = _isPointOccluded(_intersect1, edge, caster, casters, _lightRayEndPoint0);

              bool containsP0 = polygonContainsPoint(rim.vertices, p0.vertex);
              bool containsP1 = polygonContainsPoint(rim.vertices, p1.vertex);

              // Handle the intersection with the Rim first.
              if (!occluded) {
                // Intersect was not occlude by other casters
                _shadowVertex.clear();

                // Which end point --of the original egde-- was inside
                if (!containsP0 && containsP1)
                  _shadowVertex.endType = 1; // p1 is inside, hence intersection is an "end"
                else
                  _shadowVertex.endType = 0; // p0 is inside, hence intersection is a "start"

                // Because it is a Rim intersection it is "green"
                _shadowVertex.type = 3;  // green
                _shadowVertex.intersect2 = _intersect1;
                _shadowVertex.edgeId2 = edge.id;
                //print(shadowVertex);
                _addShadowVertex(_shadowVertex, _intersect1);
              }

              // Now we handle the point that was inside.
              if (containsP0 && !containsP1) {
                // p0 is inside.
                _shadowVertex.clear();
                // Because this is p0 and we are moving CCW, vertexType = 1 = "end"ing of shadow group.
                _formLightRayEndPoint(p0.vertex, _lightRayEndPoint0);
                bool occluded = _evaluateVertex(p0.vertex, edge, _lightRayEndPoint0, caster, casters, _shadowVertex);
                _shadowVertex.endType = 1; // end

                if (!occluded) {
                  // p0 was NOT occluded. So we can add it.
                  _addShadowVertex(_shadowVertex, p0.vertex);
                }
              } else {
                _shadowVertex.clear();
                // p1 is inside
                // Because this is p1 and we are moving CCW, vertexType = 0 = "start"ing of shadow group.
                _formLightRayEndPoint(p1.vertex, _lightRayEndPoint1);
                occluded = _evaluateVertex(p1.vertex, edge, _lightRayEndPoint1, caster, casters, _shadowVertex);
                _shadowVertex.endType = 0; // start

                if (!occluded) {
                  // p1 was NOT occluded.
                  _addShadowVertex(_shadowVertex, p1.vertex);
                }
              }
              break;

            case 2:
              // There was 2 intersects with the Rim.
              // We need to determine which side each intersect is on relative to the edge.
              // The distance from the intersect to an end point is used to determine it.
              // The intersect that is closest to p0 becomes an "end" endType.
              // The intersect that is closest to p1 becomes an "start" endType.

              bool isEnd = false;    // default to p0 end point.
              double distance0 = distanceBetweenByVector(_intersect1, p0.vertex);
              double distance1 = distanceBetweenByVector(_intersect2, p0.vertex);
              // The intersect that is closest to p0 is the deciding factor.
              if (distance0 < distance1) {
                // intersect1 is closer to p0. Hence intersect1 is an "end".
                isEnd = true;
              }

              _formLightRayEndPoint(_intersect1, _lightRayEndPoint0);
              bool occluded = _isPointOccluded(_intersect1, edge, caster, casters, _lightRayEndPoint0);

              if (!occluded) {
                _shadowVertex.clear();
                _shadowVertex.type = 3; // green
                _shadowVertex.intersect2 = _intersect1;
                _shadowVertex.edgeId2 = edge.id;
                if (isEnd)
                  _shadowVertex.endType = 1; // "end"
                else
                  _shadowVertex.endType = 0; // "start"
                _addShadowVertex(_shadowVertex, _intersect1);
              }

              _formLightRayEndPoint(_intersect2, _lightRayEndPoint1);
              occluded = _isPointOccluded(_intersect2, edge, caster, casters, _lightRayEndPoint1);

              if (!occluded) {
                _shadowVertex.clear();
                _shadowVertex.type = 3; // green
                _shadowVertex.intersect2 = _intersect2;
                _shadowVertex.edgeId2 = edge.id;
                if (isEnd)
                  _shadowVertex.endType = 0; // "start"
                else
                  _shadowVertex.endType = 1; // "end"
                _addShadowVertex(_shadowVertex, _intersect2);
              }

              break;
          } // end Switch

        } // next Edge
      }

      // BEGIN debug stuff
      if (_casterFocusIndexCount == _casterFocus) {
        lightRayEndPointVisual0.setValues(_lightRayEndPoint0.x, _lightRayEndPoint0.y);
        lightRayEndPointVisual1.setValues(_lightRayEndPoint1.x, _lightRayEndPoint1.y);
      }
      _casterFocusIndexCount++;
      // END debug stuff

    } // next Caster
  }

  void _buildShadowRim() {
    // First we need to check if a SV group is straddling 0.0f radial
    // We can't just look at the first SV because it could actually be an Interior (aka white) vertex which
    // isn't an end-vertex. Only blue or green are. So we iterate until we hit an end point.
    _svCircularIndex = 0;

    ShadowVertex startSV;
    ShadowVertex nextSV;

    nextSV = _currentSV();
    double nextAngle = _theta_inc;

    // If the first SV in the list is a "white=2=interior" SV
    // then we need to search for the end that is associated with this interior
    // SV.
    if (nextSV.type == 2) {
      // Scan for blue or green end-type
      do {
        nextSV = _nextSV();
      } while (nextSV.type == 2);
    }

    bool straddling = false;

    // Now check to see if the an SV group is straddling the 0.0==>2PI degree boundary
    // We can detect this if the nextSV's endType = 1 = "end". Which means the "start"
    // is on the other side of 2PI.
    if (nextSV.endType == 1) {
      // Straddling. We need to reverse scan for the start SV.
      straddling = true;
      do {
        startSV = _prevSV();
      } while (startSV.type == 2);
    } else {
      // An SV group IS NOT straddling
      _svCircularIndex = 0;
      startSV = _currentSV();
    }

//    print("startSV: ${startSV}");
//    print("_currentSV: ${_currentSV()}");
//    print("staddling: ${straddling}");

    // The outer loop always stops when we hit the first SV that we started with.
    int hitStartSV = 0;
    bool stepOver = false;

    do {
      stepOver = false;

      _walkShadowsVertices(_currentSV());

      ShadowVertex cSV = _currentSV();

      // Find next end-SV.
      if (cSV.id != startSV.id) {
        // We didn't wrap yet. Get the end-SV for the next group.
        do {
          nextSV = _nextSV();
          if (nextSV.id == startSV.id) {
            // We hit while scanning. This means we atleast
            hitStartSV = 1;
          }
          // We know we hit a group-end-SV when the type changes back to 1 or 3.
          // So we continue to scan while it is 2 (white)
        } while (nextSV.type == 2);
      } else {
        hitStartSV = 2;
      }

      if (hitStartSV == 0) {
        // We just walked an SV group and there is still another to be processed.
        // And because there is another group there is a "gap" between them.
        // This "gap" may fit a Rim vertex or not.
        stepOver = false;
      } else {
        // Even though there are no more SV groups there can still be room to
        // fit Rim vertices.
        // At all times RW must check and cross over 2PI.
        stepOver = !straddling;
      }

      nextAngle = _movePie(cSV.radialPos, _theta_inc);

      _walkRimVertices(nextSV, nextAngle, stepOver);

    } while (_currentSV().id != startSV.id);

  }

  void _walkRimVertices(ShadowVertex sv, double nextAngle, stepOver) {
    double radialPos = sv.radialPos;

    if (stepOver)
      radialPos += 2.0 * math.PI;

    // Keep walking
    while (nextAngle < radialPos) {
      _vertex.setValues(radius * math.cos(-nextAngle) + position.x, radius * math.sin(-nextAngle) + position.y);
      _rimVertices.add(new Vertex(_vertex.x, _vertex.y));
      nextAngle += _theta_inc;
    }
  }

  void _walkShadowsVertices(ShadowVertex sv) {
    // Now travel all the SVs in the current group.
    ShadowVertex walkingSV = sv;

    _rimVertices.add(new Vertex(walkingSV.intersect2.x, walkingSV.intersect2.y));   // Add rim vertex first.

    // what type of shadow vertex "intersect2" is:
    // interior (white = 2) or Rim (blue = 1), Rim (green = 3)
    if (walkingSV.type == 1 || walkingSV.type == 2) {
      _rimVertices.add(new Vertex(sv.intersect1.x, sv.intersect1.y));   // Add view vertex second.
    }

    int previousEdgeId = -1;

    if (walkingSV.type == 3)
      previousEdgeId = walkingSV.edgeId2;
    else
      previousEdgeId = walkingSV.edgeId1;

    // Move to the next SV.
    walkingSV = _nextSV();

    // While type = white
    while (walkingSV.type == 2) {
      if (walkingSV.edgeId1 == previousEdgeId) {
        _rimVertices.add(new Vertex(walkingSV.intersect1.x, walkingSV.intersect1.y)); // Add view first
        _rimVertices.add(new Vertex(walkingSV.intersect2.x, walkingSV.intersect2.y)); // Add interior second
        previousEdgeId = walkingSV.edgeId2;
      } else {
        // If we are walking from a green "starter" then "view" is first.
        _rimVertices.add(new Vertex(walkingSV.intersect2.x, walkingSV.intersect2.y)); // Add interior first
        _rimVertices.add(new Vertex(walkingSV.intersect1.x, walkingSV.intersect1.y)); // Add view second
        previousEdgeId = walkingSV.edgeId1;
      }

      walkingSV = _nextSV();
    }

    // We are now at another rim SV
    // We have hit the other end.
    if (walkingSV.type == 1) {
      _rimVertices.add(new Vertex(walkingSV.intersect1.x, walkingSV.intersect1.y));   // Add view vertex first.
    }

    _rimVertices.add(new Vertex(walkingSV.intersect2.x, walkingSV.intersect2.y));   // Add rim vertex second.
  }

  double _movePie(double angle, double theta_inc) {
    double a = 0.0;
    do {
      a += theta_inc;
    } while (a < angle);
    return a;
  }

  ShadowVertex _nextSV() {
    if (_shadowVertices.length != 0)
      _svCircularIndex = (_svCircularIndex + 1) % _shadowVertices.length;
//    print("_nextSV: ${_shadowVertices[_svCircularIndex]}");
    return _shadowVertices[_svCircularIndex];
  }

  ShadowVertex _prevSV() {
    _svCircularIndex--;
    if (_svCircularIndex < 0)
      _svCircularIndex = _shadowVertices.length - 1;
//    print("_prevSV: ${_shadowVertices[_svCircularIndex]}");
    return _shadowVertices[_svCircularIndex];
  }

  ShadowVertex _currentSV() {
//    print("_currentSV: ${_shadowVertices[_svCircularIndex]}");
    return _shadowVertices[_svCircularIndex];
  }

  bool _isPointOccluded(Vector2 vertex, Edge associatedEdge,
                       Polygon associatedPolygon, List<Polygon> casters,
                       Vector2 lightRayEndPoint) {

    double vertexLightDistance = distanceBetweenByVector(position, vertex);

    bool vertexOccluded = false;
    double currentDistance = double.MAX_FINITE;

    for(Polygon caster in casters) {
      if (caster.active) {
        List<Edge> edgeList = caster.edgeList;

        // Iterate through the edges skipping edges the edge that belongs to the "vertex"
        for(Edge edge in edgeList) {
          // Edges can have the same vertex id inside different polygons.
          // So we have to include a check between polygons too.
          // For example, p[0]e[1,2] against p[1]e[1,2]
          if (edge.p0 == associatedEdge.p0 && edge.p1 == associatedEdge.p1 && caster.id == associatedPolygon.id) {
            // The current edge we are checking also belongs to the "vertex" we are checking.
            // We skip self-checks naturally.
            //print("skipping self: ${edge} :: ${evaluateEdge}");
            continue;
          }

          if (!_isEdgeFacingLight(edge)) {
            continue;
          }

          // Convert index to vertex
          Vertex p0 = caster.getVertex(edge.p0);
          Vertex p1 = caster.getVertex(edge.p1);

          bool containsP0 = polygonContainsPoint(rim.vertices, p0.vertex);
          bool containsP1 = polygonContainsPoint(rim.vertices, p1.vertex);
          //showDebug1("${intersect1}, ${intersect2}");

          if (!containsP0 && !containsP1) {
            // The VEPs are outside of the Rim, the Edge could still be intersecting the Rim though.
            // So we can't discount the current Edge yet.

            int intersectCnt = _countRimIntersects(p0.vertex, p1.vertex);

            if (intersectCnt == 0) {
              // Now we know that the Edge is "completely" outside of the Rim
              continue;
            }
          }

          // Now we take a light-ray (formed between the "vertex" and light position) and check for an intersection
          // on the current edge from the edge collection.
          bool intersect = segmentIntersect(position, lightRayEndPoint, p0.vertex, p1.vertex, _intersection);

          if (intersect) {
            // The light-ray intersected with current edge.
            // This means the "vertex" is projecting either onto the Rim or onto another Edge farther away from the light.
            double newDistance = distanceBetweenByVector(_intersection, position);

            // Is this intersection closer to the light than the "vertex" being evaluated.
            // If the intersection is closer to the light then the vertex is occluded by the edge that caused the intersection.
            if (newDistance < vertexLightDistance) {
              // this "vertex" is occluded by current edge we are scanning.
              vertexOccluded = true;
              // No need to continue to process.
              break;  // stop scanning
            }

            if (newDistance < currentDistance) {
              // This intersection is closer. Record it.
              currentDistance = newDistance;
            }

          }
        } // end For Edge

        if (vertexOccluded) {
          break;  // stop scanning because "vertex" is occluded.
        }
      }
    } // end For Polygon

    return vertexOccluded;
  }

  void _addShadowVertex(ShadowVertex sv, Vector2 vertex) {
    _lightRay.setValues(vertex.x - position.x, vertex.y - position.y); // Points towards vertex.

    double angle = angleBetween(_lightRay, _xAxis);

//    if (vertex.y > position.y) {
//      angle += math.PI * 2.0;
//    }

    if (angle < 0.0)
      angle += math.PI * 2.0;

    ShadowVertex newSV = new ShadowVertex.clone(sv);
    newSV.radialPos = angle;

    _shadowVertices.add(newSV);
  }

  /**
   * We check [vertex] against all the other [casters]. But we only want to check edges that are NOT
   * associated with [vertex].
   * [evaluateEdge] and [evalutePolygon] are the edge and polygon associated with the [vertex]. They
   * are used to check selfness.
   * A [vertex] can originate from either p0 or p1,an edge intersection or Rim intersection.
   */
  bool _evaluateVertex(Vector2 vertex, Edge evaluateEdge, Vector2 lightRayEndPoint,
                      Polygon evalutePolygon, List<Polygon> casters, ShadowVertex vertexResult) {
    bool vertexOccluded = false;

    double vertexLightDistance = distanceBetweenByVector(position, vertex);

    double currentDistance = double.MAX_FINITE;

    int intersectCount = 0;
    int currentEdgeId = 0;

    // Check all the casters against the incoming "vertex" except the edge associated with the "vertex".
    for(Polygon caster in casters) {
      if (caster.active) {
        List<Edge> edgeList = caster.edgeList;

        // Iterate through the edges skipping edges the edge that belongs to the "vertex"
        for(Edge edge in edgeList) {
          // Edges can have the same vertex id inside different polygons.
          // So we have to include a check between polygons too.
          // For example, p[0]e[1,2] against p[1]e[1,2]
          if (edge.p0 == evaluateEdge.p0 && edge.p1 == evaluateEdge.p1 && caster.id == evalutePolygon.id) {
            // The current edge we are checking also belongs to the "vertex" we are checking.
            // We skip self-checks naturally.
            //print("skipping self: ${edge} :: ${evaluateEdge}");
            continue;
          }

          if (!_isEdgeFacingLight(edge)) {
            continue;
          }

          // Convert index to vertex
          Vertex p0 = caster.getVertex(edge.p0);
          Vertex p1 = caster.getVertex(edge.p1);

          bool containsP0 = polygonContainsPoint(rim.vertices, p0.vertex);
          bool containsP1 = polygonContainsPoint(rim.vertices, p1.vertex);
          //showDebug1("${intersect1}, ${intersect2}");

          if (!containsP0 && !containsP1) {
            // The VEPs are outside of the Rim, the Edge could still be intersecting the Rim though.
            // So we can't discount the current Edge yet.

            int intersectCnt = _countRimIntersects(p0.vertex, p1.vertex);

            if (intersectCnt == 0) {
              // Now we know that the Edge is "completely" outside of the Rim
              continue;
            }
          }

          // Okay, we have a an Edge that isn't associated with the currently evaluating "vertex".
          // Does this vertex's light-ray intersect this Edge? If it does then we compare the distance
          // with the last distance.
          // We track the closest distance until:
          //      1: we run out of Edges without an intersection being found (meaning it is in full view)
          //      2: or an intersect was less than this "vertex"'s distance (meaning the vertex is occluded)

          // Now we take a light-ray (formed between the "vertex" and light position) and check for an intersection
          // on the current edge from the edge collection.
          bool intersect = segmentIntersect(position, lightRayEndPoint, p0.vertex, p1.vertex, _intersection);

          if (intersect) {
            // The light-ray intersected with current edge.
            // This means the "vertex" is projecting either onto the Rim or onto another Edge farther away from the light.
            double newDistance = distanceBetweenByVector(_intersection, position);

            // Is this intersection closer to the light than the "vertex" being evaluated.
            // If the intersection is closer to the light then the vertex is occluded by the edge that caused the intersection.
            if (newDistance < vertexLightDistance) {
              // this "vertex" is occluded by current edge we are scanning.
              vertexOccluded = true;
              // No need to continue to process.
              break;  // stop scanning
            }

            // Else is this intersection closer to the light than the previous intersection.
            // Ultimately we want:
            //      The closest intersection to the light, but not an intersect that is closer to the light
            //      than the "vertex" passed in otherwise the "vertex" would be occluded.
            //
            // Also, we don't consider edge intersects where the intersection is outside the Rim.
            //      In this case we discard the intersection and continue to check for intersections.
            //      While continuing we may or may not find another intersection.
            bool containsIntersection = polygonContainsPoint(rim.vertices, _intersection);

            if (!containsIntersection) {
              // Intersection at is outside Rim. Discarding edge.
              continue;
            }

            if (newDistance < currentDistance) {
              // This intersection is closer. Record it.
              currentDistance = newDistance;
              // Track intersection for "white" type intersections.
              _currentIntersection.setFrom(_intersection);
              currentEdgeId = edge.id;
              // Track number of intersections for later processing.
              intersectCount++;
            }
          }

        } // next Edge

        if (vertexOccluded) {
          _shadowVertex.type = 0;
          break;  // stop scanning because "vertex" is occluded.
        }
      } // if caster active
    } // next Caster

    // What was the result of processing the vertex against the other casters
    if (!vertexOccluded) {
      // The vertex wasn't occluded so it is in full view (red)
      vertexResult.intersect1 = vertex;
      vertexResult.edgeId1 = evaluateEdge.id;

      // We also need it's projection:
      // either onto another edge (white = 2) or onto the rim (blue = 1).
      if (intersectCount == 0) {
        // There were no intersections. Hence "vertex" caused a projection onto the Rim.
        vertexResult.type = 1; // blue

        // Get Rim Intersection
        _calcRimIntersect(lightRayEndPoint, _intersection);
        //print("intersection: ${intersection}");
        vertexResult.intersect2 = _intersection.clone();
        vertexResult.edgeId2 = evaluateEdge.id;
      } else {
        vertexResult.type = 2; // White = 2
        // There were intersections. Hence vertex caused a projection onto another Edge.
        vertexResult.intersect2 = _currentIntersection.clone();
        vertexResult.edgeId2 = currentEdgeId;
      }
    }

    return vertexOccluded;
  }

  void _formLightRayEndPoint(Vector2 vertex, Vector2 endPoint) {
    endPoint.setValues(vertex.x - position.x, vertex.y - position.y);
    endPoint.normalize();
    double r = radius + radius * 0.2;
    endPoint.scale(r);
    endPoint.setValues(endPoint.x + position.x, endPoint.y + position.y);
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

  int _countRimIntersects(Vector2 p0, Vector2 p1) {
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
          intersectCount++;
          break;
        }

        moreEdges = itr.moveNext();
      }

      // If we found an intersect then there may be another intersect.
    } while (intersectCount < 2 && moreEdges);

    return intersectCount;
  }

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
      return false; // The edge is facing away from light

    return true;
  }

  void draw(CanvasRenderingContext2D context) {
    // Draw rim first.
    rim.draw(context);

    // Draw inner drag circle
    context..beginPath()
           ..arc(position.x, position.y, radius / 10, 0, 2 * math.PI, false)
           ..fillStyle = '#ffff00'
           ..fill()
           ..lineWidth = 1
           ..strokeStyle = '#003300'
           ..stroke();

    // BEGIN
    // Draw debug stuff
//    context..fillStyle = '#ccffcc'
//           ..fillRect(intersect1.x - 2.5, intersect1.y - 2.5, 5, 5);
//
//    context..fillStyle = '#ccffcc'
//           ..fillRect(intersect2.x - 2.5, intersect2.y - 2.5, 5, 5);

    // Draw shadow vertices
    for(ShadowVertex sv in _shadowVertices) {
      //print(sv);
      switch(sv.type) {
        case 1: // blue
          context..fillStyle = '#0000ff'
                 ..fillRect(sv.intersect2.x - 2.5, sv.intersect2.y - 2.5, 5, 5);
          break;
        case 2: // white
          context..fillStyle = '#ffffff'
                 ..fillRect(sv.intersect2.x - 2.5, sv.intersect2.y - 2.5, 5, 5);
          break;
        case 3: // green
          if (sv.endType == 0)  // "start"
            context..fillStyle = '#00ff00'
                   ..fillRect(sv.intersect2.x - 2.5, sv.intersect2.y - 2.5, 5, 5);
          else
            context..fillStyle = 'magenta'
                   ..fillRect(sv.intersect2.x - 2.5, sv.intersect2.y - 2.5, 5, 5);
          break;
      }

      if (sv.type < 3) {
        if (sv.endType == 0)
          context..fillStyle = '#ff0000'
                 ..fillRect(sv.intersect1.x - 2.5, sv.intersect1.y - 2.5, 5, 5);
        else
          context..fillStyle = 'magenta'
                 ..fillRect(sv.intersect1.x - 2.5, sv.intersect1.y - 2.5, 5, 5);
      }
    }

    // Draw light shadow rim
    if (_rimVertices.length > 0) {
      context..lineWidth = 1
             ..strokeStyle = "yellow";

      Vertex p = _rimVertices[0];
      context..beginPath()
             ..moveTo(p.vertex.x, p.vertex.y);

      Iterable<Vertex> subList = _rimVertices.getRange(1, _rimVertices.length);
      for(Vertex p in subList) {
        context.lineTo(p.vertex.x, p.vertex.y);
      }
      context.closePath();
      context.stroke();
    }

//    context..beginPath()
//           ..moveTo(position.x, position.y)
//           ..lineTo(lightRayEndPointVisual0.x, lightRayEndPointVisual0.y)
//           ..strokeStyle = "magenta"
//          ..stroke();
//    context..beginPath()
//           ..moveTo(position.x, position.y)
//           ..lineTo(lightRayEndPointVisual1.x, lightRayEndPointVisual1.y)
//           ..strokeStyle = "pink"
//          ..stroke();

    // END
  }

  bool isPointOnCenter(Point location) {
    double distance = distanceBetweenByDouble(location.x.toDouble(), location.y.toDouble(), position.x, position.y);
    return distance < selectRadius;
  }

  void moveBy(double dx, double dy) {
    position.setValues(position.x + dx, position.y + dy);
    _dirty = true;
  }

  void keyboardEvent(KeyEvent ke) {
    //print("key code: ${ke.keyCode}");
    switch (ke.keyCode) {
      case 49: // 1 key
        _casterFocus = (_casterFocus + 1) % _casterCount;
        break;
      case 50: // 2 key
        _casterFocus--;
        if (_casterFocus < 0)
          _casterFocus = _casterCount - 1;
        break;
    }

    _dirty = true;
    //print(_edgeFocus);
  }
}