-- Golf Round Archive schema
-- One round = one extracted FIT activity JSON

CREATE TABLE IF NOT EXISTS rounds (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    course_name  TEXT,
    start_time   TEXT NOT NULL,
    time_seconds REAL,
    distance_m   REAL,
    calories     INTEGER,
    sport        TEXT,
    notes        TEXT,
    imported_at  TEXT DEFAULT (datetime('now'))
);


CREATE TABLE IF NOT EXISTS holes (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id     INTEGER NOT NULL,
    hole_num     INTEGER NOT NULL,
    strokes      INTEGER,
    par          INTEGER,
    time_seconds REAL,
    FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS shots (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id   INTEGER NOT NULL,
    hole_num   INTEGER NOT NULL,
    shot_num   INTEGER NOT NULL,
    lat        REAL NOT NULL,
    lon        REAL NOT NULL,
    time       TEXT NOT NULL,
    FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS track_points (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id  INTEGER NOT NULL,
    time      TEXT NOT NULL,
    lat       REAL NOT NULL,
    lon       REAL NOT NULL,
    hr        INTEGER,
    FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_shots_round ON shots(round_id);
CREATE INDEX IF NOT EXISTS idx_holes_round ON holes(round_id);
CREATE INDEX IF NOT EXISTS idx_track_round ON track_points(round_id);
