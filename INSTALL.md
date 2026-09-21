# Установка на другую машину

Репозиторий содержит код оболочки, исходники native-модулей и настройки.
Всё остальное — движок Quickshell, Qt, keytop, key-cli, libcava, M3Shapes,
matugen — собирается или ставится пакетами и в git не попадает.

Сложность установки зависит от дистрибутива:

| Система | Что придётся собирать | Время |
|---|---|---|
| **Arch, CachyOS, EndeavourOS** | почти ничего — всё есть в репозиториях и AUR | 15–30 минут |
| **Ubuntu 24.04** | Qt, Quickshell, keytop, key-cli, libcava, M3Shapes | 2–3 часа |
| **Fedora, openSUSE** | как Ubuntu, но проверьте Qt: нужен 6.8+ | 1–3 часа |

Оболочка рассчитана на композитор **niri**. На других Wayland-композиторах
часть вещей не заработает: островок и панель используют протокол
layer-shell (он есть почти везде), но управление окнами и рабочими столами
идёт через IPC самого niri.

---

## CachyOS и другие Arch-подобные

Самый простой путь: апстрим Clavis собран под Arch, поэтому почти все
зависимости лежат в репозиториях и AUR, а **Qt 6.9 идёт системным пакетом** —
ничего подкладывать не нужно.

### 1. Пакеты

```sh
# основное
sudo pacman -S --needed niri quickshell qt6-base qt6-declarative qt6-svg \
    qt6-wayland qt6-5compat qt6-lottie qt6-location qt6-positioning \
    qtkeychain-qt6 libpipewire libxkbcommon systemd-libs \
    jq wl-clipboard fd python bash glib2 libnotify pam xdg-utils

# сборка native-модулей
sudo pacman -S --needed cmake ninja pkgconf

# полезное, но не обязательное
sudo pacman -S --needed power-profiles-daemon brightnessctl btop cliphist \
    grim slurp ffmpeg networkmanager bluez upower pipewire wireplumber \
    ttf-jetbrains-mono-nerd
```

Из AUR (`paru -S` или `yay -S`):

```sh
paru -S libcava matugen ttf-material-symbols-variable qt6-m3shapes-git \
    maplibre-native-qt keytop key-cli
```

`keytop` и `key-cli` от того же автора, что и Clavis
(`StatIndet/keytop`, `StatIndet/key-cli`). Если в AUR их нет — соберите
как на Ubuntu, шаги 6 и 7 ниже.

### 2. Сам проект

```sh
git clone <адрес> ~/.config/quickshell/my
cd ~/.config/quickshell/my
scripts/build-native.sh        # соберёт модули Clavis.* из core/
scripts/install-system.sh      # свяжет юнит и обёртки
systemctl --user enable --now my-shell.service
```

Обёртки `system/bin/quickshell` и `system/bin/keytop` написаны так, что
подстановку Qt из `~/.local/opt` они делают только если этот каталог есть.
На Arch его нет, и они просто запускают системный движок.

### 3. Проверка

```sh
systemctl --user status my-shell.service
journalctl --user -u my-shell.service -n 30
```

---

## Ubuntu 24.04

Здесь длиннее: в репозиториях Qt 6.4.2, а Quickshell требует минимум 6.6,
теме нужен 6.9. Поэтому Qt ставится отдельной сборкой в `~/.local/opt`, а
движок и утилиты собираются из исходников. Всё складывается в домашний
каталог — root нужен только для системных пакетов.

Большую часть делает скрипт:

```sh
git clone <адрес> ~/.config/quickshell/my
cd ~/.config/quickshell/my
scripts/install-fresh.sh --check     # что уже есть, чего не хватает
scripts/install-fresh.sh             # поставить недостающее
```

Он идёт по шагам, каждый можно запустить отдельно:
`scripts/install-fresh.sh qt quickshell`.

Скрипт восстановлен по тому, как собрано на исходной машине, и на чистой
системе целиком не прогонялся. Запускайте по шагам и смотрите вывод.

### Что делает каждый шаг

**1. `apt` — системные пакеты.** Единственное место, где нужен root:

```sh
sudo apt install git cmake ninja-build pkgconf build-essential python3-venv \
    libwayland-dev wayland-protocols libxkbcommon-dev libpipewire-0.3-dev \
    libdrm-dev libpam0g-dev libjemalloc-dev libfftw3-dev \
    libgtk-layer-shell-dev libdbusmenu-glib-dev libdbusmenu-gtk3-dev \
    libpolkit-agent-1-dev libpolkit-gobject-1-dev \
    power-profiles-daemon brightnessctl cliphist btop jq
```

