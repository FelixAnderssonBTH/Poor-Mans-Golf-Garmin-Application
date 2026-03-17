import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application;

//  Course selection screen. Shows course name, hole count, and par. 

class CoursePickerView extends WatchUi.View {

    // Collect simple meta data from each course for preview

    var courseNames;
    var courseHoles;
    var coursePars;
    var resourceIds;
    var currentIndex = 0;

    function initialize() {
        View.initialize();
        _loadMetadata();
    }

    hidden function _loadMetadata() as Void {
        // ADD NEW COURSES HERE when you add new JSON files
        resourceIds = [
            Rez.JsonData.course_trummenas,
        ];

        var count = resourceIds.size();
        courseNames = new [count];
        courseHoles = new [count];
        coursePars = new [count];

        // Load each course briefly just to grab metadata, such as course name, number of holes and par
        for (var i = 0; i < count; i++) {
            var data = Application.loadResource(resourceIds[i]);
            courseNames[i] = data["name"];
            courseHoles[i] = (data["holes"] as Array).size();
            coursePars[i] = data["par"];
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x222222, 0x222222);
        dc.clear();

        // Course name
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 30, Graphics.FONT_SMALL, courseNames[currentIndex], Graphics.TEXT_JUSTIFY_CENTER);

        // Holes and par
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 10, Graphics.FONT_TINY, courseHoles[currentIndex] + " holes  Par " + coursePars[currentIndex], Graphics.TEXT_JUSTIFY_CENTER);
    }

    function nextCourse() as Void {
        currentIndex = (currentIndex + 1) % resourceIds.size();
        WatchUi.requestUpdate();
    }

    function prevCourse() as Void {
        currentIndex = (currentIndex - 1 + resourceIds.size()) % resourceIds.size();
        WatchUi.requestUpdate();
    }

    // Loads full course data when you have selected a course
    function loadSelectedCourse() as Dictionary {
        return Application.loadResource(resourceIds[currentIndex]);
    }
}
