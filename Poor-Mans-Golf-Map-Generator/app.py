"""Golf Round Archive — Flask app.

Run:
    pip install -r requirements.txt
    python app.py

Then open http://127.0.0.1:5000
"""

import json
from flask import Flask, render_template, request, jsonify, redirect, url_for, abort, flash

import db

app = Flask(__name__)
app.secret_key = "change-me-if-you-care"  # only used for flash messages

# Ensure the DB exists before the first request
db.init_db()


@app.route("/")
def index():
    rounds = db.list_rounds()
    return render_template("index.html", rounds=rounds)


@app.route("/upload", methods=["POST"])
def upload():
    file = request.files.get("file")
    course_name = (request.form.get("course_name") or "").strip() or None
    notes = (request.form.get("notes") or "").strip() or None

    if not file or not file.filename:
        flash("No file selected", "error")
        return redirect(url_for("index"))

    try:
        data = json.load(file.stream)
    except json.JSONDecodeError as e:
        flash(f"Could not parse JSON: {e}", "error")
        return redirect(url_for("index"))

    try:
        round_id = db.import_round(data, course_name=course_name, notes=notes)
    except Exception as e:
        flash(f"Import failed: {e}", "error")
        return redirect(url_for("index"))

    flash(f"Round imported (id {round_id})", "ok")
    return redirect(url_for("view_round", round_id=round_id))


@app.route("/round/<int:round_id>")
def view_round(round_id):
    rnd = db.get_round(round_id)
    if rnd is None:
        abort(404)
    holes = db.get_hole_summary(round_id)
    return render_template("round.html", rnd=rnd, holes=holes)


@app.route("/round/<int:round_id>/data")
def round_data(round_id):
    """JSON payload consumed by the map view."""
    rnd = db.get_round(round_id)
    if rnd is None:
        abort(404)
    return jsonify({
        "round": rnd,
        "shots": db.get_shots(round_id),
        "track": db.get_track(round_id),
        "holes": db.get_hole_summary(round_id),
    })


@app.route("/round/<int:round_id>/delete", methods=["POST"])
def delete_round(round_id):
    db.delete_round(round_id)
    flash("Round deleted", "ok")
    return redirect(url_for("index"))


# Convenience filters for templates
@app.template_filter("duration")
def fmt_duration(seconds):
    if seconds is None:
        return "—"
    s = int(seconds)
    h, rem = divmod(s, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


@app.template_filter("km")
def fmt_km(meters):
    if meters is None:
        return "—"
    return f"{meters / 1000:.2f} km"


if __name__ == "__main__":
    app.run(debug=True)
