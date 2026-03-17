import Toybox.Graphics;
import Toybox.Math;
import Toybox.Lang;

// Draws the hole map. Rotates so tee is always at bottom, pin at top. Renders fairways, greens, bunkers, water, path, tee box, pin, player dot, ball markers, and info text.

class HoleRenderer {

    var screenW;
    var screenH;

    var offsetX = 0;
    var offsetY = 0;
    var scale = 1.0;

    hidden var _centerLat = 0;
    hidden var _centerLon = 0;
    hidden var _cosLat = 1.0;
    hidden var _sinAngle = 0.0;
    hidden var _cosAngle = 1.0;

    const COLOR_FAIRWAY = 0x2D7A2D;
    const COLOR_GREEN = 0x40C040;
    const COLOR_BUNKER = 0xE8D44D;
    const COLOR_WATER = 0x3377BB;
    const COLOR_PATH = 0x88CC88;
    const COLOR_PIN = 0xFF3333;
    const COLOR_PLAYER = 0xAA44FF;
    const COLOR_BALL = 0xFFFFFF;
    const COLOR_BG = 0x1A3A1A;
    const COLOR_TEXT = 0xFFFFFF;
    const COLOR_BLACK = 0x000000;
    const COLOR_TEE_BOX = 0xCCCCCC;

    function initialize(w, h) {
        screenW = w;
        screenH = h;
    }

    function fitHole(hole as Dictionary) {

        var tee = hole["tee"];
        var pin = hole["pin"];

        var midLat = (tee[0] + pin[0]) / 2;
        _cosLat = Math.cos((midLat / 100000.0) * Math.PI / 180.0);

        _centerLat = midLat;
        _centerLon = (tee[1] + pin[1]) / 2;

        var dxTP = (pin[1] - tee[1]) * _cosLat;
        var dyTP = (pin[0] - tee[0]);

        var angle = Math.atan2(dxTP.toFloat(), dyTP.toFloat());
        _sinAngle = Math.sin(angle);
        _cosAngle = Math.cos(angle);

        var minX = 99999999.0;
        var maxX = -99999999.0;
        var minY = 99999999.0;
        var maxY = -99999999.0;

        var tp = _gpsToRotated(tee[0], tee[1]);
        minX = _minF(minX, tp[0]); maxX = _maxF(maxX, tp[0]);
        minY = _minF(minY, tp[1]); maxY = _maxF(maxY, tp[1]);

        var pp = _gpsToRotated(pin[0], pin[1]);
        minX = _minF(minX, pp[0]); maxX = _maxF(maxX, pp[0]);
        minY = _minF(minY, pp[1]); maxY = _maxF(maxY, pp[1]);

        var path = hole["path"];
        for (var i = 0; i < path.size(); i++) {
            var rp = _gpsToRotated(path[i][0], path[i][1]);
            minX = _minF(minX, rp[0]); maxX = _maxF(maxX, rp[0]);
            minY = _minF(minY, rp[1]); maxY = _maxF(maxY, rp[1]);
        }

        var rangeX = maxX - minX;
        var rangeY = maxY - minY;
        if (rangeX < 30.0) { rangeX = 30.0; }
        if (rangeY < 30.0) { rangeY = 30.0; }

        var padX = rangeX * 0.20;
        var padY = rangeY * 0.20;
        rangeX = rangeX + padX * 2;
        rangeY = rangeY + padY * 2;

        var scaleX = (screenW - 10).toFloat() / rangeX;
        var scaleY = (screenH - 10).toFloat() / rangeY;
        scale = (scaleX < scaleY) ? scaleX : scaleY;

        offsetX = screenW / 2;
        offsetY = screenH / 2;
    }

    hidden function _gpsToRotated(lat, lon) {
        var dx = (lon - _centerLon) * _cosLat;
        var dy = (lat - _centerLat);
        var rx = dx * _cosAngle - dy * _sinAngle;
        var ry = dx * _sinAngle + dy * _cosAngle;
        return [rx.toFloat(), ry.toFloat()];
    }

    hidden function _minF(a, b) { return (a < b) ? a : b; }
    hidden function _maxF(a, b) { return (a > b) ? a : b; }

