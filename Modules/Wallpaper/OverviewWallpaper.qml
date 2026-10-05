import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Clavis.Niri
import qs.Common
import qs.Services

// Обои обзора рабочих столов. niri кладёт этот слой в задник обзора
// (place-within-backdrop в ~/.config/niri/clavis/layer-rules.kdl), а вне
// обзора его не видно вовсе. Поэтому окно создаётся только на время обзора:
// полноэкранная поверхность, слой с размытием и буферы MultiEffect стоили
// ~85 МБ графической памяти, которая у Intel — та же RAM (замер 2026-10-04:
// 276 → 191 МБ при выключенном обзоре).
//
// Обработанный кадр (заполнение, размытие, насыщенность, контраст) кэшируется
// в Paths.cacheHome/overview как статичный JPEG. Оригинал обоев и MultiEffect
// нужны только при первом открытии после смены обоев или настроек; дальше
// обзор показывает маленькую готовую картинку. При размытии кадр хранится
// в уменьшенном виде — после размытия детали всё равно не видны.
Variants {
    model: Quickshell.screens

    Scope {
        id: slot

        required property var modelData

        // Запас после закрытия обзора: окно не должно пропасть посреди
        // анимации отъезда, и быстрое повторное открытие его не пересоздаёт.
        readonly property bool wanted: PersonalizationConfig.overviewEnabled
                                       && (Niri.inOverview || closeGrace.running)

        // Пока окна нет, показывать нечего — для WallpaperService это «готово».
        function reportIdle() {
            if (!slot.wanted)
                WallpaperService.reportOverviewSurface(slot.modelData.name, true, "");
        }

        onWantedChanged: reportIdle()
        Component.onCompleted: reportIdle()

        Connections {
            target: Niri

            function onOverviewChanged() {
                if (Niri.inOverview)
                    closeGrace.stop();
                else
                    closeGrace.restart();
            }
        }

        Timer {
            id: closeGrace

            interval: 1500
        }

        LazyLoader {
            active: slot.wanted

            PanelWindow {
                id: overviewWindow

                screen: slot.modelData
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "clavis-overview-wallpaper"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                mask: Region {
                    item: Item {}
                }

                Item {
                    id: root

                    anchors.fill: parent
                    clip: true

                    property int serviceRevision: WallpaperService.revision
                    property int settingsRevision: WallpaperService.settingsRevision
                    readonly property int blurOverflow: PersonalizationConfig.overviewBlurRadius > 0 ? 64 : 0
                    readonly property string targetSource: serviceRevision >= 0
                                                           ? WallpaperService.overviewWallpaperForScreen(
                                                                 slot.modelData.name) : ""
                    readonly property string targetFillModeName: settingsRevision >= 0
                                                                 ? WallpaperService.overviewFillModeForScreen(
                                                                       slot.modelData.name) : "Fill"

                    readonly property string cacheDir: Paths.cacheHome + "/overview"
                    readonly property string cacheScreenKey: String(slot.modelData.name).replace(/[^A-Za-z0-9_-]/g,
                                                                                                "_")
                    // Радиус размытия в пикселях экрана; чем он больше, тем мельче можно хранить кадр.
                    readonly property real blurPixels: PersonalizationConfig.overviewBlurRadius / 100 * 64
                    readonly property int cacheScale: Math.max(1, Math.min(4, Math.floor(root.blurPixels / 4)))
                    // Окно появляется размером 500×500 и лишь потом растягивается на экран,
                    // поэтому размер кадра берётся у экрана, а не у окна.
                    readonly property int screenWidth: Math.round(slot.modelData.width)
                    readonly property int screenHeight: Math.round(slot.modelData.height)
                    // Без уменьшения кадр хранится в физических пикселях, чтобы не потерять резкость.
                    readonly property real cachePixelRatio: root.cacheScale === 1
                                                            ? Math.max(1, slot.modelData.devicePixelRatio) :
                                                              1 / root.cacheScale
                    readonly property bool cacheable: WallpaperService.isImagePath(root.targetSource)
                                                      && root.previewSource === "" && root.screenWidth > 0
                                                      && root.screenHeight > 0
                    readonly property string previewSource: WallpaperPaletteSession.previewForScreen("overview",
                                                                                                     slot.modelData.name)
                    readonly property string cachePath: root.cacheable ? root.cacheDir + "/" + root.cacheScreenKey
                                                                         + "-" + Qt.md5(JSON.stringify([
                                                                                                           root.targetSource,
                                                                                                           root.targetFillModeName,
                                                                                                           PersonalizationConfig.overviewBlurRadius,
                                                                                                           PersonalizationConfig.overviewSaturation,
                                                                                                           PersonalizationConfig.overviewContrast,
                                                                                                           root.screenWidth,
                                                                                                           root.screenHeight,
                                                                                                           root.cachePixelRatio
                                                                                                       ])) + ".jpg" : ""
                    // Сбрасывается при смене ключа: сначала пробуем готовый файл.
                    property bool cacheMissing: false
                    // Защита от круга «записали → не прочиталось → пишем снова».
                    property int captureAttempts: 0
                    readonly property bool useCached: root.cacheable && !root.cacheMissing
                    readonly property bool surfaceReady: root.useCached ? cachedImage.status === Image.Ready :
                                                                          liveLoader.item !== null
                                                                          && liveLoader.item.ready
                    readonly property string surfaceError: !root.useCached && liveLoader.item
                                                           ? liveLoader.item.lastError : ""

                    function reportSurface() {
                        WallpaperService.reportOverviewSurface(slot.modelData.name, !PersonalizationConfig.overviewEnabled
                                                               || root.surfaceReady, root.surfaceError);
                    }

                    function markCacheMissing() {
                        if (root.useCached && cachedImage.status === Image.Error)
                            root.cacheMissing = true;
                    }

                    function scheduleCapture() {
                        if (!root.useCached && root.cacheable && liveLoader.item && liveLoader.item.ready)
                            captureDelay.restart();
                        else
                            captureDelay.stop();
                    }

                    function capture() {
                        const live = liveLoader.item;
                        const path = root.cachePath;
                        if (!live || !live.ready || root.useCached || path === "" || root.captureAttempts >= 2)
                            return;
                        root.captureAttempts += 1;
                        const size = Qt.size(Math.max(1, Math.round(root.screenWidth * root.cachePixelRatio)),
                                             Math.max(1, Math.round(root.screenHeight * root.cachePixelRatio)));
                        live.grabToImage(result => {
                            if (path !== root.cachePath || !result.saveToFile(path))
                                return;
                            // Файл готов: живой рендер с оригиналом и эффектами больше не нужен.
                            root.cacheMissing = false;
                        }, size);
                    }

                    onCachePathChanged: {
                        root.cacheMissing = false;
                        root.captureAttempts = 0;
                    }
                    onSurfaceReadyChanged: root.reportSurface()
                    onSurfaceErrorChanged: root.reportSurface()
                    onUseCachedChanged: root.scheduleCapture()

                    onTargetSourceChanged: Qt.callLater(root.reportSurface)
                    Component.onCompleted: Qt.callLater(root.reportSurface)

                    Image {
                        id: cachedImage

                        anchors.fill: parent
                        visible: root.useCached
                        source: root.useCached ? Paths.fileUrl(root.cachePath) : ""
                        // Файл маленький: синхронная загрузка даёт картинку уже в первом кадре.
                        asynchronous: false
                        cache: false
                        smooth: true
                        fillMode: Image.Stretch

                        // Синхронная загрузка сообщает об ошибке прямо во время вычисления
                        // source; переключение откладывается, чтобы не зациклить привязку.
                        onStatusChanged: {
                            if (status === Image.Error)
                                Qt.callLater(root.markCacheMissing);
                        }
                    }

                    Loader {
                        id: liveLoader

                        anchors.fill: parent
                        active: !root.useCached

                        onLoaded: root.scheduleCapture()

                        sourceComponent: Item {
                            readonly property bool ready: renderer.ready
                            readonly property string lastError: renderer.lastError

                            clip: true

                            onReadyChanged: root.scheduleCapture()

                            WallpaperTransitionSurface {
                                id: renderer

                                anchors.fill: parent
                                anchors.margins: -root.blurOverflow
                                sourcePath: root.targetSource
                                previewSource: root.previewSource
                                imageFillMode: WallpaperService.qtFillMode(root.targetFillModeName)
                                shaderFillMode: WallpaperService.shaderFillMode(root.targetFillModeName)
                                transitionType: PersonalizationConfig.overviewTransitionType
                                includedTransitions: PersonalizationConfig.includedTransitions
                                transitionDurationMs: PersonalizationConfig.transitionDurationMs
                                transitionEasingMode: PersonalizationConfig.transitionEasingMode
                                transitionBezierCurve: PersonalizationConfig.transitionBezierCurve
                                // Под сильным размытием полное разрешение не видно, а распаковка
                                // уменьшенного JPEG в разы быстрее.
                                textureWidth: Math.min(Math.max(1, Math.round(root.screenWidth / root.cacheScale)), 8192)
                                textureHeight: Math.min(Math.max(1, Math.round(root.screenHeight / root.cacheScale)), 8192)

                                layer.enabled: PersonalizationConfig.overviewBlurRadius > 0
                                               || PersonalizationConfig.overviewSaturation !== 1
                                               || PersonalizationConfig.overviewContrast !== 1
                                layer.effect: MultiEffect {
                                    blurEnabled: PersonalizationConfig.overviewBlurRadius > 0
                                    blur: PersonalizationConfig.overviewBlurRadius / 100
                                    blurMax: 64
                                    saturation: PersonalizationConfig.overviewSaturation - 1
                                    contrast: PersonalizationConfig.overviewContrast - 1
                                }

                                onLoadFailed: (source, message) => {
                                    WallpaperService.reportOverviewSurface(slot.modelData.name, false, message);
                                }
                            }
                        }
                    }

                    // Кадр снимается после того, как MultiEffect успел отрисоваться.
                    Timer {
                        id: captureDelay

                        interval: 250
                        onTriggered: cacheDirProcess.running = true
                    }

                    // Готовит каталог и убирает старые кадры этого экрана перед записью нового.
                    Process {
                        id: cacheDirProcess

                        command: ["sh", "-c", "mkdir -p \"$1\" && rm -f \"$1/$2\"-*.jpg", "sh", root.cacheDir,
                            root.cacheScreenKey]
                        onExited: exitCode => {
                            if (exitCode === 0)
                                root.capture();
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.m3colors.m3scrim
                        opacity: PersonalizationConfig.overviewDim
                    }
                }
            }
        }
    }
}
