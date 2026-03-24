# NimFPDF — Оставшиеся шаги MVP

## Что уже сделано

- [x] Шаг 1: Скелет проекта и типы (`types.nim`, `utils.nim`, `buffer.nim`, `fpdf.nimble`)
- [x] Шаг 2: Управление страницами и минимальный PDF (`state.nim`, `serialize.nim`)
- [x] Шаг 3: Метрики 14 базовых шрифтов (`fontmetrics/*.nim`, `fonts.nim`)
- [x] Шаг 4: Текстовый вывод — Cell, MultiCell, Write, Text, Ln (`drawing.nim`)
- [x] Шаг 5: Графика и цвета — Line, Rect, SetLineWidth, SetDrawColor/Fill/Text (`drawing.nim`, `color.nim`)

## Что осталось

### Шаг 6: Ссылки
- `src/fpdf/links.nim` — новый модуль
- `addLink() -> int` — создать внутреннюю ссылку, вернуть индекс
- `setLink(linkIdx, y, page)` — установить назначение внутренней ссылки
- `link(x, y, w, h, target)` — добавить кликабельную область на текущей странице
- Интеграция с `serialize.nim` — генерация `/Annots` аннотаций при сериализации
  - Внешние: `/A <</S /URI /URI (url)>>`
  - Внутренние: `/Dest [pageObj /XYZ 0 y null]`
- Базовая поддержка ссылок в Cell/Write уже заложена через `LinkTarget`
- **Тест**: PDF с внутренней ссылкой (переход на страницу 2) и внешним URL

### Шаг 7: Изображения — JPEG
- `src/fpdf/image.nim` — новый модуль
- `image(file, x, y, w, h, type, link)` — вставка изображения
- `parseJpeg(file) -> ImageInfo` — парсинг SOF0/SOF2 маркеров (размеры, цветовое пространство)
  - JPEG встраивается as-is с фильтром DCTDecode
  - Нужно прочитать маркер FF C0 / FF C2 → высота (2 байта), ширина (2 байта), компоненты
  - ~30 строк кода
- `putImages(doc)` / `putImage(doc, info)` — сериализация XObject в `serialize.nim`
- Авто-масштабирование: если w=h=0, используется 96 dpi
- **Тест**: PDF с встроенным JPEG, проверка рендера

### Шаг 8: Изображения — PNG
- Расширение `image.nim`
- `parsePng(file) -> ImageInfo` — декодирование через nimPNG
  - Grayscale → DeviceGray
  - RGB → DeviceRGB
  - Indexed (палитра) → `/Indexed [/DeviceRGB N palette_data]`
  - RGBA → DeviceRGB + отдельный SMask (alpha как DeviceGray)
  - Grayscale+Alpha → DeviceGray + SMask
- Сжатие пиксельных данных через deflate (zippy)
- tRNS chunk → `/Mask [color color]`
- **Тест**: PNG с прозрачностью, PNG без альфы, индексированный PNG

### Шаг 9: Сжатие (Deflate)
- Интеграция `zippy` в `serialize.nim`
- При `doc.compress == true` (по умолчанию включено):
  - Потоки страниц сжимаются через `compress(data, BestSpeed, dfZlib)`
  - Добавляется `/Filter /FlateDecode` в словарь потока
- PNG данные уже сжаты — используют FlateDecode
- JPEG использует DCTDecode — без дополнительного сжатия
- `nimble install zippy` — добавить зависимость
- **Тест**: сравнить размер PDF с/без сжатия, оба должны быть валидны

### Шаг 10: Интеграционное тестирование и edge cases
- Мульти-страничный документ:
  - Смешанные ориентации (portrait + landscape)
  - Разные размеры страниц (A4, Letter)
  - Ротация страниц (0, 90, 180, 270)
- Автоматический разрыв страниц из `multiCell` с длинным текстом
- `aliasNbPages` — замена `{nb}` на реальное число страниц
- Header/Footer callbacks — текст/линия на каждой странице
- Edge cases:
  - Пустой текст в Cell
  - Нулевая ширина ячейки (авто-расчёт)
  - Попытка вывода без установленного шрифта → `FpdfError`
  - Попытка добавить контент после `close()` → `FpdfError`
- Проверка всех сгенерированных PDF через `qpdf --check` (если доступен)

## Структура файлов (текущая)

```
src/
  fpdf.nim                      # ре-экспорт всех модулей
  fpdf/
    types.nim                   # типы, enum'ы, Fpdf ref object
    utils.nim                   # fmtFloat, escape, textString, yToPdf
    buffer.nim                  # put, output, newObj, putStream (общий для state/serialize)
    state.nim                   # newFpdf, addPage, close, margins, position, metadata
    serialize.nim               # endDoc, putPages, putFonts, putImages, xref, trailer
    fonts.nim                   # setFont, setFontSize, getStringWidth
    color.nim                   # setDrawColor, setFillColor, setTextColor
    drawing.nim                 # cell, multiCell, write, text, ln, line, rect, setLineWidth
    links.nim                   # [TODO] addLink, setLink, link
    image.nim                   # [TODO] image, parseJpeg, parsePng
    fontmetrics/
      courier.nim               # const CourierCw
      helvetica.nim             # const HelveticaCw, HelveticaBoldCw, ...
      times.nim                 # const TimesRomanCw, TimesBoldCw, ...
      symbol.nim                # const SymbolCw
      zapfdingbats.nim          # const ZapfDingbatsCw
```