    function gpsToScreen(lat, lon) {
        var r = _gpsToRotated(lat, lon);
        var sx = offsetX + r[0] * scale;
        var sy = offsetY - r[1] * scale;
        return [sx, sy];
    }

    function draw(dc, hole, playerLat, playerLon, distToPin, balls) {

        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        fitHole(hole);

        if (hole.hasKey("fw")) {
            _drawPolygons(dc, hole["fw"], COLOR_FAIRWAY);
        }

        if (hole.hasKey("water")) {
            _drawPolygons(dc, hole["water"], COLOR_WATER);
        }

        if (hole.hasKey("green")) {
            _drawPolygon(dc, hole["green"], COLOR_GREEN);
        }

        if (hole.hasKey("bk")) {
            _drawBunkers(dc, hole["bk"]);
        }

        _drawPath(dc, hole["path"]);

        // Draw ball positions
        if (balls != null) {
            _drawBalls(dc, balls);
        }

        var tee = hole["tee"];
        _drawTee(dc, tee[0], tee[1]);

        var pin = hole["pin"];
        _drawPin(dc, pin[0], pin[1]);

        if (playerLat != 0) {
            _drawPlayer(dc, playerLat, playerLon);
        }

        _drawInfo(dc, hole, distToPin);
    }

    hidden function _drawPolygons(dc, polygons, color) {
        for (var i = 0; i < polygons.size(); i++) {
            _drawPolygon(dc, polygons[i], color);
        }
    }

    hidden function _drawPolygon(dc, points, color) {
        if (points.size() < 3) { return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var screenPts = new [points.size()];
        for (var i = 0; i < points.size(); i++) {
            screenPts[i] = gpsToScreen(points[i][0], points[i][1]);
        }
        dc.fillPolygon(screenPts);
        dc.setPenWidth(1);
        for (var i = 0; i < screenPts.size() - 1; i++) {
            dc.drawLine(screenPts[i][0], screenPts[i][1],
                        screenPts[i + 1][0], screenPts[i + 1][1]);
        }
    }

    hidden function _drawBunkers(dc, bunkers) {
        dc.setColor(COLOR_BUNKER, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < bunkers.size(); i++) {
            var p = gpsToScreen(bunkers[i][0], bunkers[i][1]);
            dc.fillCircle(p[0], p[1], 5);
        }
    }
hidden function _drawBalls(dc, balls) {
        for (var i = 0; i < balls.size(); i++) {
            var ball = balls[i];
            var p = gpsToScreen(ball[0], ball[1]);

            dc.setColor(COLOR_BALL, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(p[0], p[1], 3);
        }
    }

    hidden function _drawPath(dc, path) {
        dc.setColor(COLOR_PATH, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < path.size() - 1; i++) {
            var s1 = gpsToScreen(path[i][0], path[i][1]);
            var s2 = gpsToScreen(path[i+1][0], path[i+1][1]);
            dc.drawLine(s1[0], s1[1], s2[0], s2[1]);
        }
        dc.setPenWidth(1);
    }

    hidden function _drawTee(dc, lat, lon) {
        var p = gpsToScreen(lat, lon);
        dc.setColor(COLOR_TEE_BOX, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(p[0] - 5, p[1] - 3, 10, 6);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(p[0] - 5, p[1] - 3, 10, 6);
    }

    hidden function _drawPin(dc, lat, lon) {
        var p = gpsToScreen(lat, lon);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(p[0], p[1], p[0], p[1] - 14);
        dc.setColor(COLOR_PIN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], 3);
    }

    hidden function _drawPlayer(dc, lat, lon) {
        var p = gpsToScreen(lat, lon);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], 8);
        dc.setColor(COLOR_PLAYER, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], 6);
    }

    hidden function _drawInfo(dc, hole, distToPin) {
        var topY = 24;
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        var topText = "Hole " + hole["num"] + "  Par " + hole["par"];
        dc.drawText(screenW / 2, topY, Graphics.FONT_SMALL, topText, Graphics.TEXT_JUSTIFY_CENTER);

        var botY = screenH - 48;
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        var distText;
        if (distToPin >= 0) {
            distText = distToPin.toNumber() + "m";
        } else {
            distText = hole["dist"] + "m";
        }
        dc.drawText(screenW / 2, botY, Graphics.FONT_MEDIUM, distText, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
