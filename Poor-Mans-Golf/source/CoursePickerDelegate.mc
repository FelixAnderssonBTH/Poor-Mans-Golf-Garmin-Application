import Toybox.WatchUi;
import Toybox.Lang;

class CoursePickerDelegate extends WatchUi.BehaviorDelegate {
    var pickerView;

    function initialize(view as CoursePickerView) {
        BehaviorDelegate.initialize();
        pickerView = view;
    }

    // Swipe down / DOWN button: next course
    function onNextPage() {
        pickerView.nextCourse();
        return true;
    }

    // Swipe up / UP button: previous course
    function onPreviousPage() {
        pickerView.prevCourse();
        return true;
    }

    // SELECT/START: start the selected course
    function onSelect() {
        _startGame();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            _startGame();
            return true;
        }
        return false;
    }

    hidden function _startGame() as Void {
        // Only now load the full course data into memory
        var selectedData = pickerView.loadSelectedCourse();
        var courseData = new CourseData(selectedData);
        var model = new GolfModel(courseData);
        model.startGps();
        model.startRecording();

        var holeView = new HoleView(model);
        var summaryView = new SummaryView(model);
        var delegate = new GolfDelegate(model, holeView, summaryView);

        WatchUi.switchToView(holeView, delegate, WatchUi.SLIDE_LEFT);
    }

    // BACK: exit app
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Block tap
    function onTap(evt) {
        return true;
    }
}
