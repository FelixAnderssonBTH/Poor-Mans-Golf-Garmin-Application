#!/usr/bin/env python3
"""
OSM Golf Course to Connect IQ Converter

Parses Overpass Turbo JSON export and generates a course JSON file
with integer coordinates for Connect IQ watches.

Usage:
    python osm_to_connectiq.py <overpass_export.json>
"""

import json, sys, math, os


def haversine(lat1, lon1, lat2, lon2):
    """Math to handle cordinates to meters"""
    R = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def point_to_segment_dist(px, py, ax, ay, bx, by):
    """Distance in meters from point to line segment."""
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return haversine(px, py, ax, ay)
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    cx, cy = ax + t * dx, ay + t * dy
    return haversine(px, py, cx, cy)


def min_dist_point_to_path(lat, lon, path):
    """Min distance from a point to path."""
    min_d = float('inf')
    for i in range(len(path) - 1):
        d = point_to_segment_dist(lat, lon, path[i][0], path[i][1], path[i+1][0], path[i+1][1])
        if d < min_d:
            min_d = d
    return min_d


def polygon_min_dist_to_path(poly, path):
    """Min distance from any polygon vertex to path segments."""
    min_d = float('inf')
    for pt in poly:
        d = min_dist_point_to_path(pt[0], pt[1], path)
        if d < min_d:
            min_d = d
    return min_d


def point_in_polygon(px, py, poly):
    """Ray casting point-in-polygon. Checks if a fairway goes through the shot line"""
    n = len(poly)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside


def segments_intersect(a1, a2, b1, b2):
    """Check if segment a1-a2 crosses segment b1-b2."""
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    d1 = cross(b1, b2, a1)
    d2 = cross(b1, b2, a2)
    d3 = cross(a1, a2, b1)
    d4 = cross(a1, a2, b2)
    if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
       ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
        return True
    return False


def path_intersects_polygon(path, poly):
    """True if the path goes through the polygon: any path point inside,
    or any path segment crosses a polygon edge."""
    for pt in path:
        if point_in_polygon(pt[0], pt[1], poly):
            return True
    for i in range(len(path) - 1):
        for j in range(len(poly) - 1):
            if segments_intersect(path[i], path[i+1], poly[j], poly[j+1]):
                return True
    return False


def centroid(p):
    if not p:
        return [0, 0]
    return [sum(x[0] for x in p)/len(p), sum(x[1] for x in p)/len(p)]


def simplify_polygon(points, tol=0.00002):
    """
    Mathematical algorithm to reduce the number of points in a polygon but still keep its shape
    This is important for the view of course in the garmin app, we want to see the map but also not overload the watch memory
    https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
    """
    if len(points) <= 4:
        return points
    def pd(p, s, e):
        if s[0]==e[0] and s[1]==e[1]:
            return math.sqrt((p[0]-s[0])**2 + (p[1]-s[1])**2)
        u = max(0, min(1, ((p[0]-s[0])*(e[0]-s[0]) + (p[1]-s[1])*(e[1]-s[1])) / ((e[0]-s[0])**2 + (e[1]-s[1])**2)))
        return math.sqrt((p[0]-s[0]-u*(e[0]-s[0]))**2 + (p[1]-s[1]-u*(e[1]-s[1]))**2)
    def rdp(pts, eps):
        if len(pts) <= 2:
            return pts
        d, idx = 0, 0
        for i in range(1, len(pts)-1):
            dd = pd(pts[i], pts[0], pts[-1])
            if dd > d:
                d, idx = dd, i
        if d > eps:
            return rdp(pts[:idx+1], eps)[:-1] + rdp(pts[idx:], eps)
        return [pts[0], pts[-1]]
    r = rdp(points, tol)
    if len(r) > 2 and r[0] != r[-1]:
        r.append(r[0])
    return r


def to_int(v):
    return int(round(v * 100000))


def slugify(name):
    """Convert course name to a safe filename slug."""
    import re
    s = name.lower().strip()
    s = re.sub(r'[åä]', 'a', s)
    s = re.sub(r'[ö]', 'o', s)
    s = re.sub(r'[^a-z0-9]+', '_', s)
    s = s.strip('_')
    return s


