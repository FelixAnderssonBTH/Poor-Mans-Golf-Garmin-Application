import Toybox.Graphics;
import Toybox.Lang;

// Distances to the front, centre and back of the green.
//
// Stacked back-over-front so the numbers sit in the same spatial order as the
// green ahead of the player, with the centre as the hero figure. Positions are
// derived from the actual font heights rather than hardcoded, since the number
// fonts differ across devices and the screen is round -- content has to stay
// clear of the narrowing top and bottom.

class GreenPage extends HolePage {

    const COLOR_BG = 0x1A3A1A;
    const COLOR_MAIN = 0xFFFFFF;
    const COLOR_DIM = 0xAAAAAA;
    const COLOR_LABEL = 0x888888;
    const COLOR_WARN = 0xFF4444;

    // Gap between the widest possible centre number and the label column.
    const LABEL_GAP = 16;

    function initialize() {
        HolePage.initialize();
    }

    function draw(dc as Graphics.Dc, model as GolfModel) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        // The converter omits gf/gc/gb when a hole has no green, and
        // _updateDistances leaves them at -1.0. Say so plainly rather than
        // showing three dashes, which would read as a GPS problem.
        if (model.distCentre < 0) {
            dc.setColor(COLOR_WARN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 10, Graphics.FONT_TINY,
                "No green data", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var hasFix = (model.playerLat != 0);

        var smallH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var bigH = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        var gap = 6;

        // One label column for all three rows, placed clear of the widest
        // number the centre can ever show. Deriving it from the current value
        // instead would shift the labels sideways every time a distance
        // crossed from three digits to two.
        var labelX = w / 2 - dc.getTextWidthInPixels("888", Graphics.FONT_NUMBER_MEDIUM) / 2
                     - LABEL_GAP;

        // Centre the three-line stack vertically
        var total = smallH + gap + bigH + gap + smallH;
        var y = (h - total) / 2;

        // Back, above -- the far edge of the green
        _row(dc, labelX, w, y, smallH, "B", _fmt(model.distBack, hasFix),
             Graphics.FONT_MEDIUM, COLOR_DIM);
        y += smallH + gap;

        // Centre, the number to club off
        _row(dc, labelX, w, y, bigH, "C", _fmt(model.distCentre, hasFix),
             Graphics.FONT_NUMBER_MEDIUM, COLOR_MAIN);
        y += bigH + gap;

        // Front, below -- the near edge, the carry you must make
        _row(dc, labelX, w, y, smallH, "F", _fmt(model.distFront, hasFix),
             Graphics.FONT_MEDIUM, COLOR_DIM);
    }

    // One labelled row. The number is centred on the screen; the label is
    // right-justified in the shared column and vertically centred against the
    // row, so a small label lines up with a tall number.
    hidden function _row(dc as Graphics.Dc, labelX, w, y, rowH, label, text, font, color) as Void {
        var labelH = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(COLOR_LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelX, y + (rowH - labelH) / 2, Graphics.FONT_XTINY,
            label, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Dashes rather than a number when there is no fix: a distance computed
    // from a null position would look authoritative and be meaningless.
    hidden function _fmt(metres, hasFix) as String {
        if (!hasFix || metres < 0) {
            return "--";
        }
        return metres.toNumber().toString();
    }
}
