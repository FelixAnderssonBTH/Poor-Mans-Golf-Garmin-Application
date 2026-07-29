import Toybox.WatchUi;
import Toybox.Lang;

//  Input handler for the free play hole count screen.

class HoleCountPickerDelegate extends WatchUi.BehaviorDelegate {
    var pickerView;

    function initialize(view as HoleCountPickerView) {
        BehaviorDelegate.initialize();
        pickerView = view;
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

        var holeView = new HoleView(model);
        var summaryView = new SummaryView(model);
        var delegate = new GolfDelegate(model, holeView, summaryView);

        WatchUi.switchToView(holeView, delegate, WatchUi.SLIDE_LEFT);
    }

    // BACK: return to course picker
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt) {
        return true;
    }
}
