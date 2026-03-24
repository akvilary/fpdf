import std/[strutils, options]
import ./types
import ./buffer
import ./utils
import ./fonts
import ./state

# ---- Graphics primitives ----

proc setLineWidth*(doc: Fpdf, width: float64) =
  doc.lineWidth = width
  if doc.page > 0:
    doc.output(fmtFloat(width * doc.k) & " w")

proc line*(doc: Fpdf, x1, y1, x2, y2: float64) =
  doc.output(
    fmtFloat(x1 * doc.k) & " " & fmtFloat(yToPdf(doc.h, y1, doc.k)) & " m " &
    fmtFloat(x2 * doc.k) & " " & fmtFloat(yToPdf(doc.h, y2, doc.k)) & " l S")

proc rect*(doc: Fpdf, x, y, w, h: float64, style: string = "") =
  let op = case style.toUpperAscii()
    of "F": "f"
    of "FD", "DF": "B"
    else: "S"
  doc.output(
    fmtFloat(x * doc.k) & " " & fmtFloat(yToPdf(doc.h, y, doc.k)) & " " &
    fmtFloat(w * doc.k) & " " & fmtFloat(-h * doc.k) & " re " & op)

# ---- Underline helper ----

proc doUnderline(doc: Fpdf, x, y: float64, txt: string): string =
  let up = float64(doc.currentFont.up) / 1000.0 * doc.fontSizePt
  let ut = float64(doc.currentFont.ut) / 1000.0 * doc.fontSizePt
  let w = doc.getStringWidth(txt) + doc.ws * float64(txt.count(' '))
  result = fmtFloat(x * doc.k) & " " &
           fmtFloat(yToPdf(doc.h, y - up / doc.k, doc.k)) & " " &
           fmtFloat(w * doc.k) & " " & fmtFloat(-ut) & " re f"

# ---- Auto page break check ----

proc acceptPageBreak*(doc: Fpdf): bool =
  if doc.acceptPageBreakProc != nil:
    return doc.acceptPageBreakProc(doc)
  return doc.autoPageBreak

# ---- Text output ----

proc cell*(doc: Fpdf, w: float64, h: float64 = 0, txt: string = "",
           border: string = "0", ln: int = 0, align: string = "",
           fill: bool = false, link: LinkTarget = noLink()) =
  if not doc.fontSet:
    doc.error("No font has been set")

  let k = doc.k
  var cellW = w
  if cellW == 0:
    cellW = doc.w - doc.rMargin - doc.x

  var s = ""

  # Check if we need fill or border
  let hasFill = fill
  let hasBorder = border != "0" and border != ""

  if hasFill or hasBorder:
    if hasFill:
      let op = if hasBorder: "B" else: "f"
      s.add(fmtFloat(doc.x * k) & " " & fmtFloat(yToPdf(doc.h, doc.y, k)) & " " &
            fmtFloat(cellW * k) & " " & fmtFloat(-h * k) & " re " & op & " ")
    if hasBorder:
      if border == "1":
        s.add(fmtFloat(doc.x * k) & " " & fmtFloat(yToPdf(doc.h, doc.y, k)) & " " &
              fmtFloat(cellW * k) & " " & fmtFloat(-h * k) & " re S ")
      else:
        let x = doc.x
        let y = doc.y
        if 'L' in border:
          s.add(fmtFloat(x * k) & " " & fmtFloat(yToPdf(doc.h, y, k)) & " m " &
                fmtFloat(x * k) & " " & fmtFloat(yToPdf(doc.h, y + h, k)) & " l S ")
        if 'T' in border:
          s.add(fmtFloat(x * k) & " " & fmtFloat(yToPdf(doc.h, y, k)) & " m " &
                fmtFloat((x + cellW) * k) & " " & fmtFloat(yToPdf(doc.h, y, k)) & " l S ")
        if 'R' in border:
          s.add(fmtFloat((x + cellW) * k) & " " & fmtFloat(yToPdf(doc.h, y, k)) & " m " &
                fmtFloat((x + cellW) * k) & " " & fmtFloat(yToPdf(doc.h, y + h, k)) & " l S ")
        if 'B' in border:
          s.add(fmtFloat(x * k) & " " & fmtFloat(yToPdf(doc.h, y + h, k)) & " m " &
                fmtFloat((x + cellW) * k) & " " & fmtFloat(yToPdf(doc.h, y + h, k)) & " l S ")

  if txt.len > 0:
    var dx: float64
    let actualAlign = if align.len == 0: "L" else: align.toUpperAscii()
    case actualAlign
    of "R":
      dx = cellW - doc.cMargin - doc.getStringWidth(txt)
    of "C":
      dx = (cellW - doc.getStringWidth(txt)) / 2.0
    else: # "L" or default
      dx = doc.cMargin

    if doc.colorFlag:
      s.add("q " & doc.textColor & " ")

    s.add("BT " &
          fmtFloat((doc.x + dx) * k) & " " &
          fmtFloat(yToPdf(doc.h, doc.y + 0.5 * h + 0.3 * doc.fontSize, k)) &
          " Td " & textString(txt) & " Tj ET")

    if fsUnderline in doc.fontStyle:
      s.add(" " & doc.doUnderline(doc.x + dx, doc.y + 0.5 * h + 0.3 * doc.fontSize, txt))

    if doc.colorFlag:
      s.add(" Q")

    if link.isInternal or link.url.len > 0:
      doc.pageLinks[doc.page - 1].add(PageLink(
        x: doc.x + dx,
        y: doc.y + 0.5 * h - 0.5 * doc.fontSize,
        w: doc.getStringWidth(txt),
        h: doc.fontSize,
        link: link
      ))

  if s.len > 0:
    doc.output(s)

  doc.lastH = h

  # Update position
  case ln
  of 1:
    # Next line
    doc.y += h
    doc.x = doc.lMargin
  of 2:
    # Below
    doc.y += h
  else:
    # Right
    doc.x += cellW

