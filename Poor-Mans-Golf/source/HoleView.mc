import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Lang;

// Main game screen. Renders the hole map via HoleRenderer, overlays score relative to par, and shows GPS status

class HoleView extends WatchUi.View {
    var model;
    var renderer;
    var updateTimer;

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

    function onUpdate(dc as Graphics.Dc) as Void {
        var hole = model.courseData.holes[model.currentHole];
        
        // If viewing a hole we've moved past, show last ball at pin
        var holeIsFinished = (model.scores[model.currentHole] > 0 && model.currentHole < model._getLastPlayedHole());
        var balls = model.getBallPositions(model.currentHole, holeIsFinished);
        var displayDist = model.getDisplayDistance();

        renderer.draw(dc, hole, model.playerLat, model.playerLon, displayDist, balls);

        // Only show score if hole has been started
        var strokes = model.scores[model.currentHole];
        if (strokes > 0) {
            var par = hole["par"];
            var diff = strokes - par;

            var scoreText;
            var scoreColor;
            if (diff < 0) {
                scoreText = diff.toString();
                scoreColor = 0x44BBFF;
            } else if (diff == 0) {
                scoreText = "E";
                scoreColor = 0xFFFFFF;
            } else {
                scoreText = "+" + diff;
                scoreColor = 0xFF6644;
            }

            dc.setColor(scoreColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(28, dc.getHeight() / 2 - 12, Graphics.FONT_MEDIUM,
                scoreText, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Draw GPS status
        if (!model.gpsActive || model.playerLat == 0) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_TINY,
                "Waiting for GPS...", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
