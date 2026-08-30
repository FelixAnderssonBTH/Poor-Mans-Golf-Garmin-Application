import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.Math;

// Owns the round's screen: the view lifecycle, the update timer, the GPS
// lifecycle, and a small carousel of HolePage objects. It draws the shared
// chrome -- hole number and par, hole score, running total, GPS status and the
// page indicator -- around whatever the active page renders.
//
// Course play pages left to right: map, green distances.
// Free play has a single page, so horizontal swipes are a natural no-op.

class HoleView extends WatchUi.View {
    var model;
    var renderer;
    var updateTimer;

    // Where Discard returns to. Held here rather than in the delegates because
    // the switch has to happen from onShow() -- see the note there.
    var pickerView as CoursePickerView;
    var pickerDelegate as CoursePickerDelegate;

    var freePlayPage;

    hidden var _pages;
    hidden var _pageIndex = 0;

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
        freePlayPage = new FreePlayPage(model);

        // Free play has no course geometry, so the green page would have
        // nothing to show. A one-element array makes paging a no-op there
        // without special-casing the input path.
        if (model.isFreePlay()) {
            _pages = [freePlayPage];
        } else {
            _pages = [new MapPage(renderer), new GreenPage()];
        }
        _pageIndex = 0;
    }

    // --- Page navigation, called by GolfDelegate ---

    function nextPage() as Void {
        _pageIndex = (_pageIndex + 1) % _pages.size();
        WatchUi.requestUpdate();
    }

    function prevPage() as Void {
        _pageIndex = (_pageIndex - 1 + _pages.size()) % _pages.size();
        WatchUi.requestUpdate();
    }

    // A new hole means standing on a new tee, where the map is the orienting
    // view -- so hole changes always land back on it.
    function resetPage() as Void {
        _pageIndex = 0;
        WatchUi.requestUpdate();
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

        _pages[_pageIndex].draw(dc, model);
        _drawChrome(dc);
    }

    // Drawn over every page, so a stroke registered from any screen is visibly
    // acknowledged. That matters: a player who presses START and sees nothing
    // move will press again, and two strokes within a second is a known way to
    // lose one from the FIT file.
    hidden function _drawChrome(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var hole = model.courseData.holes[model.currentHole];

        // Hole number and par, top
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 24, Graphics.FONT_SMALL,
            "Hole " + hole["num"] + "  Par " + hole["par"], Graphics.TEXT_JUSTIFY_CENTER);

        // Score for this hole, mid-left -- only once the hole has been started
        var strokes = model.scores[model.currentHole];
        if (strokes > 0) {
            var scoreInfo = diffToText(strokes - hole["par"]);
            dc.setColor(scoreInfo[1], Graphics.COLOR_TRANSPARENT);
            dc.drawText(28, h / 2 - 12, Graphics.FONT_MEDIUM,
                scoreInfo[0], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Running total, mid-right
        var totalInfo = diffToText(model.totalToPar());
        dc.setColor(totalInfo[1], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 25, h / 2 - 12, Graphics.FONT_MEDIUM,
            totalInfo[0], Graphics.TEXT_JUSTIFY_CENTER);

        // GPS status is drawn by the pages, not here: the map wants it centred,
        // free play wants it at the bottom, and the green page says it already
        // by showing dashes instead of distances.

        _drawPageDots(dc, w, h);
    }

    // One dot per page, active one filled. Suppressed entirely when there is
    // only one page, where a lone dot would mean nothing.
    //
    // Laid out along the bezel rather than in a straight row: the screen is
    // round, so an arc follows its edge and stays clear of the map's centred
    // distance readout. Centred on 4 o'clock, which is empty on every page.
    hidden function _drawPageDots(dc as Graphics.Dc, w, h) as Void {
        var count = _pages.size();
        if (count < 2) { return; }

        var cx = w / 2;
        var cy = h / 2;
        var radius = cx - 16;               // just inside the bezel

        // Screen angles: 0 is 3 o'clock, positive runs clockwise because y
        // grows downward. 30 degrees is 4 o'clock; 42 sits a little lower,
        // further round the bezel and well clear of the distance readout.
        var baseDeg = 42.0;
        var stepDeg = 5.0;

        for (var i = 0; i < count; i++) {
            var deg = baseDeg + (i - (count - 1) / 2.0) * stepDeg;
            var rad = deg * Math.PI / 180.0;
            var x = cx + radius * Math.cos(rad);
            var y = cy + radius * Math.sin(rad);

            if (i == _pageIndex) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 3);
            } else {
                dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, 3);
            }
        }
    }
}
