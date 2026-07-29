import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;

//  Simple data class that holds course name, par, and holes array from a parsed JSON dictionary.
//  Also supports "free play" mode: no pre-defined course, holes are created on the fly
//  with a par the player picks at the start of each hole.

class CourseData {
    var name as String = "";
    var par as Number = 0;
    var numHoles as Number = 0;
    var holes as Array = [];

    // True when there is no pre-defined course (no map data)
    var freePlay as Boolean = false;

    function initialize(data as Dictionary) {
        name = data["name"] as String;
        par = data["par"] as Number;

        var holesData = data["holes"] as Array;
        numHoles = holesData.size();
        holes = new [numHoles];

        for (var i = 0; i < numHoles; i++) {
            holes[i] = holesData[i];
        }
    }

    // Build a course with no map data. Par per hole starts unset (0) and is
    // chosen by the player before the first shot on each hole.
    static function createFreePlay(holeCount as Number) as CourseData {
        var holesData = new [holeCount];
        for (var i = 0; i < holeCount; i++) {
            holesData[i] = {
                "num" => i + 1,
                "par" => 0,      // 0 = not chosen yet
                "dist" => 0
            };
        }

        var cd = new CourseData({
            "name" => "Free Play",
            "par" => 0,
            "holes" => holesData
        });
        cd.freePlay = true;
        return cd;
    }

    // Set the par for a hole in free play and keep the course total in sync
    function setHolePar(idx as Number, newPar as Number) as Void {
        if (idx < 0 || idx >= numHoles) { return; }
        var hole = holes[idx];
        var old = hole["par"];
        if (old == null) { old = 0; }
        hole["par"] = newPar;
        par = par - old + newPar;
    }

    // In free play a hole is "unset" until the player chooses a par
    function holeParChosen(idx as Number) as Boolean {
        if (!freePlay) { return true; }
        if (idx < 0 || idx >= numHoles) { return true; }
        var p = holes[idx]["par"];
        return (p != null && p > 0);
    }
}
