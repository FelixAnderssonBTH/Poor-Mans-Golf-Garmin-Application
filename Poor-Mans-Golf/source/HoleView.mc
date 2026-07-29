import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;

// Renders the hole map via HoleRenderer, overlays score relative to par, and shows GPS status.
// In free play (no pre-defined course) there is no map: it shows the hole number, a par
// picker before the first shot, and the stroke count.

class HoleView extends WatchUi.View {
    var model;
    var renderer;
    var updateTimer;

    // Par options offered in free play
    var parOptions = [5, 4, 3];
    var parIndex = 1;   // default par 4

    // True when the player re-opened the par picker mid-hole (long press BACK)
    var editingPar = false;

    function initialize(golfModel as GolfModel) {
        View.initialize();
        model = golfModel;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        renderer = new HoleRenderer(dc.getWidth(), dc.getHeight());
    }

    function onShow() as Void {
        // Ensure GPS is running when view is shown
        if (!model.gpsActive) {
            model.startGps();
        }
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:onTimer) as Method() as Void, 2000, true);

    }

    function onHide() as Void {
        if (updateTimer != null) {
            updateTimer.stop();
        }
    }

    function onTimer() as Void {
        WatchUi.requestUpdate();
    }

    // --- Par picker helpers (free play only) ---

    function nextPar() as Void {
        parIndex = (parIndex + 1) % parOptions.size();
        WatchUi.requestUpdate();
    }

    function prevPar() as Void {
        parIndex = (parIndex - 1 + parOptions.size()) % parOptions.size();
        WatchUi.requestUpdate();
    }

    function confirmPar() as Void {
        model.setCurrentHolePar(parOptions[parIndex]);
        editingPar = false;
        parIndex = 1;   // reset default for the next hole
    }

    // Long press BACK on a hole that already has a par: re-open the picker
    function openParEdit() as Void {
        var current = model.courseData.holes[model.currentHole]["par"];
        parIndex = 1;
        for (var i = 0; i < parOptions.size(); i++) {
            if (parOptions[i] == current) {
                parIndex = i;
            }
        }
        editingPar = true;
        WatchUi.requestUpdate();
    }

    function cancelParEdit() as Void {
        editingPar = false;
        parIndex = 1;
        WatchUi.requestUpdate();
    }

    // The par picker is shown either before the first shot, or when re-editing
    function parPickerActive() as Boolean {
        return model.needsParSelection() || editingPar;
    }

    // Turns a score-vs-par diff into [text, color], shared by hole score and total score
    hidden function _diffToText(diff) {
        if (diff < 0) {
            return [diff.toString(), 0x44BBFF];
        } else if (diff == 0) {
            return ["E", 0xFFFFFF];
        } else {
            return ["+" + diff, 0xFF6644];
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (model.isFreePlay()) {
            _drawFreePlay(dc);
            return;
        }

        var hole = model.courseData.holes[model.currentHole];
        var holeIsFinished = (model.scores[model.currentHole] > 0 && model.currentHole < model._getLastPlayedHole());
        var balls = model.getBallPositions(model.currentHole, holeIsFinished);
        var displayDist = model.getDisplayDistance();

        renderer.draw(dc, hole, model.playerLat, model.playerLon, displayDist, balls);

        // Only show score if hole has been started
        var strokes = model.scores[model.currentHole];
        if (strokes > 0) {
            var par = hole["par"];
            var diff = strokes - par;
            var scoreInfo = _diffToText(diff);

            dc.setColor(scoreInfo[1], Graphics.COLOR_TRANSPARENT);
            dc.drawText(28, dc.getHeight() / 2 - 12, Graphics.FONT_MEDIUM,
                scoreInfo[0], Graphics.TEXT_JUSTIFY_CENTER);
        }

        var totalDiff = model.totalToPar();
        var totalInfo = _diffToText(totalDiff);

        dc.setColor(totalInfo[1], Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() - 25, dc.getHeight() / 2 - 12, Graphics.FONT_MEDIUM,
            totalInfo[0], Graphics.TEXT_JUSTIFY_CENTER);

        // Draw GPS status
        if (!model.gpsActive || model.playerLat == 0) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_TINY,
                "Waiting for GPS...", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Free play screen: no map, just hole number, par and strokes
    hidden function _drawFreePlay(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var hole = model.courseData.holes[model.currentHole];

        dc.setColor(0x1A3A1A, 0x1A3A1A);
        dc.clear();

        // Hole number at the top
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 24, Graphics.FONT_SMALL,
            "Hole " + hole["num"], Graphics.TEXT_JUSTIFY_CENTER);

        if (parPickerActive()) {
            // Par picker: before the first shot, or re-opened with a long press on BACK
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 50, Graphics.FONT_TINY,
                editingPar ? "Change par" : "Select par", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 22, Graphics.FONT_NUMBER_MEDIUM,
                parOptions[parIndex].toString(), Graphics.TEXT_JUSTIFY_CENTER);

            
        } else {
            var strokes = model.scores[model.currentHole];

            // Par for this hole
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 55, Graphics.FONT_TINY,
                "Par " + hole["par"], Graphics.TEXT_JUSTIFY_CENTER);

            // Stroke count, big
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 30, Graphics.FONT_NUMBER_MEDIUM,
                strokes.toString(), Graphics.TEXT_JUSTIFY_CENTER);

            // Score for this hole
            if (strokes > 0) {
                var scoreInfo = _diffToText(strokes - hole["par"]);
                dc.setColor(scoreInfo[1], Graphics.COLOR_TRANSPARENT);
                dc.drawText(36, h / 2 - 12, Graphics.FONT_MEDIUM,
                    scoreInfo[0], Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Running total for the round
            var totalInfo = _diffToText(model.totalToPar());
            dc.setColor(totalInfo[1], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 36, h / 2 - 12, Graphics.FONT_MEDIUM,
                totalInfo[0], Graphics.TEXT_JUSTIFY_CENTER);

            // GPS status at the bottom
            if (!model.gpsActive || model.playerLat == 0) {
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h - 60, Graphics.FONT_TINY,
                    "Waiting for GPS...", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0x66CC66, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h - 45, Graphics.FONT_TINY,
                    "GPS ok", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }
}
