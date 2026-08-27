import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

 // End-of-round screen. Shows total strokes, score to par, and course par.

class SummaryView extends WatchUi.View {
    var model;

    // Where Discard returns to. This view can be the one revealed when the
    // discard confirmation is popped, so it needs the same handling as HoleView.
    var pickerView as CoursePickerView;
    var pickerDelegate as CoursePickerDelegate;

    function initialize(golfModel as GolfModel, pView as CoursePickerView,
                        pDelegate as CoursePickerDelegate) {
        View.initialize();
        model = golfModel;
        pickerView = pView;
        pickerDelegate = pDelegate;
    }

    // The round was discarded from the menu while the summary was on screen.
    // The system pops that confirmation after onResponse() returns, revealing
    // this view, so the move back to the picker has to happen here.
    function onShow() as Void {
        if (model.roundDiscarded) {
            WatchUi.switchToView(pickerView, pickerDelegate, WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Leaving: paint bare background rather than the round being abandoned
        if (model.roundDiscarded) {
            dc.setColor(0x222222, 0x222222);
            dc.clear();
            return;
        }

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

        // Par (in free play this is the sum of the pars picked during the round)
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 40, Graphics.FONT_MEDIUM,
            "Par: " + model.courseData.par, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
