import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;

//  Input handler for the round. START registers a stroke, BACK undoes it,
//  UP/DOWN move between holes. In free play, when a hole has no par chosen yet,
//  UP/DOWN pick the par and START confirms it. Holding BACK on a free play hole
//  re-opens the par picker; on devices that don't report a held BACK, the menu
//  (long press UP) offers the same thing.

class GolfDelegate extends WatchUi.BehaviorDelegate {
    var model;
    var holeView;
    var summaryView;

    // Long press detection for the BACK key.
    // onBack() fires on release, so we start a timer on key down: if it expires
    // while the key is still held it's a long press, and we open the par editor.
    // The onBack() that follows is then swallowed.
    hidden var _holdTimer;
    hidden var _longPressFired = false;
    const LONG_PRESS_MS = 600;

    function initialize(golfModel as GolfModel, hView as HoleView, sView as SummaryView) {
        BehaviorDelegate.initialize();
        model = golfModel;
        holeView = hView;
        summaryView = sView;
    }

    // True while the free play par picker is on screen
    hidden function _inParPicker() as Boolean {
        return (!model.roundFinished && model.isFreePlay() && holeView.parPickerActive());
    }

    // Can the par of the current hole be edited right now?
    hidden function _canEditPar() as Boolean {
        return (!model.roundFinished && model.isFreePlay()
                && !model.needsParSelection() && !holeView.isEditingPar());
    }

    // Swipe up / UP button: previous hole (or previous par option)
    function onPreviousPage() {
        if (_inParPicker()) {
            holeView.prevPar();
            return true;
        }
        if (model.roundFinished) {
            // Go back to last hole from summary
            model.prevHole();
            WatchUi.switchToView(holeView, self, WatchUi.SLIDE_RIGHT);
        } else {
            model.prevHole();
        }
        return true;
    }

    // Swipe down / DOWN button: next hole (or next par option)
    function onNextPage() {
        if (_inParPicker()) {
            holeView.nextPar();
            return true;
        }
        var wasFinished = model.roundFinished;
        model.nextHole();
        if (model.roundFinished && !wasFinished) {
            // Just moved past last hole -> show summary
            WatchUi.switchToView(summaryView, self, WatchUi.SLIDE_LEFT);
        }
        return true;
    }

    // BACK pressed down: start the hold timer
    function onKeyPressed(evt) {
        if (evt.getKey() == WatchUi.KEY_ESC && _canEditPar()) {
            _stopHoldTimer();
            _longPressFired = false;
            _holdTimer = new Timer.Timer();
            _holdTimer.start(method(:onHoldExpired) as Method() as Void, LONG_PRESS_MS, false);
        }
        return false;
    }

    // BACK released: cancel the timer if it hasn't fired yet
    function onKeyReleased(evt) {
        if (evt.getKey() == WatchUi.KEY_ESC) {
            _stopHoldTimer();
        }
        return false;
    }

    // Held long enough: open the par editor
    function onHoldExpired() as Void {
        _stopHoldTimer();
        if (_canEditPar()) {
            _longPressFired = true;
            holeView.openParEdit();
        }
    }

    hidden function _stopHoldTimer() as Void {
        if (_holdTimer != null) {
            _holdTimer.stop();
            _holdTimer = null;
        }
    }

    // BACK button: undo last stroke
    function onBack() {
        _stopHoldTimer();

        // This press already opened the par editor, don't also undo a stroke
        if (_longPressFired) {
            _longPressFired = false;
            return true;
        }

        if (model.roundFinished) {
            model.prevHole();
            WatchUi.switchToView(holeView, self, WatchUi.SLIDE_RIGHT);
            return true;
        }
        if (_inParPicker()) {
            // Cancel an in-progress par edit, otherwise nothing to undo yet
            if (holeView.isEditingPar()) {
                holeView.cancelParEdit();
            }
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
            } else if (_inParPicker()) {
                // Lock in the par for this hole
                holeView.confirmPar();
            } else {
                model.addStroke();
            }
            return true;
        }

        return false;
    }

    // Long press MENU (hold UP): the only way out of a round mid-play.
    // Save writes the activity and quits; Discard throws it away and drops back
    // to the course picker; Resume is BACK (Menu2 pops itself).
    function onMenu() {
        var menu = new WatchUi.Menu2({:title => "Round"});
        menu.addItem(new WatchUi.MenuItem("Save & exit", null, :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        WatchUi.pushView(menu, new RoundMenuDelegate(model), WatchUi.SLIDE_UP);
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
            // System.exit() rather than popView(): the round is over either way,
            // and popping depended on how deep the view stack happened to be,
            // which differed between the course and free play paths.
            System.exit();
        }
        return true;
    }
}


//  Input handler for the hold-UP round menu.

class RoundMenuDelegate extends WatchUi.Menu2InputDelegate {
    var model as GolfModel;

    function initialize(golfModel as GolfModel) {
        Menu2InputDelegate.initialize();
        model = golfModel;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :save) {
            model.saveAndStop();
            System.exit();
            return;
        }

        if (id == :discard) {
            // Close the menu first, so the confirmation sits directly on top of
            // the hole view and answering it leaves a one-deep stack again.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            var dialog = new WatchUi.Confirmation("Discard round?");
            WatchUi.pushView(dialog, new DiscardConfirmDelegate(model), WatchUi.SLIDE_UP);
            return;
        }

        // :resume -- just close the menu and carry on playing
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}


class DiscardConfirmDelegate extends WatchUi.ConfirmationDelegate {
    var model as GolfModel;

    function initialize(golfModel as GolfModel) {
        ConfirmationDelegate.initialize();
        model = golfModel;
    }

    // Only state changes here. The system pops this dialog once we return, so
    // any view switch made here would be popped with it; HoleView.onShow()
    // performs the actual move back to the course picker.
    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            model.discardAndStop();
        }
        return true;
    }
}
