import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

 // End-of-round screen. Shows total strokes, score to par, and course par.

class SummaryView extends WatchUi.View {
    var model;

    function initialize(golfModel as GolfModel) {
        View.initialize();
        model = golfModel;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x222222, 0x222222);
        dc.clear();

        var totalStr = model.totalStrokes();
        var totalTP = model.totalToPar();

        // Title
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 45, Graphics.FONT_SMALL,
            "Round Complete", Graphics.TEXT_JUSTIFY_CENTER);

        // Strokes
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 40, Graphics.FONT_MEDIUM,
            "Strokes: " + totalStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Score to par
        var scoreText;
        var scoreColor;
        if (totalTP < 0) {
            scoreText = totalTP.toString();
            scoreColor = 0x44BBFF;
        } else if (totalTP == 0) {
            scoreText = "E";
            scoreColor = 0xFFFFFF;
        } else {
            scoreText = "+" + totalTP;
            scoreColor = 0xFF6644;
        }
        dc.setColor(scoreColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_MEDIUM,
            "Score: " + scoreText, Graphics.TEXT_JUSTIFY_CENTER);

        // Par
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 40, Graphics.FONT_MEDIUM,
            "Par: " + model.courseData.par, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
