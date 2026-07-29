import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

//  Free play setup screen. Choose how many holes the round has.

class HoleCountPickerView extends WatchUi.View {

    const MIN_HOLES = 1;
    const MAX_HOLES = 18;
    var count = 18;   // default

    function initialize() {
        View.initialize();
    }



    function selectedCount() as Number {
        return count;
    }

    function next() as Void {
        count = (count >= MAX_HOLES) ? MIN_HOLES : count + 1;
        WatchUi.requestUpdate();
    }

    function prev() as Void {
        count = (count <= MIN_HOLES) ? MAX_HOLES : count - 1;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x222222, 0x222222);
        dc.clear();

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 55, Graphics.FONT_TINY, "How many holes?", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 20, Graphics.FONT_NUMBER_MEDIUM,
                    count.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 80, Graphics.FONT_XTINY, "START to begin", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
