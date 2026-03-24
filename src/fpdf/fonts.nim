import std/[tables, strutils]
import ./types
import ./buffer
import ./utils
import ./fontmetrics/courier
import ./fontmetrics/helvetica
import ./fontmetrics/times
import ./fontmetrics/symbol
import ./fontmetrics/zapfdingbats

type
  CoreFontData = object
    name: string
    cw: array[256, int]

const coreFontMap: Table[string, CoreFontData] = {
  "courier":      CoreFontData(name: "Courier", cw: CourierCw),
  "courierB":     CoreFontData(name: "Courier-Bold", cw: CourierCw),
  "courierI":     CoreFontData(name: "Courier-Oblique", cw: CourierCw),
  "courierBI":    CoreFontData(name: "Courier-BoldOblique", cw: CourierCw),
  "helvetica":    CoreFontData(name: "Helvetica", cw: HelveticaCw),
  "helveticaB":   CoreFontData(name: "Helvetica-Bold", cw: HelveticaBoldCw),
  "helveticaI":   CoreFontData(name: "Helvetica-Oblique", cw: HelveticaObliqueCw),
  "helveticaBI":  CoreFontData(name: "Helvetica-BoldOblique", cw: HelveticaBoldObliqueCw),
  "times":        CoreFontData(name: "Times-Roman", cw: TimesRomanCw),
  "timesB":       CoreFontData(name: "Times-Bold", cw: TimesBoldCw),
  "timesI":       CoreFontData(name: "Times-Italic", cw: TimesItalicCw),
  "timesBI":      CoreFontData(name: "Times-BoldItalic", cw: TimesBoldItalicCw),
  "symbol":       CoreFontData(name: "Symbol", cw: SymbolCw),
  "zapfdingbats": CoreFontData(name: "ZapfDingbats", cw: ZapfDingbatsCw),
}.toTable

proc fontKey*(family: string, style: FontStyle): string =
  result = family.toLowerAscii()
  if fsBold in style:
    result.add("B")
  if fsItalic in style:
    result.add("I")

proc styleStr(style: FontStyle): string =
  if fsBold in style:
    result.add("B")
  if fsItalic in style:
    result.add("I")

proc setFont*(doc: Fpdf, family: string, style: FontStyle = {},
              size: float64 = 0) =
  let actualFamily = if family.len == 0: doc.fontFamily
                     else: family.toLowerAscii()

  # Normalize: "arial" -> "helvetica"
  let normalizedFamily = if actualFamily == "arial": "helvetica"
                         else: actualFamily

  # Underline is separate from font selection
  let fontStyleOnly = style - {fsUnderline}

  let key = fontKey(normalizedFamily, fontStyleOnly)

  # Register font if not already done
  if key notin doc.fonts:
    if key notin coreFontMap:
      doc.error("Undefined font: " & normalizedFamily & " " & styleStr(fontStyleOnly))

    let data = coreFontMap[key]
    let idx = doc.fonts.len + 1
    doc.fonts[key] = FontInfo(
      i: idx,
      fontType: "Core",
      name: data.name,
      up: -100,
      ut: 50,
      cw: data.cw,
      n: 0,
    )

  # Set current font
  doc.fontFamily = normalizedFamily
  doc.fontStyle = style
  doc.currentFont = doc.fonts[key]
  doc.fontSet = true

  let actualSize = if size > 0: size else: doc.fontSizePt
  doc.fontSizePt = actualSize
  doc.fontSize = actualSize / doc.k

  # Output font selection if on a page
  if doc.page > 0:
    doc.output("BT /F" & $doc.currentFont.i & " " &
               fmtFloat(doc.fontSizePt) & " Tf ET")

proc setFontSize*(doc: Fpdf, size: float64) =
  if doc.fontSizePt == size:
    return
  doc.fontSizePt = size
  doc.fontSize = size / doc.k
  if doc.page > 0 and doc.fontSet:
    doc.output("BT /F" & $doc.currentFont.i & " " &
               fmtFloat(doc.fontSizePt) & " Tf ET")

proc getStringWidth*(doc: Fpdf, s: string): float64 =
  if not doc.fontSet:
    doc.error("No font has been set")
  var w = 0
  for ch in s:
    w += doc.currentFont.cw[ord(ch) and 0xFF]
  result = float64(w) * doc.fontSize / 1000.0
