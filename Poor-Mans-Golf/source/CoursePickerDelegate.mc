import Toybox.WatchUi;
import Toybox.Lang;

class CoursePickerDelegate extends WatchUi.BehaviorDelegate {
    var pickerView as CoursePickerView;

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
        // "No Course" selected: go to the hole count screen instead
        if (pickerView.isNoCourseSelected()) {
            var countView = new HoleCountPickerView();
            var countDelegate = new HoleCountPickerDelegate(countView, pickerView, self);
            // switchToView, not pushView: every screen in the app keeps the view
            // stack exactly one deep, so ending a round behaves the same however
            // it was started. The hole count screen returns here via its onBack().
            WatchUi.switchToView(countView, countDelegate, WatchUi.SLIDE_LEFT);
            return;
        }

        // Only now load the full course data into memory
        var selectedData = pickerView.loadSelectedCourse();
        var courseData = new CourseData(selectedData);
        var model = new GolfModel(courseData);
        model.startGps();
        model.startRecording();

        var holeView = new HoleView(model, pickerView, self);
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
