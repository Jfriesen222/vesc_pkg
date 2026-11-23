import QtQuick 2.15
import QtQuick.Controls 2.12
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

    Component.onCompleted: {
        if (VescIf.getLastFwRxParams().hw.includes("Express")) {
            canId.value = -2
        }

        sendCode("(send-settings)")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            Layout.fillWidth: true
            color: colText
            font.pointSize: 15
            font.weight: Font.Medium
            text: "MT6701 Config"
        }

        SectionTitle {
            Layout.topMargin: 0
            text: "Encoder"
        }

        Group {
            SettingRow {
                label: "Pole Pairs"
                value: polePairs.value

                SpinBox {
                    id: polePairs
                    Layout.fillWidth: true
                    background: InputBackground {}
                    from: 1
                    to: 16
                    value: 4
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 500
                text: "Read"

                onClicked: {
                    sendCode("(read-encoder)")
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 500
                text: "Write"

                onClicked: {
                    var cmd = "(config-encoder " + polePairs.value + ")"
                    sendCode(cmd)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: Utility.getAppHexColor("darkBackground")
            border.color: colBorder

            ScrollView {
                id: scroll
                anchors.fill: parent
                anchors.margins: 4
                contentWidth: Math.max(terminalText.implicitWidth, availableWidth)
                clip: true

                TextArea {
                    id: terminalText
                    width: parent.width
                    readOnly: true
                    font.family: "DejaVu Sans Mono"
                    font.pointSize: 10
                    background: null
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredWidth: 500
            text: "Clear Terminal"

            onClicked: {
                terminalText.text = ""
            }
        }
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

            } else if (str.startsWith("msg ")) {
                var msg = str.substring(4)
                VescIf.emitMessageDialog("Logger", msg, false, false)
            } else {
                terminalText.text += "\n" + str
            }
        }
    }
}
