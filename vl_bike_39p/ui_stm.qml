import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import Vedder.vesc.utility 1.0

import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0

Item {
    id: appPage

    anchors.fill: parent
    anchors.margins: 10

    property Commands mCommands: VescIf.commands()
    property ConfigParams mMcConf: VescIf.mcConfig()
    property ConfigParams mInfoConf: VescIf.infoConfig()
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
        updateEditors()
        sendCode("(send-settings)")
    }

    ParamEditors {
        id: editors
    }

    function addSeparator(text) {
        var e = editors.createSeparator(scrollCol, text)
        e.Layout.columnSpan = 1
    }

    function addSeparatorMc(text) {
        var e = editors.createSeparator(scrollColMc, text)
        e.Layout.columnSpan = 1
    }

    function destroyEditors() {
        for(var i = scrollCol.children.length;i > 0;i--) {
            scrollCol.children[i - 1].destroy(1) // Only works with delay on android, seems to be a bug
        }

        for(var i = scrollColMc.children.length;i > 0;i--) {
            scrollColMc.children[i - 1].destroy(1) // Only works with delay on android, seems to be a bug
        }
    }

    function createEditorApp(param) {
        var e = editors.createEditorApp(scrollCol, param)
        e.Layout.preferredWidth = 500
        e.Layout.fillsWidth = true
    }

    function createEditorMc(param) {
        var e = editors.createEditorMc(scrollColMc, param)
        e.Layout.preferredWidth = 500
        e.Layout.fillsWidth = true
    }

    function updateEditors() {
        destroyEditors()

        var params = VescIf.appConfig().getParamsFromSubgroup("VESC Remote", "General")

        for (var i = 0;i < params.length;i++) {
            if (params[i].startsWith("::sep::")) {
                addSeparator(params[i].substr(7))
                } else {
                createEditorApp(params[i])
            }
        }

        params = VescIf.mcConfig().getParamsFromSubgroup("Additional Info", "Setup")

        for (var i = 0;i < params.length;i++) {
            if (params[i].startsWith("::sep::")) {
                addSeparatorMc(params[i].substr(7))
                } else {
                createEditorMc(params[i])
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent

        Text {
            Layout.fillWidth: true
            color: colText
            font.pointSize: 15
            font.weight: Font.Medium
            text: "VL Bike 39P STM"
        }

        SectionChips {
            model: ["Start", "Detect", "Input", "Controls", "Vehicle"]
            currentIndex: section
            onChosen: function(index) { section = index }
        }

        StackLayout {
            currentIndex: section
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true

            Page {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    SectionTitle {
                        text: "Logging"
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: "Start Logging"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 500

                            onClicked: {
                                sendCode("(start-log-defaults)")
                            }
                        }

                        Button {
                            text: "Stop Logging"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 500

                            onClicked: {
                                sendCode("(stop-log last-can-id)")
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            Page {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    SectionTitle {
                        text: "Motor Setup"
                    }

                    Group {
                        SettingRow {
                            label: "Encoder"
                            value: encoderBox.currentText.replace("Encoder: ", "")
                            chevron: true

                            ComboBox {
                                id: encoderBox
                                Layout.fillWidth: true
                                background: InputBackground {}
                                model: [
                                "Encoder: Sensorless",
                                "Encoder: VESC Labs ABI Encoder",
                                ]
                                currentIndex: 1

                                onCurrentIndexChanged: {

                                }
                            }
                        }

                        SettingRow {
                            label: "Motor Current"
                            value: parseFloat(currMaxBox.realValue).toFixed(1) + " A"

                            DoubleSpinBox {
                                id: currMaxBox
                                Layout.fillWidth: true
                                suffix: " A"
                                decimals: 1
                                realFrom: 0.0
                                realTo: 1000
                                realValue: 550.0
                                realStepSize: 1
                            }
                        }

                        SettingRow {
                            label: "Detect Current"
                            value: parseFloat(currDetectBox.realValue).toFixed(1) + " A"

                            DoubleSpinBox {
                                id: currDetectBox
                                Layout.fillWidth: true
                                suffix: " A"
                                decimals: 1
                                realFrom: 0.0
                                realTo: 1000
                                realValue: 100.0
                                realStepSize: 1
                            }
                        }
                    }

                    Button {
                        text: "Configure IPM Motor"
                        Layout.fillWidth: true

                        onClicked: {
                            confIpmDialog.open()
                        }

                        Dialog {
                            id: confIpmDialog
                            parent: appPage
                            standardButtons: Dialog.Ok | Dialog.Cancel
                            modal: true
                            focus: true
                            width: parent.width - 20
                            closePolicy: Popup.CloseOnEscape
                            title: "Configure IPM Motor"

                            Overlay.modal: Rectangle {
                                color: "#AA000000"
                            }

                            x: 10
                            y: Math.max((parent.height - height) / 2, 10)

                            Text {
                                color: Utility.getAppHexColor("lightText")
                                verticalAlignment: Text.AlignVCenter
                                anchors.centerIn: parent
                                width: appPage.width - 80
                                wrapMode: Text.WordWrap
                                text:
                                "This is going to spin up the motor. Make " +
                                "sure that nothing is in the way!"
                            }

                            onAccepted: {
                                sendCode("(conf-start " +
                                    encoderBox.currentIndex + " " +
                                    parseFloat(currMaxBox.realValue).toFixed(2) + " " +
                                    parseFloat(currDetectBox.realValue).toFixed(2) + ")")
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            Page {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    // A Flickable rather than a ScrollView, so that scrolling glides
                    Flickable {
                        id: inputFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: column.height + 10
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            interactive: Qt.platform.os !== "ios" && Qt.platform.os !== "android"
                        }

                        ColumnLayout {
                            id: column
                            // Clear of the scroll bar
                            width: inputFlick.width - inputFlick.ScrollBar.vertical.implicitWidth - 4
                            spacing: 10

                            SectionTitle {
                                text: "Throttle and Brake"
                            }

                            Group {
                                SettingRow {
                                    label: "Throttle Min"
                                    value: parseFloat(thrMinBox.realValue).toFixed(2) + " V"

                                    DoubleSpinBox {
                                        id: thrMinBox
                                        Layout.fillWidth: true
                                        suffix: " V"
                                        decimals: 2
                                        realFrom: 0.0
                                        realTo: 3.3
                                        realValue: 0.58
                                        realStepSize: 0.01
                                    }
                                }

                                SettingRow {
                                    label: "Throttle Max"
                                    value: parseFloat(thrMaxBox.realValue).toFixed(2) + " V"

                                    DoubleSpinBox {
                                        id: thrMaxBox
                                        Layout.fillWidth: true
                                        suffix: " V"
                                        decimals: 2
                                        realFrom: 0.0
                                        realTo: 3.3
                                        realValue: 2.8
                                        realStepSize: 0.01
                                    }
                                }

                                SettingRow {
                                    label: "Brake Min"
                                    value: parseFloat(brkMinBox.realValue).toFixed(2) + " V"

                                    DoubleSpinBox {
                                        id: brkMinBox
                                        Layout.fillWidth: true
                                        suffix: " V"
                                        decimals: 2
                                        realFrom: 0.0
                                        realTo: 3.3
                                        realValue: 0.58
                                        realStepSize: 0.01
                                    }
                                }

                                SettingRow {
                                    label: "Brake Max"
                                    value: parseFloat(brkMaxBox.realValue).toFixed(2) + " V"

                                    DoubleSpinBox {
                                        id: brkMaxBox
                                        Layout.fillWidth: true
                                        suffix: " V"
                                        decimals: 2
                                        realFrom: 0.0
                                        realTo: 3.3
                                        realValue: 2.8
                                        realStepSize: 0.01
                                    }
                                }

                                SettingRow {
                                    label: "Use Brake"
                                    control: Switch {
                                        id: useBrkBox
                                    }
                                }
                            }

                            SectionTitle {
                                text: "Live"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 0.5

                                CustomGauge {
                                    id: throttleGauge
                                    Layout.fillWidth: true
                                    //Layout.preferredWidth: parent.width * 0.45
                                    Layout.preferredHeight: width
                                    maximumValue: 4
                                    minimumValue: 0
                                    tickmarkScale: 1
                                    tickmarkSuffix: "V"
                                    labelStep: 1
                                    precision: 2
                                    value: 0
                                    unitText: "V"
                                    typeText: "Throttle"
                                }

                                CustomGauge {
                                    id: brakeGauge
                                    Layout.fillWidth: true
                                    //Layout.preferredWidth: parent.width * 0.45
                                    Layout.preferredHeight: width
                                    maximumValue: 4
                                    minimumValue: 0
                                    tickmarkScale: 1
                                    tickmarkSuffix: "V"
                                    labelStep: 1
                                    precision: 2
                                    value: 0
                                    unitText: "V"
                                    typeText: "Brake"
                                }

                                CustomGauge {
                                    id: outGauge
                                    Layout.fillWidth: true
                                    //Layout.preferredWidth: parent.width * 0.45
                                    Layout.preferredHeight: width
                                    maximumValue: 100
                                    minimumValue: -100
                                    tickmarkScale: 1
                                    tickmarkSuffix: "%"
                                    labelStep: 20
                                    precision: 0
                                    value: 0
                                    unitText: "%"
                                    typeText: "Output"
                                }
                            }

                            Group {
                                SettingRow {
                                    label: "Poll Voltage"
                                    control: Switch {
                                        id: pollVoltBox
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: inputFlick.ScrollBar.vertical.implicitWidth + 4
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 600
                            text: "Write"

                            onClicked: {
                                sendCode("(save-config " +
                                parseFloat(thrMinBox.realValue).toFixed(2) + " " +
                                parseFloat(thrMaxBox.realValue).toFixed(2) + " " +
                                parseFloat(brkMinBox.realValue).toFixed(2) + " " +
                                parseFloat(brkMaxBox.realValue).toFixed(2) + " " +
                                useBrkBox.checked +
                                ")"
                                )
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 600
                            text: "Read"

                            onClicked: {
                                sendCode("(send-settings)")
                            }
                        }
                    }
                }
            }

            Page {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Flickable {
                        id: appFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        contentWidth: width
                        contentHeight: scrollCol.height
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            interactive: Qt.platform.os !== "ios" && Qt.platform.os !== "android"
                        }

                        GridLayout {
                            id: scrollCol
                            // Clear of the scroll bar
                            width: appFlick.width - appFlick.ScrollBar.vertical.implicitWidth - 4
                            columns: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: appFlick.ScrollBar.vertical.implicitWidth + 4
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 600
                            text: "Write"

                            onClicked: {
                                mCommands.setAppConf()
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 600
                            text: "Read"

                            onClicked: {
                                mCommands.getAppConf()
                            }
                        }
                    }
                }
            }

            Page {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Flickable {
                        id: mcFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        contentWidth: width
                        contentHeight: scrollColMc.height
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            interactive: Qt.platform.os !== "ios" && Qt.platform.os !== "android"
                        }

                        GridLayout {
                            id: scrollColMc
                            // Clear of the scroll bar
                            width: mcFlick.width - mcFlick.ScrollBar.vertical.implicitWidth - 4
                            columns: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: mcFlick.ScrollBar.vertical.implicitWidth + 4
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 600
                            text: "Write"

                            onClicked: {
                                mCommands.setMcconf(true)
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 600
                            text: "Read"

                            onClicked: {
                                mCommands.getMcconf()
                            }
                        }
                    }
                }
            }
        }
    }

    function sendCode(str) {
        mCommands.sendCustomAppData(str + "\0") // Append null to ensure that the string is null-terminated
    }

    Timer {
        id: aliveTimer
        interval: 100
        running: true
        repeat: true

        onTriggered: {
            if (VescIf.isPortConnected()) {
                if (pollVoltBox.checked) {
                    sendCode("(send-adc)")
                }
            }
        }
    }

    Connections {
        target: mCommands

        function onCustomAppDataReceived(data) {
            var str = data.toString()

            if (str.startsWith("settings")) {
                var tokens = str.split(" ")
                thrMinBox.realValue = Number(tokens[1])
                thrMaxBox.realValue = Number(tokens[2])
                brkMinBox.realValue = Number(tokens[3])
                brkMaxBox.realValue = Number(tokens[4])
                useBrkBox.checked = tokens[5] == "1"
                VescIf.emitStatusMessage("Settings Received!", true)
            } else if (str.startsWith("volts")) {
                var tokens = str.split(" ")
                throttleGauge.value = Number(tokens[1])
                brakeGauge.value = Number(tokens[2])
                outGauge.value = Number(tokens[3]) * 100.0
            } else if (str.startsWith("msg ")) {
                var msg = str.substring(4)
                VescIf.emitMessageDialog("Maxim STM", msg, false, false)
                mCommands.getMcconf()
            } else {
                VescIf.emitStatusMessage(str, true)
            }
        }
    }
}
