import Toybox.Lang;
import Toybox.Position;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Application.Storage;
import Toybox.Attention;

class GolfModel {
    var courseData;
    var currentHole = 0;

    var scores;

    // Shot positions: where the player stood when they hit each shot
    // shotPositions[hole] = [[lat,lon], [lat,lon], ...]
    var shotPositions;
    var playerLat = 0;
    var playerLon = 0;
    var gpsActive = false;
    var distToPin = -1.0;

    // Activity recording
    var session;

    // FIT fields for per-hole score in activity file
    var holeScoreField;
    var holeNumField;
    // FIT record fields for shot positions (logged every second, updated on stroke)
    var shotLatField;
    var shotLonField;
    var shotNumField;

    var roundFinished = false;

    function initialize(course as CourseData) {
        courseData = course;
        scores = new [course.numHoles];
        shotPositions = new [course.numHoles];
        for (var i = 0; i < course.numHoles; i++) {
            scores[i] = 0;
            shotPositions[i] = [];
        }
    }

    function startRecording() as Void {
        if (session == null) {
            session = ActivityRecording.createSession({
                :name => "Golf",
                :sport => ActivityRecording.SPORT_GOLF,
                :subSport => ActivityRecording.SUB_SPORT_GENERIC
            });

            // Per-lap fields (written when saving)
            holeScoreField = session.createField(
                "hole_score",
                0,
                FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "strokes"}
            );
            holeNumField = session.createField(
                "hole_num",
                1,
                FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_LAP}
            );

