part of shadows;

int SVComparator(ShadowVertex a, ShadowVertex b) {
  return a.radialPos.compareTo(b.radialPos);
}

class ShadowVertex {
  // ----------------------------------------------------------
  // Vars
  // ----------------------------------------------------------
  static int _genId = 0;  // unique id.

  // The closet intersection to the Light's position.
  // This value could be p0 or p1 of the occluding edge.
  // Or it could be nothing if one of the end points where outside of the light's range or
  // intersected the Rim. If intersected Rim then intersect2 holds the intersection.
  Vector2 intersect1;
  int edgeId1;

  // "intersect2" always represents a rim intersection or interior edge intersection.
  // Rim intersects come in 2 types:
  // 1: an intersect because an edge intersected with the rim
  // 2: a projected intersect from an edge point in-view of the light.
  Vector2 intersect2;
  int edgeId2;

  // Defines what type of projected shadow vertex "intersect2" is:
  // 0 = occluded/discarded, (actually this is never collected)
  // 1 = Rim, blue
  // 2 = Interior, white
  // 3 = Partial (green)
  //      (only one edge was in the light's range). In this case "intersect1" is blank/meaningless.
  //      Thus "intersect2" is a rim intersection verses an interior intersection.
  int type;

  // Where radially this intersect is relative to the +x axis.
  // It is used during radial sorting.
  double radialPos;

  // Is this SV originating from a p0 end point or p1 end point.
  // 0 = starting of a shadow rim,
  // 1 = end of a shadow rim,
  // 2 = Interior
  // Because CCW, p1s will always be "start"ing.
  int endType;

  int id;

  // This index is used to "know" what the original index was prior to radial sorting.
//  int sortIndex;

  // ----------------------------------------------------------
  // Factories
  // ----------------------------------------------------------
  factory ShadowVertex() {
    ShadowVertex sv = new ShadowVertex.withId(_genId++);
    return sv;
  }

  factory ShadowVertex.withNoId() {
    ShadowVertex sv = new ShadowVertex.withId(-1);
    return sv;
  }

  factory ShadowVertex.clone(ShadowVertex sv) {
    ShadowVertex clone = new ShadowVertex.withId(_genId++);

    clone.edgeId1 = sv.edgeId1;
    clone.edgeId2 = sv.edgeId2;
    clone.endType = sv.endType;
    clone.type = sv.type;
    if (sv.intersect1 != null)
      clone.intersect1 = sv.intersect1.clone();
    clone.intersect2 = sv.intersect2.clone();
    clone.radialPos = sv.radialPos;

    return clone;
  }

  // ----------------------------------------------------------
  // Constructors
  // ----------------------------------------------------------
  ShadowVertex.withId(this.id);

  // ----------------------------------------------------------
  // Methods
  // ----------------------------------------------------------
  void clear() {
    edgeId1 = null;
    edgeId2 = null;
    endType = null;
    type = null;
    intersect1 = null;
    intersect2 = null;
    radialPos = null;
  }

  @override
  String toString() {
    String typeN;
    String endTypeN;
    switch (type) {
      case 1: typeN = "blue"; break;
      case 2: typeN = "white"; break;
      case 3: typeN = "green"; break;
    }
    switch (endType) {
      case 0: endTypeN = "start"; break;
      case 1: endTypeN = "end"; break;
      case 2: endTypeN = "interior"; break;
    }

    return "id: ${id}, type:${typeN}(${type}), endT:${endTypeN}, "
    "eId1:${edgeId1}, eId2:${edgeId2}, "
    "intr1:${intersect1}, intr2:${intersect2}, "
    "radP:${radialPos}";
  }
}