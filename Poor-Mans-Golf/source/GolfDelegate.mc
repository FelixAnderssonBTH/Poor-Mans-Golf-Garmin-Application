import Toybox.WatchUi;
import Toybox.Lang;

//  Input handler for the course picker. START loads the full course and starts the game

class GolfDelegate extends WatchUi.BehaviorDelegate {
    var model;
    var holeView;
    var summaryView;

    function initialize(golfModel as GolfModel, hView as HoleView, sView as SummaryView) {
        BehaviorDelegate.initialize();
        model = golfModel;
        holeView = hView;
        summaryView = sView;
    }

    // Swipe up / UP button: previous hole
    function onPreviousPage() {
        if (model.roundFinished) {
            // Go back to last hole from summary
            model.prevHole();
            WatchUi.switchToView(holeView, self, WatchUi.SLIDE_RIGHT);
        } else {
            model.prevHole();
        }
        return true;
    }

    // Swipe down / DOWN button: next hole
    function onNextPage() {
        var wasFinished = model.roundFinished;
        model.nextHole();
        if (model.roundFinished && !wasFinished) {
            // Just moved past last hole -> show summary
            WatchUi.switchToView(summaryView, self, WatchUi.SLIDE_LEFT);
        }
        return true;
    }

    // BACK button: undo last stroke
    function onBack() {
        if (model.roundFinished) {
            model.prevHole();
            WatchUi.switchToView(holeView, self, WatchUi.SLIDE_RIGHT);
            return true;
        }
        if (model.scores[model.currentHole] > 0) {
            var dialog = new WatchUi.Confirmation("Undo stroke?");
            WatchUi.pushView(dialog, new UndoConfirmDelegate(model), WatchUi.SLIDE_UP);
        }
        return true;
    }

    // Handle physical key presses
    function onKey(evt) {
        var key = evt.getKey();

        // SELECT/START/ENTER
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            if (model.roundFinished) {
                // On summary page: confirm finish
                var dialog = new WatchUi.Confirmation("Finish round?");
                WatchUi.pushView(dialog, new SaveConfirmDelegate(model), WatchUi.SLIDE_UP);
            } else {
                model.addStroke();
            }
            return true;
        }

        return false;
    }

    // Long press MENU/START: show save confirmation
    function onMenu() {
        var dialog = new WatchUi.Confirmation("Save round?");
        WatchUi.pushView(dialog, new SaveConfirmDelegate(model), WatchUi.SLIDE_UP);
        return true;
    }

    function onTap(evt) {
        return true;
    }
}

class UndoConfirmDelegate extends WatchUi.ConfirmationDelegate {
    var model;

    function initialize(golfModel as GolfModel) {
        ConfirmationDelegate.initialize();
        model = golfModel;
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            model.removeStroke();
        }
        return true;
    }
}

class SaveConfirmDelegate extends WatchUi.ConfirmationDelegate {
    var model;

    function initialize(golfModel as GolfModel) {
        ConfirmationDelegate.initialize();
        model = golfModel;
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            model.saveAndStop();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
}
