"""SQLite helpers + round JSON importer."""

import os
import sqlite3

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, "golf.db")
SCHEMA_PATH = os.path.join(BASE_DIR, "schema.sql")


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db():
    with open(SCHEMA_PATH) as f:
        schema = f.read()
    with get_db() as conn:
        conn.executescript(schema)
        existing = {row["name"] for row in conn.execute("PRAGMA table_info(holes)")}
        if "par" not in existing:
            conn.execute("ALTER TABLE holes ADD COLUMN par INTEGER")
        conn.commit()


def import_round(data, course_name=None, notes=None):
    """Import an extracted round JSON dict. Returns the new round_id."""
    activity = data.get("activity", {}) or {}
    holes_data = data.get("holes", []) or []
    shots_data = data.get("shots", []) or []
    track_data = data.get("track", []) or []

    # Fall back to the course name embedded in the FIT, if any
    if not course_name:
        course_name = activity.get("course_name") or None

    with get_db() as conn:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO rounds
               (course_name, start_time, time_seconds, distance_m, calories, sport, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (course_name,
             activity.get("start_time"),
             activity.get("time_seconds"),
             activity.get("distance_m"),
             activity.get("calories"),
             activity.get("sport"),
             notes),
        )
        round_id = cur.lastrowid

        # Holes (extract_round.py)
        for h in holes_data:
            cur.execute(
                """INSERT INTO holes (round_id, hole_num, strokes, par, time_seconds)
                   VALUES (?, ?, ?, ?, ?)""",
                (round_id, h.get("hole"), h.get("strokes"), h.get("par"),
                 h.get("time_seconds")),
            )

        any_authoritative = any("hole" in s for s in shots_data)
        if any_authoritative:
            for s in shots_data:
                hn = s.get("hole")
                if hn is None or hn <= 0:
                    continue  # skip shots tagged as "between holes"
                cur.execute(
                    """INSERT INTO shots (round_id, hole_num, shot_num, lat, lon, time)
                       VALUES (?, ?, ?, ?, ?, ?)""",
                    (round_id, hn, s.get("shot_num", 1), s["lat"], s["lon"], s["time"]),
                )
        else:
            hole_num = 0
            prev_shot_num = 10**9
            for s in shots_data:
                sn = s.get("shot_num", 1)
                if sn < prev_shot_num:
                    hole_num += 1
                prev_shot_num = sn
                cur.execute(
                    """INSERT INTO shots (round_id, hole_num, shot_num, lat, lon, time)
                       VALUES (?, ?, ?, ?, ?, ?)""",
                    (round_id, hole_num, sn, s["lat"], s["lon"], s["time"]),
                )

        # Track points
        for t in track_data:
            cur.execute(
                """INSERT INTO track_points (round_id, time, lat, lon, hr)
                   VALUES (?, ?, ?, ?, ?)""",
                (round_id, t["time"], t["lat"], t["lon"], t.get("hr")),
            )

        conn.commit()
        return round_id


def list_rounds(course_name=None):
    """List rounds, optionally filtered to a single course."""
    sql = """
        SELECT r.id, r.course_name, r.start_time, r.time_seconds, r.distance_m,
               r.calories, r.sport, r.notes,
               (SELECT COUNT(*) FROM shots WHERE round_id = r.id) AS total_shots,
               (SELECT MAX(hole_num) FROM shots WHERE round_id = r.id) AS holes_played
        FROM rounds r
    """
    params = ()
    if course_name:
        sql += " WHERE r.course_name = ?"
        params = (course_name,)
    sql += " ORDER BY r.start_time DESC"
    with get_db() as conn:
        return conn.execute(sql, params).fetchall()


def get_round(round_id):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM rounds WHERE id = ?", (round_id,)).fetchone()
        return dict(row) if row else None


def get_shots(round_id):
    with get_db() as conn:
        rows = conn.execute(
            """SELECT hole_num, shot_num, lat, lon, time
               FROM shots WHERE round_id = ?
               ORDER BY id""",
            (round_id,),
        ).fetchall()
        return [dict(r) for r in rows]


def get_track(round_id):
    with get_db() as conn:
        rows = conn.execute(
            """SELECT time, lat, lon, hr FROM track_points
               WHERE round_id = ? ORDER BY id""",
            (round_id,),
        ).fetchall()
        return [dict(r) for r in rows]


