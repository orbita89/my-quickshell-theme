# Вкладка Upload

Очередь загрузки файлов в облако через rclone. Файлы сюда перетаскивают на
островок или вставляют Ctrl+V.

- **Обёртка:** `UploadHubTab.qml`, размер 440×220. Контракт описан в `../Hub/README.md`.
- **Флаги в реестре:**
  - `stickyOpen`: хаб не закрывается, когда курсор уходит за файлом;
  - `acceptsFileDrop`: перетаскивание файла на островок открывает эту вкладку.
- **`finishDrop(addedCount)`:** островок вызывает его после drop или Ctrl+V, и вкладка показывает очередь.
- **Где обрабатываются drop и Ctrl+V:** в `Styles/Shared/KeystoneSurface.qml` (`cloudUploadDropArea`, Shortcut `StandardKey.Paste`). Оба работают, только если вкладка включена.
- **Службы:** `CloudUploadService` (очередь), `RcloneService` (наличие rclone, удалённые хранилища). Обе пассивны, пока ничего не загружается.
