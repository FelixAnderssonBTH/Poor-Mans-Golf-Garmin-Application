import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from osm_to_connectiq import centroid, green_reference_points

# Coordinates are lat/lon * 1e5. At 48 degrees north one lat unit is ~1.1132 m
# and one lon unit is ~0.745 m, so this green is ~24.5 m deep by ~29.8 m wide.
GREEN_RECT = [
    [4800303, 1099980],
    [4800303, 1100020],
    [4800325, 1100020],
    [4800325, 1099980],
    [4800303, 1099980],   # closing vertex, as every OSM ring has
]

TEE = [4800000, 1100000]
PIN = [4800314, 1100000]       # ~350 m due north of the tee


def test_centre_ignores_the_repeated_closing_vertex():
    """centroid() on the raw ring counts the first point twice and lands off
    centre; green_reference_points must drop it before averaging."""
    naive = centroid(GREEN_RECT)
    assert naive[0] != 4800314.0          # 4800311.8 -- visibly wrong

    _, gc, _ = green_reference_points(GREEN_RECT, TEE, PIN)
    assert abs(gc[0] - 4800314.0) < 0.01
    assert abs(gc[1] - 1100000.0) < 0.01


def test_axis_aligned_green_front_centre_back():
    """Tee due south of the pin, so the axis is due north and the answers are
    the green's own south edge, centre and north edge."""
    gf, gc, gb = green_reference_points(GREEN_RECT, TEE, PIN)

    assert abs(gf[0] - 4800303.0) < 0.01
    assert abs(gc[0] - 4800314.0) < 0.01
    assert abs(gb[0] - 4800325.0) < 0.01

    for point in (gf, gc, gb):
        assert abs(point[1] - 1100000.0) < 0.01


def test_front_is_nearer_the_tee_than_back():
    gf, gc, gb = green_reference_points(GREEN_RECT, TEE, PIN)
    d = lambda p: math.hypot(p[0] - TEE[0], p[1] - TEE[1])
    assert d(gf) < d(gc) < d(gb)


def test_front_and_back_stay_on_the_axis_when_the_green_is_offset():
    """A green whose mass sits east of the tee->pin line must still produce
    front/back points on the line, not points skewed sideways onto a vertex."""
    offset = [
        [4800303, 1100050],
        [4800303, 1100120],
        [4800325, 1100120],
        [4800325, 1100050],
        [4800303, 1100050],
    ]
    gf, gc, gb = green_reference_points(offset, TEE, PIN)
    assert abs(gf[1] - gc[1]) < 0.01
    assert abs(gb[1] - gc[1]) < 0.01
    assert gf[0] < gc[0] < gb[0]


def test_degenerate_axis_returns_the_centre_three_times():
    """Guards against dividing by a zero-length axis when tee == pin."""
    gf, gc, gb = green_reference_points(GREEN_RECT, PIN, PIN)
    assert gf == gc == gb

def test_reference_points_are_ordered_along_the_axis():
    """The ordering invariant that catches a sign error in the projection.
    Runs against whatever course JSON this branch ships."""
    import json
    from pathlib import Path

    course = (Path(__file__).resolve().parents[2] / "Poor-Mans-Golf" /
              "resources" / "JsonData" / "course_trummenas.json")
    holes = json.loads(course.read_text())["holes"]

    checked = 0
    for hole in holes:
        if "green" not in hole:
            continue
        assert "gf" in hole and "gc" in hole and "gb" in hole, f"hole {hole['num']}"
        tee = hole["tee"]
        d = lambda p: math.hypot(p[0] - tee[0], p[1] - tee[1])
        assert d(hole["gf"]) < d(hole["gc"]) < d(hole["gb"]), f"hole {hole['num']}"
        checked += 1
    assert checked == 18