Отдельно niri: в Ubuntu 24.04 его нет в репозиториях, ставится из
[релизов проекта](https://github.com/YaLTeR/niri/releases) или собирается
из исходников.

**2. `qt` — Qt 6.9.3** через `aqtinstall` в `~/.local/opt/Qt`. Это
официальные сборки, учётная запись не нужна.

**3. `devroot` — заголовки** в `~/.local/opt/devroot`. Пакеты `-dev`
скачиваются и распаковываются без установки в систему: так native-модули
находят заголовки polkit, jemalloc, fftw и прочих, не требуя root.

**4. `cava` — libcava 0.9.1.** Строго эта версия: в 1.0.0 у `cava_init`
появился лишний аргумент и плагин `Clavis.Cava` не собирается.

**5. `quickshell`** — движок, ревизия `c6a5160` (0.3.1).

**6. `keytop`** — системный монитор, из `StatIndet/keytop`.

**7. `keycli`** — утилита `key` в отдельном venv, из `StatIndet/key-cli`.
Отвечает за буфер обмена, запись экрана и поиск файлов.

**8. `matugen`** — генератор палитры из обоев, `cargo install`. Нужен Rust.

**9. `fonts`** — Material Symbols Rounded (значки интерфейса). Без него
вместо иконок будут пустые квадраты.

**10. `native`** — сборка модулей `Clavis.*` из `core/`.

**11. `links`** — ссылки на юнит systemd и обёртки, включение службы.

---

## Другие дистрибутивы

Принцип один: нужен **Qt 6.8 или новее** и **Quickshell**. Дальше смотрите
по тому, что есть в репозиториях:

- **Qt 6.8+ есть** (Fedora 41+, openSUSE Tumbleweed, Arch) — ставьте Qt
  пакетами, собирайте только Quickshell, keytop, key-cli, libcava,
  M3Shapes. Скрипт `install-fresh.sh` пропустит шаг `qt`, если каталог
  `~/.local/opt/Qt` создан или если поправить в нём `qt_root` на системный
  путь.
- **Qt старее** (Debian stable, Ubuntu LTS) — путь как у Ubuntu выше.

Полный список зависимостей с пояснением, зачем каждая, лежит у апстрима в
`packaging/dependencies.json` — там же имена пакетов для Arch.

---

## После установки

Эти вещи в репозиторий не входят и настраиваются отдельно.

**Конфиг niri.** Горячие клавиши, автозапуск, раскладка мониторов —
`~/.config/niri/config.kdl`. Оболочка запускается службой
`my-shell.service`, через `spawn-at-startup` её дублировать не нужно:
получится два экземпляра.

**Обои.** Путь хранится в настройках (`config/config.json`,
`wallpaper.path`) и после переезда будет указывать в никуда. Выберите обои
заново — палитра пересчитается сама.

**Тема btop.** Чтобы btop перекрашивался вместе с оболочкой, в
`~/.config/btop/btop.conf` поставьте `color_theme = "matugen"`.

**Шрифт значков.** После установки стоит прогнать
`scripts/subset-icon-font.sh` — он урежет Material Symbols с 14 МБ до 1.6 МБ,
оставив только те иконки, которые оболочка рисует. Не обязательно, но
экономит около 15 МБ памяти в долгой сессии.

**Шрифт интерфейса.** В настройках стоит `LXGW WenKai GB Screen`. Если его
нет, подставляется `sans-serif` — работает, но выглядит иначе. Поменять
можно в настройках оформления.

---

## Если что-то не работает

Проверено на своей шкуре, поэтому с симптомами.

**Ползунок яркости ничего не делает.** Файл
`/sys/class/backlight/*/brightness` принадлежит группе `video`, а
пользователь в ней не состоит — `brightnessctl` печатает «run with root
privileges». Обёртка `backlight-set` это обходит через logind, но если
хотите штатный путь: `sudo usermod -aG video $USER` и перезайти в систему.

**Ночной режим не меняет цвет экрана.** Проверьте, что композитор отдаёт
протокол гаммы:

```sh
wlsunset -T 3001 -t 3000     # должен написать «setting temperature»
```

На Intel Tiger Lake таблица гаммы содержит 262145 значений — апстримный
плагин такие браковал. В `core/plugin/gamma/src/` предел поднят, но если
собираете плагин из другого дерева, правку придётся повторить.

**Вместо слов в интерфейсе появляются иконки.** Шрифт интерфейса не
установлен, и Qt подставляет шрифт значков: слова вроде `balance` и `power`
совпадают с названиями лигатур Material Symbols. Поставьте нужный шрифт
или оставьте `sans-serif`.

**keytop ест процессор.** Модуль `gpu` опрашивает дискретную видеокарту и
стоит около 58% ядра. В этом проекте он отключён; если вернёте — знайте
цену. Осиротевшие процессы keytop подчищает сама служба.

**Панель не появилась.** Смотрите журнал:

```sh
journalctl --user -u my-shell.service -n 50
```

Частое: не найден модуль `Clavis.*` (не выполнен `scripts/build-native.sh`)
или движок собран против другого Qt («version Qt_6.9 not found»).
