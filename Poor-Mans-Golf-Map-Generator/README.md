# OSM to Connect IQ Golf Course Converter

## Quick Start

### Step 1: Export course data from OpenStreetMap

1. Go to https://overpass-turbo.eu
2. Paste this query (Make sure you are above your course on owerpass-turbo when you run the script):

```
[out:json][timeout:60];
(
  way["leisure"="golf_course"](around:2000,56.1645,15.7349);
  relation["leisure"="golf_course"](around:2000,56.1645,15.7349);
);
map_to_area -> .course;
(
  way["golf"](area.course);
  node["golf"](area.course);
  way["golf"](around:2000,56.1645,15.7349);
  node["golf"](around:2000,56.1645,15.7349);
  way["leisure"="golf_course"](around:2000,56.1645,15.7349);
  relation["leisure"="golf_course"](around:2000,56.1645,15.7349);
);
out geom;
```

3. Click **Run**
4. Click **Export** → **download/copy as raw OSM data** (choose JSON format)
5. Save as `<your_course>.json`

#### If your course do not exist. go to https://www.openstreetmap.org. Here you can create the course yourself. Please create it on OpenStreetMap so future users can access the course data as well.

### Step 2: Convert to Connect IQ format

```
python osm_to_connectiq.py trummenas.json
```

This produces the file:
- `<your_course>.json` — Full detail, human-readable (for debugging)

### Step 3: Use in your Connect IQ project

Copy the JSON into your project's `resources/` folder and load it
in your Monkey C app. See the watch app code (coming next) for details.

## For Other Courses

Change the coordinates in the Overpass query to any other course:
- Replace `56.1645,15.7349` with the latitude,longitude of the course
- The course must be mapped in OpenStreetMap with golf=hole ways

## Output Format

### Full JSON structure:
```json
{
  "name": "Course Name",
  "center": [lat, lon],
  "par": 72,
  "holes": [
    {
      "num": 1,
      "par": 4,
      "hcp": 10,
      "dist": 305,
      "tee": [lat, lon],
      "pin": [lat, lon],
      "path": [[lat, lon], ...],
      "green": [[lat, lon], ...],
      "fairways": [[[lat, lon], ...], ...],
      "bunkers": [[lat, lon], ...],
      "water": [[[lat, lon], ...], ...]
    }
  ]
}
```

### Compact format (for watch):
Same structure but with shortened keys and integer coordinates (lat/lon × 100000).
