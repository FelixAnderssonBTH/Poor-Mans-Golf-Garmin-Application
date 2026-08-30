import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// The free play screen: no map, because there is no course geometry. Shows the
// hole number, a par picker before the first shot, and the stroke count.
//
// This page owns the par picker state, since it is the only thing that draws
// it. HoleView forwards the delegate's calls through to here.

class FreePlayPage extends HolePage {
    hidden var _model;

    // Par options offered in free play
    var parOptions = [5, 4, 3];
    var parIndex = 1;   // default par 4

    // True when the player re-opened the par picker mid-hole (long press BACK)
    var editingPar = false;

    function initialize(golfModel) {
        HolePage.initialize();
        _model = golfModel;
    }

    // --- Par picker helpers ---

    function nextPar() as Void {
        parIndex = (parIndex + 1) % parOptions.size();
        WatchUi.requestUpdate();
    }

    function prevPar() as Void {
        parIndex = (parIndex - 1 + parOptions.size()) % parOptions.size();
        WatchUi.requestUpdate();
    }

    function confirmPar() as Void {
        _model.setCurrentHolePar(parOptions[parIndex]);
        editingPar = false;
        parIndex = 1;   // reset default for the next hole
    }

    // Long press BACK on a hole that already has a par: re-open the picker
    function openParEdit() as Void {
        var current = _model.courseData.holes[_model.currentHole]["par"];
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
        return _model.needsParSelection() || editingPar;
    }

    function draw(dc as Graphics.Dc, model as GolfModel) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var hole = model.courseData.holes[model.currentHole];

        dc.setColor(0x1A3A1A, 0x1A3A1A);
        dc.clear();

        // Hole number, par, score, total and GPS status are drawn by HoleView
        // as shared chrome around every page -- do not repeat them here.

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

            // Stroke count, big
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 30, Graphics.FONT_NUMBER_MEDIUM,
                strokes.toString(), Graphics.TEXT_JUSTIFY_CENTER);

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
