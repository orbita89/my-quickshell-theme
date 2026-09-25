import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

ColumnLayout {
    id: root

    // Shared editor for niri's mouse, touchpad and trackpoint sections. The
    // libinput options differ per device, so the extras stay behind flags.
    property string device: "mouse"
    property bool touchpad: false
    property bool trackpoint: false

    Layout.fillWidth: true
    spacing: Metrics.spacingS
    enabled: InputDeviceService.editable

    GeneralSliderSetting {
        title: qsTr("Pointer speed")
        description: qsTr("libinput acceleration, from slowest to fastest")
        from: -100
        to: 100
        stepSize: 5
        suffix: "%"
        value: InputDeviceService.number(root.device, "accel-speed", 0) * 100
        onMoved: value => InputDeviceService.set(root.device, "accel-speed", value / 100)
    }

    SettingsRow {
        Layout.fillWidth: true
        iconName: "speed"
        title: qsTr("Acceleration profile")
        supportingText: qsTr("Flat keeps the raw sensor resolution")

        trailing: StyledButtonGroup {
            model: [
                {
                    "value": "adaptive",
                    "label": qsTr("Adaptive")
                },
                {
                    "value": "flat",
                    "label": qsTr("Flat")
                }
            ]
            currentValue: InputDeviceService.choice(root.device, "accel-profile", "adaptive")
            onValueSelected: value => InputDeviceService.set(root.device, "accel-profile", value)
        }
    }

    GeneralSliderSetting {
        title: qsTr("Scroll speed")
        description: qsTr("Multiplies the distance of every scroll event")
        from: 10
        to: 500
        stepSize: 5
        suffix: "%"
        value: InputDeviceService.number(root.device, "scroll-factor", 1) * 100
        onMoved: value => InputDeviceService.set(root.device, "scroll-factor", value / 100)
    }

    SettingsRow {
        Layout.fillWidth: true
        iconName: "swap_vert"
        title: qsTr("Natural scrolling")
        supportingText: qsTr("Content follows the direction of your fingers")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "natural-scroll")
            Accessible.name: qsTr("Natural scrolling")
            onToggled: InputDeviceService.set(root.device, "natural-scroll", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "gesture"
        title: qsTr("Scroll method")

        trailing: StyledButtonGroup {
            model: [
                {
                    "value": "two-finger",
                    "label": qsTr("Two fingers")
                },
                {
                    "value": "edge",
                    "label": qsTr("Edge")
                },
                {
                    "value": "no-scroll",
                    "label": qsTr("Off")
                }
            ]
            currentValue: InputDeviceService.choice(root.device, "scroll-method", "two-finger")
            onValueSelected: value => InputDeviceService.set(root.device, "scroll-method", value)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "touch_app"
        title: qsTr("Tap to click")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "tap")
            Accessible.name: qsTr("Tap to click")
            onToggled: InputDeviceService.set(root.device, "tap", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "touch_app"
        title: qsTr("Tap button map")
        supportingText: qsTr("Buttons reported by two and three finger taps")

        trailing: StyledButtonGroup {
            enabled: InputDeviceService.editable && InputDeviceService.flag(root.device, "tap")
            model: [
                {
                    "value": "left-right-middle",
                    "label": qsTr("2 → right")
                },
                {
                    "value": "left-middle-right",
                    "label": qsTr("2 → middle")
                }
            ]
            currentValue: InputDeviceService.choice(root.device, "tap-button-map", "left-right-middle")
            onValueSelected: value => InputDeviceService.set(root.device, "tap-button-map", value)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "ads_click"
        title: qsTr("Click method")
        supportingText: qsTr("Click areas at the bottom edge, or by finger count")

        trailing: StyledButtonGroup {
            model: [
                {
                    "value": "button-areas",
                    "label": qsTr("Areas")
                },
                {
                    "value": "clickfinger",
                    "label": qsTr("Fingers")
                }
            ]
            currentValue: InputDeviceService.choice(root.device, "click-method", "button-areas")
            onValueSelected: value => InputDeviceService.set(root.device, "click-method", value)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "keyboard"
        title: qsTr("Disable while typing")
        supportingText: qsTr("Ignores the touchpad and the palm resting on it")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "dwt")
            Accessible.name: qsTr("Disable while typing")
            onToggled: InputDeviceService.set(root.device, "dwt", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "back_hand"
        title: qsTr("Disable while trackpointing")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "dwtp")
            Accessible.name: qsTr("Disable while trackpointing")
            onToggled: InputDeviceService.set(root.device, "dwtp", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "drag_pan"
        title: qsTr("Drag lock")
        supportingText: qsTr("Keeps dragging when your finger lifts briefly")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "drag-lock")
            Accessible.name: qsTr("Drag lock")
            onToggled: InputDeviceService.set(root.device, "drag-lock", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: root.touchpad
        iconName: "mouse"
        title: qsTr("Disable with an external mouse")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "disabled-on-external-mouse")
            Accessible.name: qsTr("Disable with an external mouse")
            onToggled: InputDeviceService.set(root.device, "disabled-on-external-mouse", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        visible: !root.trackpoint
        iconName: "left_click"
        title: qsTr("Left-handed buttons")
        supportingText: qsTr("Swaps the left and right buttons")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "left-handed")
            Accessible.name: qsTr("Left-handed buttons")
            onToggled: InputDeviceService.set(root.device, "left-handed", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        iconName: "adjust"
        title: qsTr("Middle button emulation")
        supportingText: qsTr("Pressing both buttons acts as the middle button")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "middle-emulation")
            Accessible.name: qsTr("Middle button emulation")
            onToggled: InputDeviceService.set(root.device, "middle-emulation", checked)
        }
    }

    SettingsRow {
        Layout.fillWidth: true
        iconName: "block"
        title: qsTr("Disable this device")

        trailing: StyledSwitch {
            checked: InputDeviceService.flag(root.device, "off")
            Accessible.name: qsTr("Disable this device")
            onToggled: InputDeviceService.set(root.device, "off", checked)
        }
    }
}
