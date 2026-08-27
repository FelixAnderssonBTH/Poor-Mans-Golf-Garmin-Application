import Toybox.WatchUi;
import Toybox.Lang;

//  Input handler for the free play hole count screen.

class HoleCountPickerDelegate extends WatchUi.BehaviorDelegate {
    var pickerView;

    // The course picker we came from, kept alive rather than rebuilt: its
    // constructor loads every course resource just to read the preview
    // metadata, so a fresh one is expensive.
    var coursePickerView as CoursePickerView;
    var coursePickerDelegate as CoursePickerDelegate;

    function initialize(view as HoleCountPickerView, cView as CoursePickerView,
                        cDelegate as CoursePickerDelegate) {
        BehaviorDelegate.initialize();
        pickerView = view;
        coursePickerView = cView;
        coursePickerDelegate = cDelegate;
    }

    function onNextPage() {
        pickerView.next();
        return true;
    }

    function onPreviousPage() {
        pickerView.prev();
        return true;
    }

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
        var courseData = CourseData.createFreePlay(pickerView.selectedCount());
        var model = new GolfModel(courseData);
        model.startGps();
        model.startRecording();

        var holeView = new HoleView(model, coursePickerView, coursePickerDelegate);
        var summaryView = new SummaryView(model);
        var delegate = new GolfDelegate(model, holeView, summaryView);

        WatchUi.switchToView(holeView, delegate, WatchUi.SLIDE_LEFT);
    }

    // BACK: return to course picker. switchToView rather than popView because
    // this screen replaced the picker instead of stacking on top of it.
    function onBack() {
        WatchUi.switchToView(coursePickerView, coursePickerDelegate, WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt) {
        return true;
    }
}
