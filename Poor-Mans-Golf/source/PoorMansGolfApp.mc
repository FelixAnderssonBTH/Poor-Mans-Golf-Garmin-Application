import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;


//  App entry point. Launches the course picker screen.

class PoorMansGolfApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var pickerView = new CoursePickerView();
        var pickerDelegate = new CoursePickerDelegate(pickerView);
        return [pickerView, pickerDelegate];
    }
}
