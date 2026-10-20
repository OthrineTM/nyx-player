import QtQuick
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

// Tells a desktop widget when windows hide it, so it can pause its timers and animations.
// mode: 0 never, 1 a maximized or fullscreen window on this screen, 2 any window over the widget
Item {
    id: cover
    visible: false
    width: 0
    height: 0

    property Item target
    property int mode: 1
    property bool covered: false

    readonly property bool watching: mode > 0 && !!target

    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: windows
        groupMode: TaskManager.TasksModel.GroupDisabled
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByScreen: true
        filterByCurrentVirtualDesktop: true
        activity: activityInfo.currentActivity
        filterByActivity: true
        filterMinimized: true
        filterHidden: true
    }
    Instantiator {
        id: list
        active: cover.watching
        model: windows
        delegate: QtObject {
            readonly property bool win: model.IsWindow === true
            readonly property bool big: model.IsMaximized === true || model.IsFullScreen === true
            readonly property rect geo: model.Geometry
            onBigChanged: check.restart()
            onGeoChanged: check.restart()
        }
        onObjectAdded: check.restart()
        onObjectRemoved: check.restart()
        onActiveChanged: check.restart()
    }
    onModeChanged: check.restart()

    Timer {
        id: check
        interval: 250
        onTriggered: {
            var hit = false
            if (list.active && cover.mode > 0) {
                var sg = Plasmoid.containment.screenGeometry
                var p = cover.target.mapToItem(null, 0, 0)
                var x1 = sg.x + p.x, y1 = sg.y + p.y
                var x2 = x1 + cover.target.width, y2 = y1 + cover.target.height
                for (var i = 0; i < list.count && !hit; i++) {
                    var w = list.objectAt(i)
                    if (!w || !w.win) continue
                    if (cover.mode === 1) hit = w.big
                    else hit = w.geo.x < x2 && w.geo.x + w.geo.width > x1
                               && w.geo.y < y2 && w.geo.y + w.geo.height > y1
                }
            }
            cover.covered = hit
        }
    }
}
