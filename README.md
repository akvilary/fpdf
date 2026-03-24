# FPDF

PDF generation library for Nim, inspired by the [FPDF](http://www.fpdf.org/) PHP library by Olivier Plathey.

No external PDF tools required — generates valid PDF 1.3 files entirely in Nim.

> **Attribution.** API design is inspired by [FPDF](http://www.fpdf.org/) (PHP) by Olivier Plathey. FPDF is released under a permissive license with no usage restrictions. This is an independent clean-room implementation in Nim; no PHP code was copied. See [License notes](#license-notes) for details.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Guide](#usage-guide)
  - [Creating a Document](#creating-a-document)
  - [Adding Pages](#adding-pages)
  - [Text Output](#text-output)
  - [Fonts](#fonts)
  - [Colors](#colors)
  - [Drawing](#drawing)
  - [Positioning and Margins](#positioning-and-margins)
  - [Header and Footer](#header-and-footer)
  - [Metadata](#metadata)
  - [Saving the Document](#saving-the-document)
- [API Reference](#api-reference)
- [Roadmap](#roadmap)
- [License Notes](#license-notes)
- [License](#license)

## Features

- 14 core PDF fonts (Courier, Helvetica, Times, Symbol, ZapfDingbats) with bold/italic/underline styles
- Text output: cells, multi-line cells with word wrapping, flowing text, absolute positioning
- Text alignment: left, center, right, justified
- Graphics primitives: lines, rectangles (stroke, fill, or both)
- RGB and grayscale colors for text, fill, and stroke
- Multiple page sizes (A3, A4, A5, Letter, Legal) and orientations
- Page rotation (0, 90, 180, 270 degrees)
- Automatic page breaks
- Header/footer callbacks
- Document metadata (title, author, subject, keywords)
- Multiple measurement units (mm, cm, inches, points)

## Installation

```bash
nimble install fpdf
```

### Dependencies

- Nim >= 2.0.0
- [zippy](https://github.com/guzba/zippy) >= 0.10.0
- [nimPNG](https://github.com/jangko/nimPNG) >= 0.3.0

## Quick Start

```nim
import fpdf

let doc = newFpdf()
doc.addPage()
doc.setFont("Helvetica", {fsBold}, 16)
doc.cell(0, 10, "Hello, World!")
doc.outputToFile("hello.pdf")
```

## Usage Guide

### Creating a Document

```nim
# Default: portrait A4, millimeters
let doc = newFpdf()

# Landscape, letter size, inches
let doc = newFpdf(orLandscape, utInch, PageLetter)

# Available page sizes: PageA3, PageA4, PageA5, PageLetter, PageLegal
# Available units: utMillimeter (default), utCentimeter, utInch, utPoint
```

### Adding Pages

```nim
doc.addPage()

# Landscape page
doc.addPage(orientation = some(orLandscape))

# Custom size
doc.addPage(size = some(PageA3))

# Rotated page (90, 180, 270)
doc.addPage(rotation = 90)
```

Pages are added automatically if you call `outputToFile` on an empty document. Automatic page breaks are enabled by default and can be controlled with `setAutoPageBreak`.

### Text Output

#### Cell

Outputs a single-line cell with optional border, background, and alignment.

```nim
doc.setFont("Helvetica", {}, 12)

# Simple text
doc.cell(40, 10, "Hello")

# Full-width cell, centered, with border, then move to next line
doc.cell(0, 10, "Centered Title", "1", 1, "C")

# Cell with fill
doc.setFillColor(230, 230, 230)
doc.cell(60, 8, "Highlighted", "1", 0, "L", true)
```

Parameters: `cell(w, h, txt, border, ln, align, fill, link)`

- `w` — cell width (0 = extend to right margin)
- `h` — cell height (default: 0)
- `txt` — text content
- `border` — `"0"` none, `"1"` full border
- `ln` — where to go after: `0` = right, `1` = next line, `2` = below
- `align` — `"L"` left, `"C"` center, `"R"` right
- `fill` — `true` to fill background with current fill color

#### MultiCell

Outputs text with automatic word wrapping. Each time a line reaches the right edge, a new line is started.

```nim
doc.multiCell(0, 5,
  "This is a long paragraph that will automatically wrap " &
  "across multiple lines. Justified alignment distributes " &
  "words evenly across each line.",
  "0", "J")
```

Parameters: `multiCell(w, h, txt, border, align, fill)`

- `align` — `"L"`, `"C"`, `"R"`, `"J"` (justified)

#### Write

Outputs flowing text from the current position. Text wraps automatically. Useful for inline text with mixed fonts.

```nim
doc.setFont("Helvetica", {}, 12)
doc.write(5, "This is normal text. ")
doc.setFont("Helvetica", {fsBold}, 12)
doc.write(5, "This is bold. ")
doc.setFont("Helvetica", {}, 12)
doc.write(5, "Back to normal.")
```

#### Text

Outputs text at an absolute position on the page.

```nim
doc.text(50, 100, "Positioned text")
```

#### Line Break

```nim
doc.ln()       # move down by height of last cell
doc.ln(10)     # move down by 10 mm
```

### Fonts

14 core PDF fonts are available — no font files needed.

```nim
# Font families: "Courier", "Helvetica", "Times", "Symbol", "ZapfDingbats"
# "Arial" is an alias for "Helvetica"

doc.setFont("Helvetica", {}, 12)              # regular
doc.setFont("Helvetica", {fsBold}, 14)        # bold
doc.setFont("Times", {fsItalic}, 11)          # italic
doc.setFont("Courier", {fsBold, fsItalic}, 10) # bold italic
doc.setFont("Helvetica", {fsUnderline}, 12)   # underline

# Change size only
doc.setFontSize(16)

# Measure text width
let w = doc.getStringWidth("Hello, World!")
```

### Colors

Colors use RGB values (0–255) or a single grayscale value.

```nim
# RGB
doc.setTextColor(255, 0, 0)     # red text
doc.setFillColor(200, 220, 255) # light blue fill
doc.setDrawColor(0, 0, 200)     # blue lines

# Grayscale (single value)
doc.setTextColor(128)           # gray text
doc.setDrawColor(0)             # black lines
```

### Drawing

```nim
# Line
doc.line(10, 20, 100, 20)

# Rectangle — stroke only
doc.setDrawColor(255, 0, 0)
doc.rect(10, 30, 40, 20, "D")

# Rectangle — fill only
doc.setFillColor(0, 255, 0)
doc.rect(60, 30, 40, 20, "F")

# Rectangle — stroke and fill
doc.setDrawColor(0, 0, 255)
doc.setFillColor(200, 200, 255)
doc.rect(110, 30, 40, 20, "DF")

# Set line width
doc.setLineWidth(0.5)
```

### Positioning and Margins

```nim
# Set margins (left, top, right)
doc.setMargins(15, 15, 15)
doc.setLeftMargin(20)
doc.setTopMargin(20)
doc.setRightMargin(20)

# Get/set position
let x = doc.getX()
let y = doc.getY()
doc.setX(50)
doc.setY(100)
doc.setXY(50, 100)

# Page dimensions
let pw = doc.getPageWidth()
let ph = doc.getPageHeight()

# Automatic page breaks
doc.setAutoPageBreak(true, 15)  # 15mm bottom margin

# Current page number
let page = doc.pageNo()
```

### Header and Footer

```nim
doc.setHeaderProc(proc(doc: Fpdf) =
  doc.setFont("Helvetica", {fsBold}, 12)
  doc.cell(0, 10, "My Document", "0", 0, "C")
  doc.ln(15)
)

doc.setFooterProc(proc(doc: Fpdf) =
  doc.setY(-15)
  doc.setFont("Helvetica", {fsItalic}, 8)
  doc.cell(0, 10, "Page " & $doc.pageNo(), "0", 0, "C")
)

# Enable page count placeholder — replaces {nb} with total page count
doc.aliasNbPages()
```

### Metadata

```nim
doc.setTitle("Annual Report 2024")
doc.setAuthor("John Smith")
doc.setSubject("Financial Summary")
doc.setKeywords("report finance annual")
doc.setCreator("MyApp")
```

### Saving the Document

```nim
# To file
doc.outputToFile("output.pdf")

# To string (binary)
let pdfBytes = doc.outputToString()

# To stream
import std/streams
let s = newFileStream("output.pdf", fmWrite)
doc.outputToStream(s)
s.close()
```

## API Reference

### Document Lifecycle

| Proc | Description |
|------|-------------|
| `newFpdf(orientation, unit, size)` | Create a new document |
| `addPage(orientation?, size?, rotation)` | Add a page |
| `close()` | Finalize the document |
| `outputToFile(filename)` | Write PDF to file |
| `outputToString(): string` | Get PDF as binary string |
| `outputToStream(stream)` | Write PDF to a stream |
| `pageNo(): int` | Current page number |

### Text

| Proc | Description |
|------|-------------|
| `cell(w, h?, txt?, border?, ln?, align?, fill?, link?)` | Output a single-line cell |
| `multiCell(w, h, txt, border?, align?, fill?)` | Output text with word wrapping |
| `write(h, txt, link?)` | Output flowing inline text |
| `text(x, y, txt)` | Output text at absolute position |
| `ln(h?)` | Line break |

### Fonts

| Proc | Description |
|------|-------------|
| `setFont(family, style?, size?)` | Set font family, style, and size |
| `setFontSize(size)` | Change font size |
| `getStringWidth(s): float64` | Get text width in current font |

### Colors

| Proc | Description |
|------|-------------|
| `setDrawColor(r, g?, b?)` | Set stroke color |
| `setFillColor(r, g?, b?)` | Set fill color |
| `setTextColor(r, g?, b?)` | Set text color |

### Drawing

| Proc | Description |
|------|-------------|
| `line(x1, y1, x2, y2)` | Draw a line |
| `rect(x, y, w, h, style?)` | Draw a rectangle (`"D"`, `"F"`, `"DF"`) |
| `setLineWidth(width)` | Set stroke width |

### Position and Margins

| Proc | Description |
|------|-------------|
| `setMargins(left, top, right?)` | Set page margins |
| `setLeftMargin(margin)` | Set left margin |
| `setTopMargin(margin)` | Set top margin |
| `setRightMargin(margin)` | Set right margin |
| `setAutoPageBreak(auto, margin?)` | Configure automatic page breaks |
| `getX() / setX(x)` | Get/set horizontal position |
| `getY() / setY(y, resetX?)` | Get/set vertical position |
| `setXY(x, y)` | Set both positions |
| `getPageWidth() / getPageHeight()` | Get page dimensions |

### Metadata and Display

| Proc | Description |
|------|-------------|
| `setTitle(title)` | Set document title |
| `setAuthor(author)` | Set document author |
| `setSubject(subject)` | Set document subject |
| `setKeywords(keywords)` | Set document keywords |
| `setCreator(creator)` | Set creator application |
| `aliasNbPages(alias?)` | Enable total page count substitution |
| `setDisplayMode(zoom, layout?)` | Set viewer zoom and layout mode |
| `setHeaderProc(callback)` | Set header callback |
| `setFooterProc(callback)` | Set footer callback |

### Types and Constants

```nim
# Page sizes
PageA3, PageA4, PageA5, PageLetter, PageLegal

# Units
utPoint, utMillimeter, utCentimeter, utInch

# Orientation
orPortrait, orLandscape

# Font style flags (used as set)
fsBold, fsItalic, fsUnderline

# Link helpers
noLink()              # no link
extLink(url)          # external URL
intLink(idx)          # internal document link
```

## Roadmap

### v0.2.0 — Links and Images

- [ ] Clickable links (internal cross-references and external URLs)
- [ ] Link annotations in `cell` and `write`
- [ ] JPEG image embedding (`DCTDecode`)
- [ ] PNG image embedding with transparency/alpha channel support

### v0.3.0 — Compression and Stability

- [ ] Deflate compression for page streams (`FlateDecode` via zippy)
- [ ] Comprehensive integration tests (multi-page, mixed orientations/sizes)
- [ ] Edge case hardening (empty cells, auto-width, state validation)
- [ ] `qpdf --check` validation for all generated PDFs

### v0.4.0 — Extended Drawing

- [ ] Circle and ellipse primitives
- [ ] Arc and curve drawing (Bezier)
- [ ] Dashed line styles
- [ ] Clipping regions

### v0.5.0 — Advanced Text

- [ ] TTF/OTF font embedding with subsetting
- [ ] Unicode text support (UTF-8 with ToUnicode CMap)
- [ ] Text rotation
- [ ] Character spacing control

### v1.0.0 — Production Ready

- [ ] Table helper (column layout with borders and alignment)
- [ ] Bookmarks / document outline
- [ ] PDF encryption (RC4/AES, password protection)
- [ ] PDF/A compliance mode
- [ ] Comprehensive documentation and examples

### Future Ideas

- HTML-to-PDF subset renderer
- SVG path rendering
- Barcode / QR code generation
- Multi-column layout
- Watermarks and layers (Optional Content Groups)
- Form fields (AcroForms)

## License Notes

FPDF's API design is inspired by [FPDF](http://www.fpdf.org/) by Olivier Plathey. Using the same API is legally and ethically clear:

1. **FPDF's license** explicitly permits use, copying, modification, and distribution with no restrictions whatsoever.
2. **The U.S. Supreme Court** ruled in *Google LLC v. Oracle America, Inc.* (2021) that reimplementing an API constitutes fair use — even when copying exact method names and structure.
3. **16+ ports** of FPDF exist in other languages (Go, Python, Java, Ruby, C++, etc.), all using the same API, and are [officially listed](http://www.fpdf.org/en/links.php) on fpdf.org.

FPDF is an independent clean-room implementation. No PHP source code was copied.

## License

MIT — see [LICENSE](LICENSE).
