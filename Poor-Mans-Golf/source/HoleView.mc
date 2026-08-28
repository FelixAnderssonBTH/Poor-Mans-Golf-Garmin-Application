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
    var mapPage;
    var updateTimer;

    // Where Discard returns to. Held here rather than in the delegates because
    // the switch has to happen from onShow() -- see the note there.
    var pickerView as CoursePickerView;
    var pickerDelegate as CoursePickerDelegate;

    var freePlayPage;

    function initialize(golfModel as GolfModel, pView as CoursePickerView,
                        pDelegate as CoursePickerDelegate) {
        View.initialize();
        model = golfModel;
        pickerView = pView;
        pickerDelegate = pDelegate;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        // renderer does not exist until here, so the page that needs it is
        // built here too rather than in initialize().
        renderer = new HoleRenderer(dc.getWidth(), dc.getHeight());
        mapPage = new MapPage(renderer);
        freePlayPage = new FreePlayPage(model);
    }

    function onShow() as Void {
        // The round was discarded from the confirmation dialog. That dialog is
        // popped by the system *after* onResponse() returns, so a switchToView()
        // in onResponse gets thrown away with it -- Garmin's ConfirmationDialog
        // sample sets state there and lets the revealed view act, which is this.
        // Returning early also matters: the GPS restart below would otherwise
        // undo the stopGps() that discardAndStop() just did.
        if (model.roundDiscarded) {
            WatchUi.switchToView(pickerView, pickerDelegate, WatchUi.SLIDE_IMMEDIATE);
            return;
        }

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

    // --- Par picker forwarders (free play only) ---
    // The state lives on FreePlayPage, which is the only thing that draws it.
    // These keep GolfDelegate talking to the view rather than reaching through it.

    function nextPar() as Void { freePlayPage.nextPar(); }

    function prevPar() as Void { freePlayPage.prevPar(); }

    function confirmPar() as Void { freePlayPage.confirmPar(); }

    function openParEdit() as Void { freePlayPage.openParEdit(); }

    function cancelParEdit() as Void { freePlayPage.cancelParEdit(); }

    function parPickerActive() as Boolean { return freePlayPage.parPickerActive(); }

    // A field read cannot be forwarded, so the delegate calls this instead
    function isEditingPar() as Boolean { return freePlayPage.editingPar; }

    // Turns a score-vs-par diff into [text, color], shared by hole score and total score
    hidden function _diffToText(diff) {
        return diffToText(diff);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // Discarding: this view is briefly top-of-stack before onShow() switches
        // away, so it gets one paint. Fill it with the course picker's own
        // background instead of the hole, so that frame blends into where we are
        // heading rather than flashing the round the player just abandoned.
        if (model.roundDiscarded) {
            dc.setColor(0x222222, 0x222222);
            dc.clear();
            return;
        }

        if (model.isFreePlay()) {
            freePlayPage.draw(dc, model);
            return;
        }

        mapPage.draw(dc, model);

        // Score chrome below is shared by every page, so it stays in the view
        // rather than moving into MapPage.
        var hole = model.courseData.holes[model.currentHole];

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
}
