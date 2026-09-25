import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    Component.onCompleted: NiriConfigService.refresh()

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: !InputDeviceService.supported
            tone: "info"
            message: qsTr("Available in a niri session")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: InputDeviceService.supported && !InputDeviceService.available
            tone: "warning"
            message: qsTr("The niri configuration has no input section")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: InputDeviceService.supported && InputDeviceService.available
                     && !InputDeviceService.writable
            tone: "warning"
            message: qsTr("Configuration is not writable")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: InputDeviceService.error !== ""
            tone: "error"
            message: InputDeviceService.error
        }

        SettingsSection {
            id: mouseSection

            Layout.fillWidth: true
            flat: true
            title: mouseAnchor.title
            iconName: "mouse"

            SettingsSearchAnchor {
                id: mouseAnchor

                target: mouseSection
                declaration:
                    '{"id":"general.mouse-touchpad.section.mouse","route":"general.mouse-touchpad","title":"Mouse","context":"MouseTouchpadPage","icon":"mouse","aliases":["pointer speed","acceleration","scroll speed"]}'
            }

            PointerDeviceSettings {
                device: "mouse"
            }
        }

        SettingsSection {
            id: touchpadSection

            Layout.fillWidth: true
            flat: true
            title: touchpadAnchor.title
            iconName: "touchpad_mouse"

            SettingsSearchAnchor {
                id: touchpadAnchor

                target: touchpadSection
                declaration:
                    '{"id":"general.mouse-touchpad.section.touchpad","route":"general.mouse-touchpad","title":"Touchpad","context":"MouseTouchpadPage","icon":"touchpad_mouse","aliases":["tap to click","natural scrolling","gestures"]}'
            }

            PointerDeviceSettings {
                device: "touchpad"
                touchpad: true
            }
        }

        SettingsSection {
            id: trackpointSection

            Layout.fillWidth: true
            flat: true
            // Only laptops with a pointing stick carry this section.
            visible: !!(InputDeviceService.snapshot.devices
                        && InputDeviceService.snapshot.devices.trackpoint
                        && InputDeviceService.snapshot.devices.trackpoint.present)
            title: trackpointAnchor.title
            iconName: "radio_button_checked"

            SettingsSearchAnchor {
                id: trackpointAnchor

                target: trackpointSection
                declaration:
                    '{"id":"general.mouse-touchpad.section.trackpoint","route":"general.mouse-touchpad","title":"Trackpoint","context":"MouseTouchpadPage","icon":"radio_button_checked","aliases":["pointing stick"]}'
            }

            PointerDeviceSettings {
                device: "trackpoint"
                trackpoint: true
            }
        }

        SettingsSection {
            id: pointerSection

            Layout.fillWidth: true
            flat: true
            title: pointerAnchor.title
            iconName: "highlight_alt"
            enabled: InputDeviceService.editable

            SettingsSearchAnchor {
                id: pointerAnchor

                target: pointerSection
                declaration:
                    '{"id":"general.mouse-touchpad.section.pointer","route":"general.mouse-touchpad","title":"Pointer behavior","context":"MouseTouchpadPage","icon":"highlight_alt","aliases":["focus follows mouse","warp"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "center_focus_strong"
                title: qsTr("Warp the pointer to the focused window")

                trailing: StyledSwitch {
                    checked: InputDeviceService.sectionFlag("warp-mouse-to-focus")
                    Accessible.name: qsTr("Warp the pointer to the focused window")
                    onToggled: InputDeviceService.setSectionFlag("warp-mouse-to-focus", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "my_location"
                title: qsTr("Focus follows the pointer")
                supportingText: InputDeviceService.locked("focus-follows-mouse") ? qsTr(
                                                                                       "Tuned in the configuration file") :
                                                                                   ""

                trailing: StyledSwitch {
                    enabled: InputDeviceService.editable
                             && !InputDeviceService.locked("focus-follows-mouse")
                    checked: InputDeviceService.sectionFlag("focus-follows-mouse")
                    Accessible.name: qsTr("Focus follows the pointer")
                    onToggled: InputDeviceService.setSectionFlag("focus-follows-mouse", checked)
                }
            }
        }
    }
}
