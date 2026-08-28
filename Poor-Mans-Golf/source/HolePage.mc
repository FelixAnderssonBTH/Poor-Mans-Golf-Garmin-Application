import Toybox.Graphics;
import Toybox.Lang;

// One screen within a hole. Pages are drawing-only: they own no timers, no GPS
// and no view lifecycle -- HoleView keeps all of that. A page draws its own
// content and nothing else; the shared score chrome is drawn around it by
// HoleView, so pages must leave those regions clear.

class HolePage {

    function initialize() {
    }

    // Draw this page's content. Subclasses override.
    function draw(dc as Graphics.Dc, model as GolfModel) as Void {
    }
}