def get_hole_summary(round_id):
    """Per-hole summary. Uses the holes table (strokes + par from FIT laps).
    """
    with get_db() as conn:
        # Counts per hole derived from shots
        shot_counts = {
            r["hole_num"]: r["c"]
            for r in conn.execute(
                """SELECT hole_num, COUNT(*) AS c FROM shots
                   WHERE round_id = ? GROUP BY hole_num""",
                (round_id,),
            ).fetchall()
        }
        hole_rows = {
            r["hole_num"]: dict(r)
            for r in conn.execute(
                """SELECT hole_num, strokes, par, time_seconds FROM holes
                   WHERE round_id = ?""",
                (round_id,),
            ).fetchall()
        }

        all_hole_nums = sorted(set(shot_counts) | set(hole_rows))
        out = []
        for hn in all_hole_nums:
            lap = hole_rows.get(hn, {})
            strokes = lap.get("strokes") if lap.get("strokes") is not None else shot_counts.get(hn)
            par = lap.get("par")
            out.append({
                "hole_num": hn,
                "strokes": strokes,
                "par": par,
                "to_par": (strokes - par) if (strokes is not None and par is not None) else None,
                "time_seconds": lap.get("time_seconds"),
            })
        return out


def delete_round(round_id):
    with get_db() as conn:
        conn.execute("DELETE FROM rounds WHERE id = ?", (round_id,))
        conn.commit()


# ---------------------------------------------------------------------------
# Cross-round analysis (shot heatmap by hole)
# ---------------------------------------------------------------------------

def list_courses():
    """Distinct course names that have at least one round, alphabetical."""
    with get_db() as conn:
        rows = conn.execute("""
            SELECT DISTINCT course_name FROM rounds
            WHERE course_name IS NOT NULL AND course_name != ''
            ORDER BY course_name
        """).fetchall()
        return [r["course_name"] for r in rows]


def get_course_holes(course_name):
    """Holes that have shots for a given course, with how many rounds and
    shots were recorded on each. Used to build the hole picker.
    """
    with get_db() as conn:
        rows = conn.execute(
            """SELECT s.hole_num                         AS hole_num,
                      COUNT(DISTINCT s.round_id)         AS rounds,
                      COUNT(*)                           AS shots,
                      (SELECT h.par FROM holes h
                         JOIN rounds r2 ON r2.id = h.round_id
                        WHERE r2.course_name = ? AND h.hole_num = s.hole_num
                          AND h.par IS NOT NULL
                        LIMIT 1)                         AS par
                 FROM shots s
                 JOIN rounds r ON r.id = s.round_id
                WHERE r.course_name = ?
                GROUP BY s.hole_num
                ORDER BY s.hole_num""",
            (course_name, course_name),
        ).fetchall()
        return [dict(r) for r in rows]


def get_hole_shots_across_rounds(course_name, hole_num):
    """Every shot ever recorded on one hole of one course, across all rounds.
    Ordered by round then shot number so the frontend can group them.
    """
    with get_db() as conn:
        rows = conn.execute(
            """SELECT s.round_id   AS round_id,
                      r.start_time AS start_time,
                      s.shot_num   AS shot_num,
                      s.lat        AS lat,
                      s.lon        AS lon,
                      s.time       AS time
                 FROM shots s
                 JOIN rounds r ON r.id = s.round_id
                WHERE r.course_name = ? AND s.hole_num = ?
                ORDER BY r.start_time, s.round_id, s.shot_num""",
            (course_name, hole_num),
        ).fetchall()
        return [dict(r) for r in rows]


def get_hole_scores_across_rounds(course_name, hole_num):
    """Per-round score info for one hole across all rounds of a course.
    Prefers the authoritative strokes from the holes table (FIT laps);
    falls back to the shot count for that round/hole when strokes is missing.
    Returns list of {round_id, strokes, par}.
    """
    with get_db() as conn:
        shot_counts = {
            r["round_id"]: r["c"]
            for r in conn.execute(
                """SELECT s.round_id AS round_id, COUNT(*) AS c
                     FROM shots s
                     JOIN rounds r ON r.id = s.round_id
                    WHERE r.course_name = ? AND s.hole_num = ?
                    GROUP BY s.round_id""",
                (course_name, hole_num),
            ).fetchall()
        }
        hole_rows = {
            r["round_id"]: dict(r)
            for r in conn.execute(
                """SELECT h.round_id AS round_id, h.strokes AS strokes, h.par AS par
                     FROM holes h
                     JOIN rounds r ON r.id = h.round_id
                    WHERE r.course_name = ? AND h.hole_num = ?""",
                (course_name, hole_num),
            ).fetchall()
        }
        out = []
        for rid in sorted(set(shot_counts) | set(hole_rows)):
            lap = hole_rows.get(rid, {})
            strokes = lap.get("strokes")
            if strokes is None:
                strokes = shot_counts.get(rid)
            out.append({
                "round_id": rid,
                "strokes": strokes,
                "par": lap.get("par"),
            })
        return out
