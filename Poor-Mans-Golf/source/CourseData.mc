import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;

//  Simple data class that holds course name, par, and holes array from a parsed JSON dictionary.

class CourseData {
    var name as String = "";
    var par as Number = 0;
    var numHoles as Number = 0;
    var holes as Array = [];

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
}
