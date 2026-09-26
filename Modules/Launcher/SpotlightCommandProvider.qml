import QtQuick
import qs.Services
import "../../Common/functions/SpotlightCommands.js" as Commands

QtObject {
    id: root
    property bool active: false
    property bool slash: false
    property string query: ""
    property var sessionState: ({
                                    mode: "search",
                                    tool: ""
                                })
    readonly property string language: Qt.uiLanguage
    readonly property var results: {
        const currentLanguage = language;
        if (!active)
            return [];
        let entries = SpotlightCatalog.commandMatches(query, !slash);
        // ЛОКАЛЬНАЯ ПРАВКА: при наборе «/имя» наверх идут команды, чьё имя
        // или псевдоним начинается с набранного, дальше — совпадения по
        // названию. Порядок внутри групп — как в SpotlightCommands.js.
        if (slash) {
            const prefix = query.trim().toLocaleLowerCase();
            const rank = entry => [entry.slashName].concat(entry.aliases || []).some(name => name.startsWith(
                                                                                            prefix)) ? 0 : 1;
            entries = entries.map((entry, index) => ({
                                                          entry: entry,
                                                          index: index
                                                      })).sort((a, b) => rank(a.entry) - rank(b.entry) || a.index
                                                                         - b.index).map(item => item.entry);
        }
        return entries.map(entry => ({
            id: entry.id,
            title: SpotlightCatalog.commandTitle(entry),
            icon: entry.icon,
            subtitle: Commands.available(entry, sessionState) ? "/" + entry.slashName : qsTr(
                                                                    "Available in %1 only").arg(entry.scope
                                                                                                === "apps"
                                                                                                ? qsTr("Apps") :
                                                                                                  qsTr("Clipboard")),
            entry: entry
        }));
    }
    }
