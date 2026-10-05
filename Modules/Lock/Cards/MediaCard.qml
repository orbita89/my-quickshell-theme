import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    property bool compact: false
    property var player: MediaManager.active
    property bool hasMedia: player !== null
    property bool isPlaying: player && player.isPlaying
    property string artUrl: (player && player.trackArtUrl) ? player.trackArtUrl : ""
    property string title: (player && player.trackTitle) ? player.trackTitle : qsTr("No media")
    property string artist: (player && player.trackArtist) ? player.trackArtist : qsTr("Not playing")

    // ЛОКАЛЬНАЯ ПРАВКА: кнопки и текст сжимаются под ширину карточки. На
    // экране 1536×864 внутри карточки ~250 px, а три кнопки занимали 302 —
    // «вперёд» обрезалась по краю. 302 = 69 + 20 + 124 + 20 + 69, где 124 —
    // кнопка воспроизведения с запасом под анимацию нажатия (64 + 20 + 40,
    // см. PlayPauseButton.implicitWidth).
    readonly property real controlScale: Math.max(0.5, Math.min(1, contentLayout.width / 302))
    readonly property bool narrow: controlScale < 1

    Layout.fillWidth: true
    implicitHeight: contentLayout.implicitHeight + Metrics.lockOuterPadding * 2
    color: Appearance.colors.colLayer2
    radius: Metrics.lockCardRadius
    clip: true
    layer.enabled: true

    Image {
        id: coverArt

        anchors.fill: parent
        source: root.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        smooth: true
        visible: false
    }

    Rectangle {
        id: coverMask

        anchors.fill: parent
        visible: false
        layer.enabled: true

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Appearance.applyAlpha(Appearance.colors.colScrim, 0.5)
            }

            GradientStop {
                position: 0.4
                color: Appearance.applyAlpha(Appearance.colors.colScrim, 0.2)
            }

            GradientStop {
                position: 0.8
                color: Appearance.applyAlpha(Appearance.colors.colScrim, 0)
            }
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: coverArt
        maskSource: coverMask
        opacity: coverArt.status === Image.Ready ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.standardExtraLarge.duration
                easing.type: Appearance.animation.standardExtraLarge.type
                easing.bezierCurve: Appearance.animation.standardExtraLarge.bezierCurve
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.hasMedia && coverArt.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: "music_note"
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.materialSymbolsRounded
            font.pixelSize: 48
            opacity: 0.2
        }
    }

    ColumnLayout {
        id: contentLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Metrics.lockOuterPadding
        spacing: 0

        Text {
            Layout.topMargin: root.compact ? 0 : Metrics.spacingM
            Layout.bottomMargin: root.compact ? Metrics.spacingS : Metrics.spacingM
            visible: !root.compact
            text: qsTr("Now playing")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.numeric
            font.pixelSize: 17
            font.weight: 500
            elide: Text.ElideRight
        }

        // Не влезает в строку — переносится на вторую, дальше многоточие.
        Text {
            Layout.fillWidth: true
            text: root.artist
            color: Appearance.colors.colPrimary
            font.family: Fonts.numeric
            font.pixelSize: root.narrow ? 18 : 24
            font.weight: 600
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSurface
            font.family: Fonts.numeric
            font.pixelSize: root.narrow ? 15 : 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: root.compact ? Metrics.spacingS : Metrics.spacingXL
            spacing: Math.round(Metrics.lockOuterPadding * root.controlScale)

            PlayerControl {
                icon: "skip_previous"
                canUse: root.hasMedia
                onClicked: {
                    if (root.player)
                        root.player.previous();
                }
            }

            PlayPauseButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                enabled: root.hasMedia
                opacity: enabled ? 1 : 0.45
                isPlaying: root.isPlaying
                playingBg: Appearance.colors.colPrimary
                playingFg: Appearance.colors.colOnPrimary
                pausedBg: Appearance.colors.colPrimaryContainer
                pausedFg: Appearance.colors.colOnPrimaryContainer
                stateLayerPlaying: Appearance.colors.colOnPrimary
                stateLayerPaused: Appearance.colors.colOnPrimaryContainer
                buttonSize: Math.round(64 * root.controlScale)
                iconSize: Math.round(31 * root.controlScale)
                iconFontFamily: Fonts.materialSymbolsRounded
                morphExpandWidth: Math.round(Metrics.lockOuterPadding * root.controlScale)
                morphPressWidth: Math.round(Metrics.lockOuterPadding * 2 * root.controlScale)
                morphPlayingRadius: Appearance.rounding.normal
                morphPressRadius: Appearance.rounding.normal
                spatialAnimationDuration: Appearance.animation.expressiveFastSpatial.duration
                spatialCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                colorAnimationDuration: Appearance.animation.standard.duration
                colorCurve: Appearance.animation.standard.bezierCurve
                iconSwapHalfDuration: Appearance.animation.standardSmall.duration
                iconOutCurve: Appearance.animation.standardAccel.bezierCurve
                iconInCurve: Appearance.animation.standardDecel.bezierCurve
                onClicked: {
                    if (root.player)
                        root.player.togglePlaying();
                }
            }

            PlayerControl {
                icon: "skip_next"
                canUse: root.hasMedia
                onClicked: {
                    if (root.player)
                        root.player.next();
                }
            }
        }
    }

    layer.effect: OpacityMask {

        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
        }
    }

    component PlayerControl: Rectangle {
        id: control

        property string icon: ""
        property bool active: false
        property bool canUse: true
        property string colour: "Secondary"
        readonly property int baseWidth: Math.round(69 * root.controlScale)
        readonly property int baseHeight: Math.round(59 * root.controlScale)
        readonly property int iconBoxSize: Math.round(Metrics.controlHeightM * root.controlScale)

        signal clicked

        Layout.preferredWidth: baseWidth + (active ? Math.round(Metrics.lockOuterPadding * root.controlScale) : 0)
        implicitWidth: baseWidth
        implicitHeight: baseHeight
        color: active ? Appearance.colors[`col${colour}`] : Appearance.colors[`col${colour}Container`]
        radius: active || controlState.pressed ? Appearance.rounding.normal : Math.min(implicitWidth,
                                                                                       implicitHeight) / 2
        opacity: canUse ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: control.active ? Appearance.colors[`colOn${control.colour}`] : Appearance.colors[`colOn${control.colour
                                                                                                    }Container`]
            opacity: controlState.pressed ? 0.2 : controlState.containsMouse ? 0.12 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }

        Text {
            id: controlIcon

            width: control.iconBoxSize
            height: control.iconBoxSize
            anchors.centerIn: parent
            text: control.icon
            color: control.active ? Appearance.colors[`colOn${control.colour}`] : Appearance.colors[`colOn${control.colour
                                                                                                    }Container`]
            font.family: Fonts.materialSymbolsRounded
            font.pixelSize: Math.round(29 * root.controlScale)
            font.weight: 500
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: controlState

            anchors.fill: parent
            enabled: control.canUse
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.standard.duration
                easing.type: Appearance.animation.standard.type
                easing.bezierCurve: Appearance.animation.standard.bezierCurve
            }
        }
    }
}