class OSMGolfParser:
    def __init__(self, data):
        self.course_name = ""
        self.holes = []
        self.pins = []
        self.greens = []
        self.fairways = []
        self.bunkers = []
        self.tees = []
        self.water = []

        for el in data.get("elements", []):
            tags = el.get("tags", {})
            geom = el.get("geometry", [])
            g = tags.get("golf", "")
            lei = tags.get("leisure", "")

            if el["type"] == "node" and g == "pin":
                self.pins.append({"lat": el["lat"], "lon": el["lon"]})
            elif el["type"] == "way":
                pts = [[p["lat"], p["lon"]] for p in geom]
                if not pts:
                    continue
                if lei == "golf_course" and not g:
                    if tags.get("name"):
                        self.course_name = tags["name"]
                    continue
                if g == "hole":
                    self.holes.append({"ref": int(tags.get("ref",0)), "par": int(tags.get("par",0)),
                                       "handicap": int(tags.get("handicap",0)), "path": pts})
                elif g == "green":
                    self.greens.append(pts)
                elif g == "fairway":
                    self.fairways.append(pts)
                elif g == "bunker":
                    self.bunkers.append(pts)
                elif g == "tee":
                    self.tees.append(pts)
                elif g == "water_hazard":
                    self.water.append(pts)

        self.holes.sort(key=lambda h: h["ref"])
        print(f"  Course: {self.course_name}")
        print(f"  Holes={len(self.holes)} Pins={len(self.pins)} Greens={len(self.greens)} "
              f"FW={len(self.fairways)} BK={len(self.bunkers)} Tees={len(self.tees)} Water={len(self.water)}")

    def build_course(self):
        # Clean course name for Connect IQ compatibility
        clean_name = self.course_name
        clean_name = clean_name.replace('\u00e4', 'a').replace('\u00c4', 'A')
        clean_name = clean_name.replace('\u00f6', 'o').replace('\u00d6', 'O')
        clean_name = clean_name.replace('\u00e5', 'a').replace('\u00c5', 'A')
        course = {"name": clean_name, "par": sum(h["par"] for h in self.holes), "holes": []}

        for hole in self.holes:
            path = hole["path"]
            end, start = path[-1], path[0]

            # --- Pin ---
            pin = min(self.pins, key=lambda p: haversine(end[0], end[1], p["lat"], p["lon"]), default=None)
            pin_pos = [pin["lat"], pin["lon"]] if pin and haversine(end[0], end[1], pin["lat"], pin["lon"]) < 30 else end

            # --- Tee ---
            tee = min(self.tees, key=lambda t: haversine(start[0], start[1], centroid(t)[0], centroid(t)[1]), default=None)
            tee_pos = centroid(tee) if tee and haversine(start[0], start[1], centroid(tee)[0], centroid(tee)[1]) < 80 else start

            # --- Green ---
            green = min(self.greens, key=lambda gg: haversine(pin_pos[0], pin_pos[1], centroid(gg)[0], centroid(gg)[1]), default=None)
            if green and haversine(pin_pos[0], pin_pos[1], centroid(green)[0], centroid(green)[1]) > 60:
                green = None
            green_s = simplify_polygon(green, 0.00001) if green else None

            # --- Fairways ---
            # PRIMARY: path goes through the fairway polygon (intersection test)
            # SECONDARY: any fairway vertex within 60m of path (for small fairways near path)
            hole_fw = []
            for fw in self.fairways:
                if path_intersects_polygon(path, fw) or polygon_min_dist_to_path(fw, path) < 80:
                    hole_fw.append(simplify_polygon(fw, 0.00001))

            # --- Bunkers: centroid within 60m of path ---
            hole_bk = []
            seen_bk = set()
            for b in self.bunkers:
                c = centroid(b)
                if min_dist_point_to_path(c[0], c[1], path) < 80:
                    k = (round(c[0], 5), round(c[1], 5))
                    if k not in seen_bk:
                        seen_bk.add(k)
                        hole_bk.append(c)

            # --- Water: any vertex within 100m of path ---
            hole_wt = []
            seen_wt = set()
            for w in self.water:
                if polygon_min_dist_to_path(w, path) < 120:
                    c = centroid(w)
                    k = (round(c[0], 4), round(c[1], 4))
                    if k not in seen_wt:
                        seen_wt.add(k)
                        hole_wt.append(simplify_polygon(w, 0.00001))

            # --- Distance ---
            dist = sum(haversine(path[i-1][0], path[i-1][1], path[i][0], path[i][1]) for i in range(1, len(path)))

            h = {
                "num": hole["ref"], "par": hole["par"], "hcp": hole["handicap"], "dist": round(dist),
                "tee": [to_int(tee_pos[0]), to_int(tee_pos[1])],
                "pin": [to_int(pin_pos[0]), to_int(pin_pos[1])],
                "path": [[to_int(p[0]), to_int(p[1])] for p in path],
            }
            if green_s:
                h["green"] = [[to_int(p[0]), to_int(p[1])] for p in green_s]
            if hole_fw:
                h["fw"] = [[[to_int(p[0]), to_int(p[1])] for p in fw] for fw in hole_fw]
            if hole_bk:
                h["bk"] = [[to_int(b[0]), to_int(b[1])] for b in hole_bk]
            if hole_wt:
                h["water"] = [[[to_int(p[0]), to_int(p[1])] for p in w] for w in hole_wt]

            course["holes"].append(h)
            print(f"  Hole {hole['ref']:2d}: Par {hole['par']} {round(dist):3d}m | "
                  f"G={'Y' if green_s else '-'} FW={len(hole_fw)} BK={len(hole_bk)} W={len(hole_wt)}")

        return course


def write_output(course, out_path):
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(course, f, separators=(",", ":"), ensure_ascii=False)
    print(f"  {out_path} ({os.path.getsize(out_path):,} bytes)")


def main():
    if len(sys.argv) < 2:
        print("Usage: python osm_to_connectiq.py <course.json>")
        sys.exit(1)

    inp = sys.argv[1]
    out = os.path.splitext(inp)[0] + "_garmin.json"

    print(f"Reading: {inp}")
    with open(inp, "r", encoding="utf-8") as f:
        osm = json.load(f)

    print("\nParsing...")
    parser = OSMGolfParser(osm)
    if not parser.holes:
        print("ERROR: No holes found!")
        sys.exit(1)

    print("\nBuilding course...")
    course = parser.build_course()

    print(f"\nWriting to: {out}")
    write_output(course, out)

    print(f"\n{'='*50}")
    print(f"  {course['name']} - Par {course['par']}")
    print(f"  JSON size: {os.path.getsize(out):,} bytes")
    print(f"{'='*50}")
    for h in course["holes"]:
        print(f"  Hole {h['num']:2d} Par {h['par']} {h['dist']:3d}m  "
              f"G={'Y' if 'green' in h else '-'} FW={len(h.get('fw',[]))} "
              f"BK={len(h.get('bk',[]))} W={len(h.get('water',[]))}")
    print("\nDone!")


if __name__ == "__main__":
    main()
