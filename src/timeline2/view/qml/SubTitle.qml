import QtQuick 2.11
import QtQuick.Controls 2.4

Item {
    id: subtitleRoot
    visible : true
    z: 20
    property int oldStartX
    property int startFrame
    property int endFrame
    property int subId
    property int duration : endFrame - startFrame
    property var subtitle
    property bool selected
    height: subtitleTrack.height
    onStartFrameChanged: {
        if (!subtitleClipArea.pressed) {
            subtitleClipArea.x = startFrame * timeScale
        }
    }
    MouseArea {
            // Clip shifting
            id: subtitleClipArea
            x: startFrame * timeScale;
            height: parent.height
            width: subtitleBase.width
            hoverEnabled: true
            enabled: true
            property int newStart: -1
            property int diff: -1
            property int oldStartFrame
            property int snappedFrame
            property double delta: -1
            property double oldDelta: 0
            property bool startMove: false
            visible: root.activeTool === 0
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (pressed ? Qt.ClosedHandCursor : ((startMouseArea.drag.active || endMouseArea.drag.active)? Qt.SizeHorCursor: Qt.PointingHandCursor));
            //drag.target: subtitleBase
            drag.axis: Drag.XAxis
            drag.smoothed: false
            drag.minimumX: 0
            onEntered: {
                console.log('ENTERED SUBTITLE MOUSE AREA')
            }
            onPressed: {
                console.log('ENTERED ITEM CLCKD')
                root.autoScrolling = false
                oldStartX = mouseX
                oldStartFrame = subtitleRoot.startFrame
                snappedFrame = oldStartFrame
                x = subtitleBase.x
                startMove = mouse.button & Qt.LeftButton
                if (timeline.selection.indexOf(subtitleRoot.subId) == -1) {
                    controller.requestAddToSelection(subtitleRoot.subId, !(mouse.modifiers & Qt.ShiftModifier))
                } else if (mouse.modifiers & Qt.ShiftModifier) {
                    console.log('REMOVE FROM SELECTION!!!!')
                    controller.requestRemoveFromSelection(subtitleRoot.subId)
                }
            }
            onPositionChanged: {
                if (pressed && !subtitleBase.textEditBegin && startMove) {
                    newStart = Math.max(0, oldStartFrame + (mouseX - oldStartX)/ timeScale)
                    snappedFrame = controller.suggestSubtitleMove(subId, newStart, root.consumerPosition, root.snapping)
                }
            }
            onReleased: {
                if (subtitleBase.textEditBegin) {
                    mouse.accepted = false
                    return
                }
                root.autoScrolling = timeline.autoScroll
                if (startMove) {
                    startMove = false
                    if (subtitleBase.x < 0)
                        subtitleBase.x = 0
                    if (oldStartFrame != snappedFrame) {
                        console.log("old start frame",oldStartFrame/timeline.scaleFactor, "new frame afer shifting ",oldStartFrame/timeline.scaleFactor + delta)
                        controller.requestSubtitleMove(subId, oldStartFrame, false, false);
                        controller.requestSubtitleMove(subId, snappedFrame, true, true);
                        x = snappedFrame * timeScale
                    }
                }
                console.log('RELEASED DONE\n\n_______________')
            }
            onClicked: {
                if (mouse.button == Qt.RightButton) {
                    //console.log('RIGHT BUTTON CLICKED')
                    root.showSubtitleClipMenu()
                }
            }
            onDoubleClicked: {
                subtitleBase.textEditBegin = true
            }
        }
    Item {
        id: subtitleBase
        property bool textEditBegin: false
        height: subtitleTrack.height
        width: duration * timeScale // to make width change wrt timeline scale factor
        x: startFrame * timeScale;
        clip: true
        TextField {
            id: subtitleEdit
            font: miniFont
            activeFocusOnPress: true
            selectByMouse: true
            onEditingFinished: {
                subtitleEdit.focus = false
                parent.textEditBegin = false
                if (subtitleRoot.subtitle != subtitleEdit.text) {
                    timeline.editSubtitle(subtitleBase.x / timeline.scaleFactor, (subtitleBase.x + subtitleBase.width)/ timeline.scaleFactor, subtitleEdit.text, subtitleRoot.subtitle)
                }
            }
            anchors.fill: parent
            //visible: timeScale >= 6
            enabled: parent.textEditBegin
            onEnabledChanged: {
                if (enabled) {
                    selectAll()
                    focus = true
                    forceActiveFocus()
                }
            }
            text: subtitleRoot.subtitle
            height: subtitleBase.height
            width: subtitleBase.width
            wrapMode: TextField.WordWrap
            horizontalAlignment: displayText == text ? TextInput.AlignHCenter : TextInput.AlignLeft
            background: Rectangle {
                color: enabled ? "#fff" : '#ccccff'
                border {
                    color: subtitleRoot.selected ? root.selectionColor : "#000"
                    width: 2
                }
            }
            color: 'black'
            padding: 0
        }
    }
    Item {
        // start position resize handle
        id: leftstart
        width: root.baseUnit / 2
        height: subtitleBase.height
        anchors.top: subtitleBase.top
        anchors.left: subtitleBase.left
        visible: true
        MouseArea {
            // Right resize handle to change end timing
            id: startMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: true
            visible: root.activeTool === 0
            property int newStart: subtitleRoot.startFrame
            property int newDuration: subtitleRoot.duration
            property int originalDuration: subtitleRoot.duration
            property int oldMouseX
            property int oldStartFrame: 0
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeHorCursor
            drag.axis: Drag.XAxis
            drag.smoothed: false
            drag.target: leftstart
            onPressed: {
                root.autoScrolling = false
                oldMouseX = mouseX
                leftstart.anchors.left = undefined
                oldStartFrame = subtitleRoot.startFrame // the original start frame of subtitle
                originalDuration = subtitleRoot.duration
                newDuration = subtitleRoot.duration
                trimIn.opacity = 0
            }
            onPositionChanged: {
                if (pressed) {
                    newDuration = subtitleRoot.endFrame - Math.round(leftstart.x / timeScale)
                    if (newDuration != originalDuration && subtitleBase.x >= 0) {
                        var frame = controller.requestItemResize(subId, newDuration , false, false, root.snapping);
                        if (frame > 0) {
                            newStart = subtitleRoot.endFrame - frame
                        }
                    }
                }
            }
            onReleased: {
                //console.log('its RELEASED')
                root.autoScrolling = timeline.autoScroll
                leftstart.anchors.left = subtitleBase.left
                if (oldStartFrame != newStart) {
                    controller.requestItemResize(subId, subtitleRoot.endFrame - oldStartFrame, false, false);
                    controller.requestItemResize(subId, subtitleRoot.endFrame - newStart, false, true);
                }
            }
            onEntered: {
                if (!pressed) {
                    trimIn.opacity = 1
                }
            }
            onExited: trimIn.opacity = 0

            Rectangle {
                id: trimIn
                anchors.left: parent.left
                width: 2
                height: parent.height
                color: 'lawngreen'
                opacity: 0
                Drag.active: startMouseArea.drag.active
                Drag.proposedAction: Qt.MoveAction
                //visible: startMouseArea.pressed
            }
        }
    }
    
    Item {
        // end position resize handle
        id: rightend
        width: root.baseUnit / 2
        height: subtitleBase.height
        //x: subtitleRoot.endFrame * timeScale
        anchors.right: subtitleBase.right
        anchors.top: subtitleBase.top
        //Drag.active: endMouseArea.drag.active
        //Drag.proposedAction: Qt.MoveAction
        visible: true
        MouseArea {
            id: endMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: true
            visible: root.activeTool === 0
            property bool sizeChanged: false
            property int oldMouseX
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeHorCursor
            property int newDuration: subtitleRoot.duration
            property int originalDuration
            drag.target: rightend
            drag.axis: Drag.XAxis
            //drag.smoothed: false

            onPressed: {
                root.autoScrolling = false
                newDuration = subtitleRoot.duration
                originalDuration = subtitleRoot.duration
                //rightend.anchors.right = undefined
                oldMouseX = mouseX
                trimOut.opacity = 0
            }
            onPositionChanged: {
                if (pressed) {
                    if ((mouseX != oldMouseX && duration > 1) || (duration <= 1 && mouseX > oldMouseX)) {
                        sizeChanged = true
                        //duration = subtitleBase.width + (mouseX - oldMouseX)/ timeline.scaleFactor
                        newDuration = Math.round((subtitleBase.width + mouseX - oldMouseX)/timeScale)
                        // Perform resize without changing model
                        var frame = controller.requestItemResize(subId, newDuration , true, false, root.snapping);
                        if (frame > 0) {
                            newDuration = frame
                        }
                    }
                }
            }
            onReleased: {
                root.autoScrolling = timeline.autoScroll
                rightend.anchors.right = subtitleBase.right
                console.log(' GOT RESIZE: ', newDuration, ' > ', originalDuration)
                if (mouseX != oldMouseX || sizeChanged) {
                    // Restore original size
                    controller.requestItemResize(subId, originalDuration , true, false);
                    // Perform real resize
                    controller.requestItemResize(subId, newDuration , true, true)
                    sizeChanged = false
                }
            }
            onEntered: {
                console.log('ENTER MOUSE END AREA')
                if (!pressed) {
                    trimOut.opacity = 1
                }
            }
            onExited: trimOut.opacity = 0

            Rectangle {
                id: trimOut
                anchors.right: parent.right
                width: 2
                height: parent.height
                color: 'red'
                opacity: 0
                Drag.active: endMouseArea.drag.active
                Drag.proposedAction: Qt.MoveAction
                //visible: endMouseArea.pressed
            }
        }
    }
}
