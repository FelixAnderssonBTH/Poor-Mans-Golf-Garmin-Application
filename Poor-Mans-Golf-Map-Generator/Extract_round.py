#!/usr/bin/env python3
"""
Extract golf round data from a Garmin FIT file.

Usage:
    pip install fitparse
    python extract_round.py <activity.fit> [output.json]

Extracts:
    - Per-hole scores from lap data
    - Shot positions from record data
    - GPS track points
    - Total time, distance, calories
"""

import sys
import json

try:
    from fitparse import FitFile
except ImportError:
    print("Install fitparse first: pip install fitparse")
    sys.exit(1)


def extract_round(fit_path):
    fitfile = FitFile(fit_path)

    round_data = {
        "activity": {},
        "holes": [],
        "shots": [],
        "track": []
    }

    # Extract session (summary) data
    for record in fitfile.get_messages("session"):
        for field in record.fields:
            if field.name == "total_elapsed_time":
                round_data["activity"]["time_seconds"] = field.value
            elif field.name == "total_distance":
                round_data["activity"]["distance_m"] = field.value
            elif field.name == "total_calories":
                round_data["activity"]["calories"] = field.value
            elif field.name == "sport":
                round_data["activity"]["sport"] = field.value
            elif field.name == "start_time":
                round_data["activity"]["start_time"] = str(field.value)

    # Extract laps (one per hole)
    for record in fitfile.get_messages("lap"):
        hole = {}
        for field in record.fields:
            if field.name == "hole_num" and field.value is not None:
                hole["hole"] = field.value
            elif field.name == "hole_score" and field.value is not None:
                hole["strokes"] = field.value
            elif field.name == "total_elapsed_time":
                hole["time_seconds"] = field.value

        if "hole" in hole or "strokes" in hole:
            round_data["holes"].append(hole)

    # Extract records for shot positions and GPS track
    last_shot_num = 0
    for record in fitfile.get_messages("record"):
        point = {}
        shot_lat = None
        shot_lon = None
        shot_num = None

        for field in record.fields:
            if field.name == "position_lat" and field.value is not None:
                point["lat"] = round(field.value * (180.0 / 2**31), 6)
            elif field.name == "position_long" and field.value is not None:
                point["lon"] = round(field.value * (180.0 / 2**31), 6)
            elif field.name == "timestamp":
                point["time"] = str(field.value)
            elif field.name == "heart_rate" and field.value is not None:
                point["hr"] = field.value
            elif field.name == "shot_lat" and field.value is not None and field.value != 0:
                shot_lat = field.value
            elif field.name == "shot_lon" and field.value is not None and field.value != 0:
                shot_lon = field.value
            elif field.name == "shot_num" and field.value is not None:
                shot_num = field.value

        # Track point
        if "lat" in point and "lon" in point:
            round_data["track"].append(point)

        # New shot detected (shot_num changed)
        if shot_num is not None and shot_num != last_shot_num and shot_num > 0:
            if shot_lat is not None and shot_lon is not None:
                round_data["shots"].append({
                    "shot_num": shot_num,
                    "lat": shot_lat / 100000.0,
                    "lon": shot_lon / 100000.0,
                    "time": point.get("time", "")
                })
            last_shot_num = shot_num

    return round_data


def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_round.py <activity.fit> [output.json]")
        sys.exit(1)

    fit_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else fit_path.replace(".fit", "_round.json")

    print(f"Reading: {fit_path}")
    data = extract_round(fit_path)

    print(f"\nRound Summary:")
    act = data["activity"]
    if "start_time" in act:
        print(f"  Start: {act['start_time']}")
    if "time_seconds" in act:
        minutes = int(act["time_seconds"] // 60)
        print(f"  Duration: {minutes} min")
    if "calories" in act:
        print(f"  Calories: {act['calories']}")

    print(f"\nHoles: {len(data['holes'])}")
    total_strokes = 0
    for h in data["holes"]:
        num = h.get("hole", "?")
        strokes = h.get("strokes", "?")
        if isinstance(strokes, int):
            total_strokes += strokes
        print(f"  Hole {num:>2}: {strokes} strokes")
    print(f"  Total: {total_strokes} strokes")

    print(f"\nShots recorded: {len(data['shots'])}")
    for s in data["shots"]:
        print(f"  Shot {s['shot_num']}: ({s['lat']:.5f}, {s['lon']:.5f}) {s['time']}")

    print(f"\nTrack points: {len(data['track'])}")

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"\nSaved: {out_path}")


if __name__ == "__main__":
    main()