proc multiCell*(doc: Fpdf, w: float64, h: float64, txt: string,
                border: string = "0", align: string = "J",
                fill: bool = false) =
  if not doc.fontSet:
    doc.error("No font has been set")

  let cw = doc.currentFont.cw
  var cellW = w
  if cellW == 0:
    cellW = doc.w - doc.rMargin - doc.x

  let wmax = (cellW - 2.0 * doc.cMargin) * 1000.0 / doc.fontSize
  let actualAlign = align.toUpperAscii()

  let text = txt.replace("\r", "")
  var nb = text.len
  if nb > 0 and text[nb - 1] == '\n':
    nb -= 1

  var b = border
  var b2 = ""
  if border == "1":
    b = "LRT"
    b2 = "LR"
  elif border.len > 0 and border != "0":
    b2 = ""
    if 'L' in border: b2.add("L")
    if 'R' in border: b2.add("R")
    b = if 'T' in border: b2 & "T" else: b2

  var i = 0
  var nl = 1

  while i < nb:
    # Find end of line
    var sep = -1
    var lineWidth = 0.0
    var j = i
    var ls = 0

    while j < nb:
      let c = text[j]
      if c == '\n':
        break
      if c == ' ':
        sep = j
        ls += 1
      lineWidth += float64(cw[ord(c) and 0xFF])
      if lineWidth > wmax:
        break
      j += 1

    var lineEnd: int
    var nextStart: int

    if lineWidth > wmax:
      # Word wrap
      if sep == -1:
        # No space found, force break
        if j == i:
          j = i + 1
        lineEnd = j
        nextStart = j
      else:
        lineEnd = sep
        nextStart = sep + 1
    else:
      lineEnd = j
      nextStart = j
      if j < nb and text[j] == '\n':
        nextStart = j + 1

    let lineText = text[i ..< lineEnd]

    # Justified text: set word spacing
    if actualAlign == "J" and lineWidth <= wmax and j < nb and text[j] != '\n':
      let spaceCount = lineText.count(' ')
      if spaceCount > 0:
        doc.ws = (cellW - 2.0 * doc.cMargin - float64(lineWidth) * doc.fontSize / 1000.0) /
                 float64(spaceCount)
        doc.output(fmtFloat(doc.ws * doc.k) & " Tw")
    else:
      if doc.ws > 0:
        doc.ws = 0
        doc.output("0 Tw")

    let cellBorder = if nl == 1: b else: b2
    doc.cell(cellW, h, lineText, cellBorder, 2,
             (if actualAlign == "J": "L" else: actualAlign), fill)

    i = nextStart
    nl += 1

    # Check page break
    if doc.y + h > doc.pageBreakTrigger and doc.acceptPageBreak():
      # Add bottom border before break if needed
      if 'B' in border:
        # The border will be part of the next page
        discard
      doc.addPage(some(doc.curOrientation), some(doc.curPageSize))
      doc.x = doc.lMargin

  # Reset word spacing
  if doc.ws > 0:
    doc.ws = 0
    doc.output("0 Tw")

  # Add bottom border on last line if needed
  # (handled via cell border parameter)

proc write*(doc: Fpdf, h: float64, txt: string,
            link: LinkTarget = noLink()) =
  if not doc.fontSet:
    doc.error("No font has been set")

  let cw = doc.currentFont.cw
  let cellW = doc.w - doc.rMargin - doc.x
  let wmax = (cellW) * 1000.0 / doc.fontSize

  let text = txt.replace("\r", "")
  let nb = text.len

  var i = 0
  while i < nb:
    # Find end of line
    var sep = -1
    var lineWidth = 0.0
    var j = i
    let currentW = doc.w - doc.rMargin - doc.x

    while j < nb:
      let c = text[j]
      if c == '\n':
        break
      if c == ' ':
        sep = j
      lineWidth += float64(cw[ord(c) and 0xFF])
      if lineWidth > currentW * 1000.0 / doc.fontSize:
        break
      j += 1

    var lineEnd: int
    var nextStart: int

    if lineWidth > currentW * 1000.0 / doc.fontSize:
      if sep == -1:
        if doc.x > doc.lMargin:
          # Move to next line
          doc.x = doc.lMargin
          doc.y += h
          continue
        if j == i:
          j = i + 1
        lineEnd = j
        nextStart = j
      else:
        lineEnd = sep
        nextStart = sep + 1
    else:
      lineEnd = j
      nextStart = j
      if j < nb and text[j] == '\n':
        nextStart = j + 1

    let lineText = text[i ..< lineEnd]
    doc.cell(doc.getStringWidth(lineText), h, lineText, "0", (if j < nb and text[j] != '\n': 0 else: 2), "", false, link)

    i = nextStart

proc text*(doc: Fpdf, x, y: float64, txt: string) =
  if not doc.fontSet:
    doc.error("No font has been set")
  var s = ""
  if doc.colorFlag:
    s.add("q " & doc.textColor & " ")
  s.add("BT " &
        fmtFloat(x * doc.k) & " " &
        fmtFloat(yToPdf(doc.h, y, doc.k)) &
        " Td " & textString(txt) & " Tj ET")
  if fsUnderline in doc.fontStyle:
    s.add(" " & doc.doUnderline(x, y, txt))
  if doc.colorFlag:
    s.add(" Q")
  doc.output(s)

proc ln*(doc: Fpdf, h: float64 = -1) =
  doc.x = doc.lMargin
  if h < 0:
    doc.y += doc.lastH
  else:
    doc.y += h
