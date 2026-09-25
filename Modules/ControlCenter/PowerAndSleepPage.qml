import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property string activeTab: "all"

    readonly property var timeoutOptions: [
        { "value": "60", "label": qsTr("1 minute") },
        { "value": "120", "label": qsTr("2 minutes") },
        { "value": "180", "label": qsTr("3 minutes") },
        { "value": "300", "label": qsTr("5 minutes") },
        { "value": "600", "label": qsTr("10 minutes") },
        { "value": "900", "label": qsTr("15 minutes") },
        { "value": "1800", "label": qsTr("30 minutes") },
        { "value": "2700", "label": qsTr("45 minutes") },
        { "value": "3600", "label": qsTr("1 hour") },
        { "value": "7200", "label": qsTr("2 hours") }
    ]

    readonly property var suspendTimeoutOptions: [
        { "value": "300", "label": qsTr("5 minutes") },
        { "value": "600", "label": qsTr("10 minutes") },
        { "value": "900", "label": qsTr("15 minutes") },
        { "value": "1800", "label": qsTr("30 minutes") },
        { "value": "2700", "label": qsTr("45 minutes") },
        { "value": "3600", "label": qsTr("1 hour") },
        { "value": "7200", "label": qsTr("2 hours") },
        { "value": "10800", "label": qsTr("3 hours") },
        { "value": "14400", "label": qsTr("4 hours") }
    ]

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: IdleService.lastError !== ""
            tone: "error"
            message: IdleService.lastError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: IdleService.inhibited
            tone: "info"
            message: qsTr("Keep Awake is active: idle timers and sleep are temporarily paused.")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: !IdleService.policyEnabled
            tone: "warning"
            message: qsTr("Idle management is turned off.")
        }

        StyledButtonGroup {
            Layout.alignment: Qt.AlignHCenter
            currentValue: root.activeTab
            model: [
                {
                    "value": "all",
                    "label": qsTr("All"),
                    "icon": "apps"
                },
                {
                    "value": "screen",
                    "label": qsTr("Screen"),
                    "icon": "monitor"
                },
                {
                    "value": "lock",
                    "label": qsTr("Lock screen"),
                    "icon": "lock"
                },
                {
                    "value": "suspend",
                    "label": qsTr("Sleep"),
                    "icon": "bedtime"
                }
            ]
            onValueSelected: value => root.activeTab = value
        }

        SettingsSection {
            id: screenSection

            Layout.fillWidth: true
            flat: true
            visible: root.activeTab === "all" || root.activeTab === "screen"
            title: screenAnchor.title
            iconName: "monitor"

            SettingsSearchAnchor {
                id: screenAnchor

                target: screenSection
                declaration:
                    '{"id":"general.power-sleep.section.screen","route":"general.power-sleep","title":"Screen & Display","context":"PowerAndSleepPage","icon":"monitor","aliases":["screen timeout","turn off display","dim screen","brightness"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "power_settings_new"
                title: qsTr("Turn off screen when inactive")
                supportingText: qsTr("Turn off display power after inactivity")

                trailing: StyledSwitch {
                    checked: IdleService.displayOffEnabled
                    Accessible.name: qsTr("Turn off screen when inactive")
                    onToggled: {
                        IdleService.configureStage("displayOff", checked, IdleService.displayOffTimeout,
                                                   IdleService.displayOffRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "timer"
                title: qsTr("Screen off timeout")
                enabled: IdleService.displayOffEnabled && IdleService.policyEnabled

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 160
                    options: root.timeoutOptions
                    value: String(Math.round(IdleService.displayOffTimeout))
                    placeholder: qsTr("Select timeout")
                    closeOnAccept: true
                    onAccepted: value => {
                        IdleService.configureStage("displayOff", IdleService.displayOffEnabled, Number(value),
                                                   IdleService.displayOffRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "brightness_medium"
                title: qsTr("Dim screen before turning off")
                supportingText: qsTr("Gradually reduce display brightness before turn-off")

                trailing: StyledSwitch {
                    checked: IdleService.dimEnabled
                    Accessible.name: qsTr("Dim screen before turning off")
                    onToggled: {
                        IdleService.configureStage("dim", checked, IdleService.dimTimeout,
                                                   IdleService.dimRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: IdleService.dimEnabled
                iconName: "schedule"
                title: qsTr("Dim timeout")
                enabled: IdleService.dimEnabled && IdleService.policyEnabled

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 160
                    options: root.timeoutOptions
                    value: String(Math.round(IdleService.dimTimeout))
                    placeholder: qsTr("Select timeout")
                    closeOnAccept: true
                    onAccepted: value => {
                        IdleService.configureStage("dim", IdleService.dimEnabled, Number(value),
                                                   IdleService.dimRespectInhibitors);
                    }
                }
            }

            GeneralSliderSetting {
                visible: IdleService.dimEnabled
                enabled: IdleService.dimEnabled && IdleService.policyEnabled
                title: qsTr("Dimmed brightness level")
                description: qsTr("Brightness level applied when screen is dimmed")
                from: 5
                to: 80
                stepSize: 5
                suffix: "%"
                value: Math.round(IdleService.dimFraction * 100)
                onMoved: value => IdleService.setDimFraction(value / 100)
            }
        }

        SettingsSection {
            id: lockSection

            Layout.fillWidth: true
            flat: true
            visible: root.activeTab === "all" || root.activeTab === "lock"
            title: lockAnchor.title
            iconName: "lock"

            SettingsSearchAnchor {
                id: lockAnchor

                target: lockSection
                declaration:
                    '{"id":"general.power-sleep.section.lock","route":"general.power-sleep","title":"Screen Lock","context":"PowerAndSleepPage","icon":"lock","aliases":["lock screen","auto lock","lock timeout","security"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "lock_clock"
                title: qsTr("Automatically lock screen")
                supportingText: qsTr("Lock the session after a period of user inactivity")

                trailing: StyledSwitch {
                    checked: IdleService.lockEnabled
                    Accessible.name: qsTr("Automatically lock screen")
                    onToggled: {
                        IdleService.configureStage("lock", checked, IdleService.lockTimeout,
                                                   IdleService.lockRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "timer"
                title: qsTr("Lock timeout")
                enabled: IdleService.lockEnabled && IdleService.policyEnabled

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 160
                    options: root.timeoutOptions
                    value: String(Math.round(IdleService.lockTimeout))
                    placeholder: qsTr("Select timeout")
                    closeOnAccept: true
                    onAccepted: value => {
                        IdleService.configureStage("lock", IdleService.lockEnabled, Number(value),
                                                   IdleService.lockRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "do_not_disturb_on"
                title: qsTr("Respect idle inhibitors")
                supportingText: qsTr("Do not lock while media is playing or presentations are active")

                trailing: StyledSwitch {
                    checked: IdleService.lockRespectInhibitors
                    Accessible.name: qsTr("Respect idle inhibitors for lock")
                    onToggled: {
                        IdleService.configureStage("lock", IdleService.lockEnabled, IdleService.lockTimeout,
                                                   checked);
                    }
                }
            }
        }

        SettingsSection {
            id: suspendSection

            Layout.fillWidth: true
            flat: true
            visible: root.activeTab === "all" || root.activeTab === "suspend"
            title: suspendAnchor.title
            iconName: "bedtime"

            SettingsSearchAnchor {
                id: suspendAnchor

                target: suspendSection
                declaration:
                    '{"id":"general.power-sleep.section.suspend","route":"general.power-sleep","title":"Sleep & Suspend","context":"PowerAndSleepPage","icon":"bedtime","aliases":["sleep","suspend","laptop sleep","power down","idle timeout"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "bedtime"
                title: qsTr("Automatic sleep / suspend")
                supportingText: qsTr("Put computer into sleep mode after inactivity")

                trailing: StyledSwitch {
                    checked: IdleService.suspendEnabled
                    Accessible.name: qsTr("Automatic sleep / suspend")
                    onToggled: {
                        IdleService.configureStage("suspend", checked, IdleService.suspendTimeout,
                                                   IdleService.suspendRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "timer"
                title: qsTr("Sleep timeout")
                enabled: IdleService.suspendEnabled && IdleService.policyEnabled

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 160
                    options: root.suspendTimeoutOptions
                    value: String(Math.round(IdleService.suspendTimeout))
                    placeholder: qsTr("Select timeout")
                    closeOnAccept: true
                    onAccepted: value => {
                        IdleService.configureStage("suspend", IdleService.suspendEnabled, Number(value),
                                                   IdleService.suspendRespectInhibitors);
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "do_not_disturb_on"
                title: qsTr("Respect sleep inhibitors")
                supportingText: qsTr("Prevent sleeping when applications request it")

                trailing: StyledSwitch {
                    checked: IdleService.suspendRespectInhibitors
                    Accessible.name: qsTr("Respect sleep inhibitors")
                    onToggled: {
                        IdleService.configureStage("suspend", IdleService.suspendEnabled,
                                                   IdleService.suspendTimeout, checked);
                    }
                }
            }
        }

        SettingsSection {
            id: policySection

            Layout.fillWidth: true
            flat: true
            visible: root.activeTab === "all"
            title: policyAnchor.title
            iconName: "tune"

            SettingsSearchAnchor {
                id: policyAnchor

                target: policySection
                declaration:
                    '{"id":"general.power-sleep.section.policy","route":"general.power-sleep","title":"Idle Policy","context":"PowerAndSleepPage","icon":"tune","aliases":["idle policy","inhibit","keep awake"]}'
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "toggle_on"
                title: qsTr("Idle management")
                supportingText: qsTr("Master switch for all screen turn-off, lock and sleep timers")

                trailing: StyledSwitch {
                    checked: IdleService.policyEnabled
                    Accessible.name: qsTr("Idle management")
                    onToggled: IdleService.setPolicyEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "coffee"
                title: qsTr("Keep awake")
                supportingText: qsTr("Temporarily prevent dimming, screen turn-off, locking and sleeping")

                trailing: StyledSwitch {
                    checked: IdleService.inhibited
                    Accessible.name: qsTr("Keep awake")
                    onToggled: IdleService.setInhibited(checked)
                }
            }
        }
    }
}
