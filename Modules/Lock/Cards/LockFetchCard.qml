import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services

Rectangle {
    id: root

    property int detailLevel: 3
    readonly property string systemUser: SystemIdentityService.accountName
    readonly property string hostName: SystemIdentityService.hostName
    readonly property string distroId: SystemIdentityService.distroId
    readonly property int sidePadding: detailLevel <= 1 ? Metrics.lockOuterPadding : Metrics.lockOuterPadding * 2
    readonly property int topPadding: Metrics.lockOuterPadding
    readonly property int bottomPadding: detailLevel <= 1 ? Metrics.lockOuterPadding : Metrics.lockOuterPadding * 2
    readonly property int promptSize: 45
    // ЛОКАЛЬНАЯ ПРАВКА: третья, узкая ступень. На экране 1536×864 карточка
    // шириной ~200 px, и на значение («Ubuntu 24.04 LTS») оставалось 70 px.
    readonly property bool narrow: width < 260
    readonly property int fetchFontSize: width >= 533 ? 20 : narrow ? 14 : 17
    readonly property int headerFontSize: width >= 533 ? 20 : narrow ? 14 : 17
    readonly property int lineHeight: width >= 533 ? 31 : narrow ? 22 : 27
    readonly property int lineLabelWidth: width >= 533 ? 61 : narrow ? 42 : 53
    readonly property int lineIconSize: narrow ? 18 : 24
    readonly property int bodySpacing: Math.max(18, Math.min(32, Math.floor(bodyRow.height * 0.15)))
    readonly property int contentWidth: Math.max(0, width - sidePadding * 2)
    readonly property int logoColumnWidth: Math.max(118, Math.floor(contentWidth * 0.42))
    readonly property int infoColumnWidth: Math.max(0, contentWidth - (root.width >= 300 ? logoColumnWidth + bodySpacing : 0))

    function distroLogo() {
        const id = String(root.distroId || "").toLowerCase();
        const logos = {
            "arch": "󰣇",
            "archlinux": "󰣇",
            "endeavouros": "",
            "manjaro": "",
            "fedora": "",
            "ubuntu": "",
            "debian": "",
            "opensuse": "",
            "nixos": "",
            "gentoo": "",
            "void": ""
        };
        return logos[id] || "";
    }

    function paletteModel() {
        const colors = [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colPrimaryContainer, Appearance.colors.colSecondaryContainer, Appearance.colors.colTertiaryContainer, Appearance.colors.colPrimary, Appearance.colors.colSecondary];
        const count = Math.max(0, Math.min(8, Math.floor(root.infoColumnWidth / 34)));
        return colors.slice(0, count);
    }

    implicitHeight: contentLayout.implicitHeight + topPadding + bottomPadding
    color: Appearance.colors.colLayer2
    radius: Metrics.lockCardRadius
    clip: true

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.leftMargin: root.sidePadding
        anchors.rightMargin: root.sidePadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: root.detailLevel > 0
            spacing: 12

            Rectangle {
                Layout.preferredWidth: root.promptSize
                Layout.preferredHeight: root.promptSize
                color: Appearance.colors.colPrimary
                radius: Metrics.lockCardRadiusSmall

                Text {
                    anchors.centerIn: parent
                    text: ">"
                    color: Appearance.colors.colOnPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: root.headerFontSize
                    font.bold: true
                }

            }

            Text {
                Layout.fillWidth: true
                text: "fastfetch"
                color: Appearance.colors.colOnSurface
                font.family: Fonts.numeric
                font.pixelSize: root.headerFontSize
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

        }

        RowLayout {
            id: bodyRow

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.bodySpacing

            Item {
                Layout.preferredWidth: root.logoColumnWidth
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                visible: root.detailLevel >= 2 && root.width >= 300

                Text {
                    anchors.centerIn: parent
                    text: root.distroLogo()
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: Math.floor(Math.min(parent.width, parent.height) * 0.94)
                    font.bold: true
                }

            }

            ColumnLayout {
                id: fetchColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: root.width >= 300 ? 0 : Math.floor(root.width * 0.1)
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.systemUser + "@" + root.hostName
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: root.fetchFontSize
                    font.bold: true
                    // Не влезает — переносим, а не обрезаем многоточием.
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    Layout.topMargin: 1
                    Layout.bottomMargin: 2
                    radius: 1
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.45
                }

                FetchLine {
                    icon: "desktop_windows"
                    label: "OS"
                    value: SystemIdentityService.distroName
                    accent: Appearance.colors.colPrimary
                    visible: root.detailLevel >= 1
                }

                FetchLine {
                    icon: "window"
                    label: "WM"
                    value: SystemIdentityService.wmName
                    accent: Appearance.colors.colSecondary
                    visible: root.detailLevel >= 1
                }

                FetchLine {
                    icon: "person"
                    label: "USER"
                    value: root.systemUser
                    accent: Appearance.colors.colTertiary
                }

                FetchLine {
                    icon: "schedule"
                    label: "UP"
                    value: SystemIdentityService.uptimeText
                    accent: Appearance.colors.colSecondary
                }

                FetchLine {
                    icon: "memory"
                    label: "KERN"
                    value: SystemIdentityService.kernelRelease
                    accent: Appearance.colors.colPrimary
                    visible: root.detailLevel >= 2
                }

                FetchLine {
                    icon: "terminal"
                    label: "SH"
                    value: SystemIdentityService.shellName
                    accent: Appearance.colors.colTertiary
                    visible: root.detailLevel >= 2
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    visible: root.detailLevel >= 3
                    spacing: 8

                    Repeater {
                        model: root.paletteModel()

                        Rectangle {
                            required property var modelData

                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 18
                            radius: 7
                            color: modelData
                        }

                    }

                }

            }

        }

    }

    component FetchLine: RowLayout {
        id: line

        property string icon: ""
        property string label: ""
        property string value: ""
        property color accent: Appearance.colors.colPrimary

        // Высоту RowLayout считает сам: не меньше lineHeight (значок и метка),
        // больше — если значение перенеслось на вторую строку.
        spacing: root.narrow ? 5 : 7

        Text {
            Layout.preferredWidth: root.lineIconSize
            Layout.preferredHeight: root.lineHeight
            Layout.alignment: Qt.AlignTop
            text: line.icon
            color: line.accent
            font.family: Fonts.materialSymbolsOutlined
            font.pixelSize: root.lineIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            Layout.preferredWidth: root.lineLabelWidth
            Layout.preferredHeight: root.lineHeight
            Layout.alignment: Qt.AlignTop
            verticalAlignment: Text.AlignVCenter
            text: line.label + ":"
            color: line.accent
            font.family: Fonts.numeric
            font.pixelSize: root.fetchFontSize
            font.bold: true
            elide: Text.ElideRight
        }

        // Длинное значение переносится на вторую строку, дальше — многоточие.
        Text {
            id: valueText

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Math.max(0, (root.lineHeight - fontMetrics.height) / 2)
            text: line.value || "--"
            color: Appearance.colors.colOnSurface
            font.family: Fonts.numeric
            font.pixelSize: root.fetchFontSize
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight

            FontMetrics {
                id: fontMetrics

                font: valueText.font
            }
        }

    }

}
