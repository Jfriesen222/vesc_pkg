import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0
import Vedder.vesc.utility 1.0

Item {
    id: container
    anchors.fill: parent
    anchors.margins: 10

    property Commands mCommands: VescIf.commands()
    property int section: 0

    // Colors of the refreshed VESC Tool, or the closest older ones where the running VESC Tool does
    // not have them, as it gives red for names it does not know
    function themeColor(name, fallback) {
        var c = Utility.getAppHexColor(name)
        return c === "#ff0000" ? Utility.getAppHexColor(fallback) : c
    }

    readonly property color colCard: themeColor("cardBackground", "normalBackground")
    readonly property color colBorder: themeColor("raisedBackground", "lightBackground")
    readonly property color colText: themeColor("titleText", "lightText")
    readonly property color colLabel: Utility.getAppHexColor("normalText")

    // The parts below look like the VESC Tool settings pages. They are defined here rather than taken
    // from VESC Tool, as the versions before its refreshed UI do not have them.

    // Title above a group of settings
    component SectionTitle: RowLayout {
        property alias text: label.text

        Layout.fillWidth: true
        Layout.topMargin: 10
        spacing: 10

        Text {
            id: label
            color: Utility.getAppHexColor("lightAccent")
            font.family: "Exan"
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Utility.getAppHexColor("lightAccent")
            opacity: 0.3
        }
    }

    // Settings drawn as one card, with a line between them
    component Group: Rectangle {
        default property alias rows: rowColumn.data

        Layout.fillWidth: true
        implicitHeight: rowColumn.implicitHeight
        radius: 12
        color: colCard
        border.color: colBorder

        ColumnLayout {
            id: rowColumn
            width: parent.width
            spacing: 0
        }
    }

    // A setting in a Group, with its name on the left and its value, or a control such as a switch, on
    // the right. Tapping it opens its editor below it.
    component SettingRow: Item {
        id: row

        property string label: ""
        property string value: ""
        property Item control: null
        property bool chevron: false
        property bool expanded: false
        default property alias editor: editorColumn.data
        readonly property bool editable: editorColumn.children.length > 0

        Layout.fillWidth: true
        implicitHeight: header.height + (expanded ? editorColumn.implicitHeight + 12 : 0)
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        onControlChanged: {
            if (control) {
                control.parent = holder
            }
        }

        // One open at a time
        onExpandedChanged: {
            if (expanded && parent) {
                for (var i = 0; i < parent.children.length; i++) {
                    var r = parent.children[i]
                    if (r !== row && r.editable !== undefined && r.expanded) {
                        r.expanded = false
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            visible: row.y > 0
            color: colBorder
        }

        Item {
            id: header
            width: parent.width
            height: Math.max(52, headerRow.implicitHeight + 12)

            MouseArea {
                anchors.fill: parent
                enabled: row.editable
                onClicked: row.expanded = !row.expanded
            }

            RowLayout {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: row.label
                    wrapMode: Text.Wrap
                    color: colText
                    font.weight: row.expanded ? Font.Medium : Font.Normal
                }

                Text {
                    Layout.maximumWidth: row.width * 0.45
                    visible: row.control === null && text !== ""
                    text: row.value
                    elide: Text.ElideRight
                    color: colText
                    font.weight: Font.Medium
                }

                Item {
                    id: holder
                    implicitWidth: row.control ? row.control.implicitWidth : 0
                    implicitHeight: row.control ? row.control.implicitHeight : 0
                    visible: row.control !== null
                }

                Text {
                    visible: row.chevron
                    text: "›"
                    rotation: row.expanded ? 90 : 0
                    font.pointSize: 18
                    color: Utility.getAppHexColor("disabledText")
                }
            }
        }

        ColumnLayout {
            id: editorColumn
            x: 14
            y: header.height
            width: parent.width - 26
            visible: row.expanded || row.height > header.height + 1
        }
    }

    // Background that styles ComboBox, SpinBox and TextField like the cards
    component InputBackground: Rectangle {
        implicitWidth: parent instanceof SpinBox ? 140 : 120
        implicitHeight: 48
        radius: 12
        color: colCard
        border.color: parent.activeFocus ? Material.accent : colBorder
    }

    // Help text under a group
    component Note: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        wrapMode: Text.WordWrap
        color: colLabel
        font.pointSize: 10
    }

    // Section switcher: tap only, like the chips on the VESC Tool settings pages. It wraps instead of scrolling
    // sideways, so that a sideways swipe always reaches the VESC Tool pages around the package.
    component SectionChips: Flow {
        id: chips

        property var model: []
        property int currentIndex: 0
        // dots[i] === true shows a dot on chip i
        property var dots: []

        signal chosen(int index)

        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: chips.model

            AbstractButton {
                id: chip

                readonly property bool on: index === chips.currentIndex

                text: modelData
                focusPolicy: Qt.NoFocus
                // 44 pt touch target around the 32 pt pill
                topInset: 6
                bottomInset: 6
                leftPadding: 12
                rightPadding: 12
                implicitHeight: 44
                implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
                Accessible.role: Accessible.PageTab
                Accessible.name: text
                onClicked: chips.chosen(index)

                contentItem: Item {
                    implicitWidth: chipRow.implicitWidth
                    implicitHeight: chipRow.implicitHeight

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            id: chipLabel
                            anchors.verticalCenter: parent.verticalCenter
                            // As wide as the selected label, so that selecting does not move the chips after it
                            width: Math.ceil(Math.max(implicitWidth, selectedMetrics.advanceWidth))
                            horizontalAlignment: Text.AlignHCenter
                            text: chip.text
                            color: chip.on ? colText : colLabel
                            font.weight: chip.on ? Font.Medium : Font.Normal

                            TextMetrics {
                                id: selectedMetrics
                                font.family: chipLabel.font.family
                                font.pointSize: chipLabel.font.pointSize
                                font.weight: Font.Medium
                                text: chip.text
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            visible: chips.dots[index] === true
                            color: Material.accent
                        }
                    }
                }

                background: Rectangle {
                    radius: height / 2
                    color: chip.on ? Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.12) : colCard
                    border.width: chip.on ? 1.5 : 1
                    border.color: chip.on ? Material.accent : colBorder
                }
            }
        }
    }

    Component.onCompleted: {
        if (VescIf.getLastFwRxParams().hw.includes("Express")) {
            canId.value = -2
        }

        sendCode("(send-settings)")
        sendCode("(send-modes)")
    }

    ColumnLayout {
        anchors.fill: parent

        Text {
            Layout.fillWidth: true
            color: colText
            font.pointSize: 15
            font.weight: Font.Medium
            text: "Dash ESC"
        }

        SectionChips {
            model: ["Logging", "Modes"]
            currentIndex: section
            onChosen: function(index) { section = index }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: section
            clip: true

            Page {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    // A Flickable rather than a ScrollView, so that scrolling glides
                    Flickable {
                        id: logScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        contentWidth: width
                        contentHeight: logScrollCol.height + 10
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            interactive: Qt.platform.os !== "ios" && Qt.platform.os !== "android"
                        }

                        ColumnLayout {
                            id: logScrollCol
                            y: 10
                            // Clear of the scroll bar
                            width: logScroll.width - logScroll.ScrollBar.vertical.implicitWidth - 4
                            spacing: 10

                            SectionTitle {
                                Layout.topMargin: 0
                                text: "Data to Log"
                            }

                            Group {
                                SettingRow {
                                    label: "GNSS"
                                    control: Switch {
                                        id: gnssLog
                                    }
                                }

                                SettingRow {
                                    label: "Local Values"
                                    control: Switch {
                                        id: localLog
                                        checked: true
                                    }
                                }

                                SettingRow {
                                    label: "CAN Values"
                                    control: Switch {
                                        id: canLog
                                    }
                                }

                                SettingRow {
                                    label: "BMS Values"
                                    control: Switch {
                                        id: bmsLog
                                    }
                                }
                            }

                            SectionTitle {
                                text: "Logger"
                            }

                            Group {
                                SettingRow {
                                    label: "Logger CAN ID"
                                    value: canId.value

                                    SpinBox {
                                        id: canId
                                        Layout.fillWidth: true
                                        background: InputBackground {}
                                        from: -2
                                        to: 254
                                        value: 2
                                    }
                                }

                                SettingRow {
                                    label: "Log Rate"
                                    value: parseFloat(logRate.realValue).toFixed(0) + " Hz"

                                    DoubleSpinBox {
                                        id: logRate
                                        Layout.fillWidth: true
                                        realFrom: 1
                                        realTo: 200
                                        realValue: 10
                                        decimals: 0
                                        suffix: " Hz"
                                    }
                                }

                                SettingRow {
                                    label: "Start logging at boot"
                                    control: Switch {
                                        id: startAtBoot
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: logScroll.ScrollBar.vertical.implicitWidth + 4

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 500
                            text: "Start Log"

                            onClicked: {
                                var cmd = "(start-log " + makeArgStr() + ")"
                                sendCode(cmd)
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 500
                            text: "Stop Log"

                            onClicked: {
                                sendCode("(stop-log " + canId.value + ")")
                            }
                        }
                    }
                }
            }

            Page {
                // A Flickable rather than a ScrollView, so that scrolling glides
                Flickable {
                    id: profileScroll
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: scrollCol.height + 10
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        interactive: Qt.platform.os !== "ios" && Qt.platform.os !== "android"
                    }

                    ColumnLayout {
                        id: scrollCol
                        y: 10
                        // Clear of the scroll bar
                        width: profileScroll.width - profileScroll.ScrollBar.vertical.implicitWidth - 4
                        spacing: 10

                        SectionTitle {
                            Layout.topMargin: 0
                            text: "Servicing"
                        }

                        Note {
                            text: "Drive profiles scale the motor current, and anything measured " +
                                  "with current is wrong while a scale is applied. Suspend them before " +
                                  "detecting a motor or writing configuration, so the controller's own " +
                                  "limits are the live ones. This turns itself off at the next power " +
                                  "cycle, and the displays show SERVICE while it is on: there is no mode " +
                                  "limiting and neutral does not hold the throttle shut."
                        }

                        Group {
                            SettingRow {
                                label: "Suspend drive profiles"
                                control: Switch {
                                    id: suspendBox
                                    onClicked: sendCode("(profile-suspend-set " + (checked ? 1 : 0) + ")")
                                }
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            text: "Capture these limits as the baseline"
                            enabled: suspendBox.checked
                            onClicked: sendCode("(limits-capture)")
                        }

                        Note {
                            text: "Press this once the controller is configured the way you want it. " +
                                  "Those limits are what gets put back whenever the displays are unplugged " +
                                  "or the profile is suspended."
                        }

                        SectionTitle {
                            text: "Throttle Mode"
                        }

                        Group {
                            SettingRow {
                                label: "Throttle input"
                                value: thrModeBox.currentText
                                chevron: true

                                ComboBox {
                                    id: thrModeBox
                                    Layout.fillWidth: true
                                    background: InputBackground {}
                                    model: ["ADC1", "ADC2"]
                                    currentIndex: 0
                                }
                            }
                        }

                        SectionTitle {
                            text: "Reverse"
                        }

                        Group {
                            SettingRow {
                                label: "Speed"
                                value: parseFloat(modeRSpeed.realValue).toFixed(1) + " km/h"

                                DoubleSpinBox {
                                    id: modeRSpeed
                                    Layout.fillWidth: true
                                    realFrom: 0.5
                                    realTo: 250.0
                                    realValue: 15.0
                                    decimals: 1
                                    suffix: " km/h"
                                }
                            }

                            SettingRow {
                                label: "Current"
                                value: parseFloat(modeRCurrent.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: modeRCurrent
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }

                            SettingRow {
                                label: "Brake"
                                value: parseFloat(modeRCurrentBrake.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: modeRCurrentBrake
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }
                        }

                        SectionTitle {
                            text: "Neutral"
                        }

                        Group {
                            SettingRow {
                                label: "Brake"
                                value: parseFloat(modeNCurrentBrake.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: modeNCurrentBrake
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }
                        }

                        SectionTitle {
                            text: "Mode 1"
                        }

                        Group {
                            SettingRow {
                                label: "Speed"
                                value: parseFloat(mode1Speed.realValue).toFixed(1) + " km/h"

                                DoubleSpinBox {
                                    id: mode1Speed
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 250.0
                                    realValue: 20.0
                                    decimals: 1
                                    suffix: " km/h"
                                }
                            }

                            SettingRow {
                                label: "Current"
                                value: parseFloat(mode1Current.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: mode1Current
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 50.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }

                            SettingRow {
                                label: "Brake"
                                value: parseFloat(mode1CurrentBrake.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: mode1CurrentBrake
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }
                        }

                        SectionTitle {
                            text: "Mode 2"
                        }

                        Group {
                            SettingRow {
                                label: "Speed"
                                value: parseFloat(mode2Speed.realValue).toFixed(1) + " km/h"

                                DoubleSpinBox {
                                    id: mode2Speed
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 250.0
                                    realValue: 25.0
                                    decimals: 1
                                    suffix: " km/h"
                                }
                            }

                            SettingRow {
                                label: "Current"
                                value: parseFloat(mode2Current.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: mode2Current
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 60.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }

                            SettingRow {
                                label: "Brake"
                                value: parseFloat(mode2CurrentBrake.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: mode2CurrentBrake
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }
                        }

                        SectionTitle {
                            text: "Mode 3"
                        }

                        Group {
                            SettingRow {
                                label: "Speed"
                                value: parseFloat(mode3Speed.realValue).toFixed(1) + " km/h"

                                DoubleSpinBox {
                                    id: mode3Speed
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 250.0
                                    realValue: 250.0
                                    decimals: 1
                                    suffix: " km/h"
                                }
                            }

                            SettingRow {
                                label: "Current"
                                value: parseFloat(mode3Current.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: mode3Current
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }

                            SettingRow {
                                label: "Brake"
                                value: parseFloat(mode3CurrentBrake.realValue).toFixed(0) + " %"

                                DoubleSpinBox {
                                    id: mode3CurrentBrake
                                    Layout.fillWidth: true
                                    realFrom: 0.0
                                    realTo: 100.0
                                    realValue: 100.0
                                    decimals: 0
                                    realStepSize: 10.0
                                    suffix: " %"
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 500

                text: "Read Config"

                onClicked: {
                    sendCode("(send-settings)")
                    sendCode("(send-modes)")
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 500

                text: "Save Config"

                onClicked: {
                    sendCode(
                    "(save-config " + makeArgStr() + " " +
                    startAtBoot.checked + " " +
                    parseFloat(thrModeBox.currentIndex + 2).toFixed(0) + ")"
                    )
                    sendCode("(save-modes " + makeModeStr() + ")")
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 500

                text: "Defaults"

                onClicked: {
                    sendCode("(restore-settings)")
                    sendCode("(send-settings)")
                    sendCode("(send-modes)")
                }
            }
        }
    }

    function makeModeStr() {
        return "" +
        parseFloat(modeRSpeed.realValue).toFixed(1) + " " +
        parseFloat(modeRCurrent.realValue / 100.0).toFixed(2) + " " +
        parseFloat(modeRCurrentBrake.realValue / 100.0).toFixed(2) + " " +
        parseFloat(modeNCurrentBrake.realValue / 100.0).toFixed(2) + " " +
        parseFloat(mode1Speed.realValue).toFixed(1) + " " +
        parseFloat(mode1Current.realValue / 100.0).toFixed(2) + " " +
        parseFloat(mode1CurrentBrake.realValue / 100.0).toFixed(2) + " " +
        parseFloat(mode2Speed.realValue).toFixed(1) + " " +
        parseFloat(mode2Current.realValue / 100.0).toFixed(2) + " " +
        parseFloat(mode2CurrentBrake.realValue / 100.0).toFixed(2) + " " +
        parseFloat(mode3Speed.realValue).toFixed(1) + " " +
        parseFloat(mode3Current.realValue / 100.0).toFixed(2) + " " +
        parseFloat(mode3CurrentBrake.realValue / 100.0).toFixed(2)
    }

    function makeArgStr() {
        return "" +
        canId.value + " " +
        gnssLog.checked + " " +
        localLog.checked + " " +
        canLog.checked + " " +
        bmsLog.checked + " " +
        parseFloat(logRate.realValue).toFixed(2)
    }

    function sendCode(str) {
        mCommands.sendCustomAppData(str + "\0") // Append null to ensure that the string is null-terminated
    }

    Connections {
        target: mCommands

        function onCustomAppDataReceived(data) {
            var str = data.toString()

            if (str.startsWith("settings")) {
                var tokens = str.split(" ")
                canId.value = Number(tokens[1])
                startAtBoot.checked = Number(tokens[2])
                logRate.realValue = Number(tokens[3])
                gnssLog.checked = Number(tokens[4])
                localLog.checked = Number(tokens[5])
                canLog.checked = Number(tokens[6])
                bmsLog.checked = Number(tokens[7])
                thrModeBox.currentIndex = Number(tokens[8]) - 2
                } else if (str.startsWith("msg ")) {
                var msg = str.substring(4)
                VescIf.emitMessageDialog("Logger", msg, false, false)
            }
            else if (str.startsWith("modes")) {
                var tokens = str.split(" ")
                modeRSpeed.realValue = Number(tokens[1])
                modeRCurrent.realValue = Number(tokens[2]) * 100.0
                modeRCurrentBrake.realValue = Number(tokens[3]) * 100.0

                modeNCurrentBrake.realValue = Number(tokens[4]) * 100.0

                mode1Speed.realValue = Number(tokens[5])
                mode1Current.realValue = Number(tokens[6]) * 100.0
                mode1CurrentBrake.realValue = Number(tokens[7]) * 100.0

                mode2Speed.realValue = Number(tokens[8])
                mode2Current.realValue = Number(tokens[9]) * 100.0
                mode2CurrentBrake.realValue = Number(tokens[10]) * 100.0

                mode3Speed.realValue = Number(tokens[11])
                mode3Current.realValue = Number(tokens[12]) * 100.0
                mode3CurrentBrake.realValue = Number(tokens[13]) * 100.0
                }
            else if (str.startsWith("msg ")) {
                var msg = str.substring(4)
                VescIf.emitMessageDialog("Logger", msg, false, false)
            }
            else {
                VescIf.emitStatusMessage(str, true)
            }
        }
    }

    Dialog {
        id: commDialog
        title: "Processing..."
        closePolicy: Popup.NoAutoClose
        modal: true
        focus: true

        width: parent.width - 20
        x: 10
        y: parent.height / 2 - height / 2
        parent: container

        ProgressBar {
            anchors.fill: parent
            indeterminate: visible
        }
    }
}
