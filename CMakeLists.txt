cmake_minimum_required(VERSION 3.21)

# Сборка native-модулей оболочки (Clavis.Cava, Clavis.Gamma, Clavis.Niri и
# остальные из core/plugin). Раньше они собирались из апстримного дерева
# ~/.local/src/clavis, и любая правка там терялась при обновлении. Теперь
# исходники лежат в этом репозитории и правятся вместе с QML.
#
# Собрать и поставить:
#     scripts/build-native.sh
#
# Или вручную:
#     cmake -S . -B build -G Ninja \
#         -DCMAKE_BUILD_TYPE=Release \
#         -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
#         -DCMAKE_PREFIX_PATH="$HOME/.local/opt/Qt/6.9.3/gcc_64;$HOME/.local/opt/devroot/usr;/usr"
#     cmake --build build
#     cmake --install build --component qml   # или скопировать build/qml вручную

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" PROJECT_DATE_VERSION LIMIT_COUNT 1)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
project(MyShellCore VERSION ${PROJECT_DATE_VERSION} LANGUAGES C CXX)

include(GNUInstallDirs)

# ЛОКАЛЬНАЯ ПРАВКА: пути к библиотекам внутри модулей делаем относительными.
#
# scripts/build-native.sh копирует собранные модули из build/qml в
# ~/.local/lib/qt6/qml. По умолчанию CMake прописывает в них абсолютный RPATH
# на дерево сборки, и скопированный плагин продолжает искать свою библиотеку
# там. Пока build/ на месте, это работает и выглядит правильным — а стоит
# переименовать каталог проекта или удалить build/, как оболочка перестаёт
# запускаться с «Cannot load library ... libClavisCava.so». Я на это наступил
# при переименовании проекта.
set(CMAKE_BUILD_RPATH_USE_ORIGIN ON)

# Каталог, из которого Quickshell берёт модули Clavis.*; тот же, что в
# обёртке ~/.local/bin/quickshell (QML2_IMPORT_PATH).
set(CLAVIS_QML_BUILD_DIR "${CMAKE_BINARY_DIR}/qml" CACHE PATH
    "Куда складывать модули QML в дереве сборки")
set(CLAVIS_QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE PATH
    "Куда ставить модули QML")

# Апстрим ставит сюда общесистемный конфиг и юниты systemd. Нам это не нужно:
# конфиг лежит прямо здесь, а служба своя (my-shell.service). Пути оставлены,
# потому что на них ссылаются install() внутри core, но ими не пользуемся.
set(CLAVIS_CONFIG_INSTALL_DIR "share/my-shell/unused" CACHE PATH
    "Не используется: конфигом служит сам репозиторий")
set(CLAVIS_SYSTEMD_USER_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/systemd/user" CACHE PATH
    "Не используется: служба заведена вручную")

# Тесты апстрима тянут за собой Qt Test и время сборки; включать по желанию
# через -DBUILD_TESTING=ON.
option(BUILD_TESTING "Собирать тесты из core/tests" OFF)
include(CTest)

# Каталог поиска для Spotlight собирается из деклараций настроек. Цель нужна
# и сама по себе, и как зависимость плагина переводов (core/plugin/i18n).
find_package(Python3 REQUIRED COMPONENTS Interpreter)
file(GLOB SEARCH_DECLARATIONS CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/Modules/ControlCenter/*.qml")
set(SEARCH_CATALOG "${CMAKE_CURRENT_SOURCE_DIR}/Common/generated/SearchCatalog.js")
add_custom_command(OUTPUT "${SEARCH_CATALOG}"
    COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/dev/generate-search-catalog.py"
    DEPENDS ${SEARCH_DECLARATIONS}
        "${CMAKE_CURRENT_SOURCE_DIR}/Common/settings-routes.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/system/niri-actions.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/dev/generate-search-catalog.py"
    VERBATIM)
add_custom_target(search_catalog ALL DEPENDS "${SEARCH_CATALOG}")

add_subdirectory(core)