            // Per-record fields (updated on each stroke, logged every second)
            shotLatField = session.createField(
                "shot_lat",
                2,
                FitContributor.DATA_TYPE_SINT32,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "deg*1e5"}
            );
            shotLonField = session.createField(
                "shot_lon",
                3,
                FitContributor.DATA_TYPE_SINT32,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "deg*1e5"}
            );
            shotNumField = session.createField(
                "shot_num",
                4,
                FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_RECORD}
            );

            // Initialize to 0
            shotLatField.setData(0);
            shotLonField.setData(0);
            shotNumField.setData(0);

            session.start();
        }
    }

    function saveAndStop() as Void {
        if (session != null && session.isRecording()) {
            // Write all hole scores as FIT laps at the end
            if (holeScoreField != null && holeNumField != null) {
                for (var i = 0; i < courseData.numHoles; i++) {
                    if (scores[i] > 0) {
                        var hole = courseData.holes[i];
                        holeNumField.setData(hole["num"]);
                        holeScoreField.setData(scores[i]);
                        session.addLap();
                    }
                }
            }
            session.stop();
            session.save();
            session = null;
        }
        _saveShotData();
    }

    function startGps() as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition) as Method(info as Position.Info) as Void);
        gpsActive = true;
    }

    function stopGps() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        gpsActive = false;
    }

    function onPosition(info as Position.Info) as Void {
        if (info.position != null) {
            var degrees = info.position.toDegrees();
            playerLat = (degrees[0] * 100000).toNumber();
            playerLon = (degrees[1] * 100000).toNumber();

            var hole = courseData.holes[currentHole];
            distToPin = _calcDistance(playerLat, playerLon, hole["pin"][0], hole["pin"][1]);

            WatchUi.requestUpdate();
        }
    }

    // Add a stroke: record where the player is standing
    function addStroke() as Void {
        scores[currentHole] = scores[currentHole] + 1;

        // Save current GPS position as shot location
        if (playerLat != 0 && playerLon != 0) {
            var shots = shotPositions[currentHole] as Array;
            var newShots = new [shots.size() + 1];
            for (var i = 0; i < shots.size(); i++) {
                newShots[i] = shots[i];
            }
            newShots[shots.size()] = [playerLat, playerLon];
            shotPositions[currentHole] = newShots;

            // Write shot position to FIT record fields
            if (shotLatField != null) {
                shotLatField.setData(playerLat);
                shotLonField.setData(playerLon);
                shotNumField.setData(scores[currentHole]);
            }
        }

        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }

        WatchUi.requestUpdate();
    }

    // Remove last stroke and its shot position
    function removeStroke() as Void {
        if (scores[currentHole] > 0) {
            scores[currentHole] = scores[currentHole] - 1;

            var shots = shotPositions[currentHole] as Array;
            if (shots.size() > 0) {
                var newShots = new [shots.size() - 1];
                for (var i = 0; i < newShots.size(); i++) {
                    newShots[i] = shots[i];
                }
                shotPositions[currentHole] = newShots;
            }

            WatchUi.requestUpdate();
        }
    }

    // Get ball landing positions for rendering on the map
    // Ball 1 lands where shot 2 was taken from, ball 2 lands where shot 3 was taken from and so on
    function getBallPositions(holeIdx, holeFinished) as Array {
        var shots = shotPositions[holeIdx] as Array;
        if (shots.size() < 2 && !holeFinished) {
            return [];
        }

        var numBalls;
        if (holeFinished) {
            numBalls = shots.size();
        } else {
            numBalls = shots.size() - 1;
        }

        var balls = new [numBalls];
        var hole = courseData.holes[holeIdx];

        for (var i = 0; i < numBalls; i++) {
            if (i < shots.size() - 1) {
                balls[i] = shots[i + 1];
            } else {
                // Last ball landed at the pin
                balls[i] = [hole["pin"][0], hole["pin"][1]];
            }
        }

        return balls;
    }

    function nextHole() as Void {
        if (currentHole < courseData.numHoles - 1) {
            currentHole = currentHole + 1;
        } else {
            roundFinished = true;
        }
        if (playerLat != 0) {
            var hole = courseData.holes[currentHole];
            distToPin = _calcDistance(playerLat, playerLon, hole["pin"][0], hole["pin"][1]);
        }
        WatchUi.requestUpdate();
    }

    function prevHole() as Void {
        if (roundFinished) {
            roundFinished = false;
        } else if (currentHole > 0) {
            currentHole = currentHole - 1;
        }
        if (playerLat != 0) {
            var hole = courseData.holes[currentHole];
            distToPin = _calcDistance(playerLat, playerLon, hole["pin"][0], hole["pin"][1]);
        }
        WatchUi.requestUpdate();
    }

    // Before first shot:tee-to-pin, after first shot: player-to-pin 
    function getDisplayDistance() {
        var hole = courseData.holes[currentHole];
        if (scores[currentHole] > 0 && playerLat != 0) {
            return distToPin;
        }
        return hole["dist"].toFloat();
    }

    // Score relative to par
    function holeScoreToPar(idx) {
        if (scores[idx] == 0) {
            return 0;
        }
        return scores[idx] - courseData.holes[idx]["par"];
    }

    // Total score relative to par for all played holes
    function totalToPar() {
        var total = 0;
        for (var i = 0; i < courseData.numHoles; i++) {
            if (scores[i] > 0) {
                total += holeScoreToPar(i);
            }
        }
        return total;
    }

    // Total strokes
    function totalStrokes() {
        var total = 0;
        for (var i = 0; i < courseData.numHoles; i++) {
            total += scores[i];
        }
        return total;
    }

    // Save all shot data to persistent storage
    hidden function _saveShotData() as Void {
        var roundData = new [courseData.numHoles];
        for (var i = 0; i < courseData.numHoles; i++) {
            var hole = courseData.holes[i];
            var holeFinished = (scores[i] > 0);
            roundData[i] = {
                "hole" => hole["num"],
                "par" => hole["par"],
                "strokes" => scores[i],
                "shots" => shotPositions[i],
                "balls" => getBallPositions(i, holeFinished)
            };
        }

        Storage.setValue("lastRound", roundData);
        Storage.setValue("lastCourse", courseData.name);
        Storage.setValue("lastTotal", totalStrokes());
        Storage.setValue("lastPar", courseData.par);
    }

    // Find the highest hole index that has strokes
    function _getLastPlayedHole() {
        var last = 0;
        for (var i = 0; i < courseData.numHoles; i++) {
            if (scores[i] > 0) {
                last = i;
            }
        }
        return last;
    }

    hidden function _calcDistance(lat1, lon1, lat2, lon2) {
        var la1 = lat1.toFloat() / 100000.0;
        var lo1 = lon1.toFloat() / 100000.0;
        var la2 = lat2.toFloat() / 100000.0;
        var lo2 = lon2.toFloat() / 100000.0;

        var dLat = (la2 - la1) * Math.PI / 180.0;
        var dLon = (lo2 - lo1) * Math.PI / 180.0;
        var avgLat = (la1 + la2) / 2.0 * Math.PI / 180.0;

        var dx = dLon * Math.cos(avgLat) * 6371000.0;
        var dy = dLat * 6371000.0;

        return Math.sqrt(dx * dx + dy * dy);
    }
}
