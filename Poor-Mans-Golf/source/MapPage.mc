import Toybox.Graphics;
import Toybox.Lang;

// The hole map: fairways, green, bunkers, water, the hole path, the player dot
// and ball markers, all drawn by HoleRenderer.

class MapPage extends HolePage {
    hidden var _renderer;

    function initialize(holeRenderer) {
        HolePage.initialize();
        _renderer = holeRenderer;
    }

    function draw(dc as Graphics.Dc, model as GolfModel) as Void {
        var hole = model.courseData.holes[model.currentHole];
        var holeIsFinished = (model.scores[model.currentHole] > 0
                              && model.currentHole < model._getLastPlayedHole());
        var balls = model.getBallPositions(model.currentHole, holeIsFinished);
        var displayDist = model.getDisplayDistance();

        _renderer.draw(dc, hole, model.playerLat, model.playerLon, displayDist, balls);
    }
}
