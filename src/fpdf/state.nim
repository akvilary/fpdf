import std/[tables, streams, options]
import ./types
import ./utils
import ./buffer

proc newFpdf*(orientation = orPortrait, unit = utMillimeter,
              size = PageA4): Fpdf =
  result = Fpdf()

  # State machine
  result.state = dsInitial
  result.page = 0
  result.n = 2
  result.offsets = @[]
  result.buffer = ""
  result.pages = @[]
  result.pageInfos = @[]

  # Scale factor
  result.k = scaleFactorForUnit(unit)

  # Page size
  result.defPageSize = size
  result.curPageSize = size

  # Orientation
  result.defOrientation = orientation
  result.curOrientation = orientation
  if orientation == orPortrait:
    result.w = size.wPt / result.k
    result.h = size.hPt / result.k
  else:
    result.w = size.hPt / result.k
    result.h = size.wPt / result.k
  result.wPt = result.w * result.k
  result.hPt = result.h * result.k
  result.curRotation = 0

  # Margins (default 1cm = 10mm)
  let margin = 28.35 / result.k  # 1cm in user units
  result.lMargin = margin
  result.rMargin = margin
  result.tMargin = margin
  result.bMargin = margin * 2
  result.cMargin = margin / 10.0

  # Position
  result.x = result.lMargin
  result.y = result.tMargin
  result.lastH = 0

  # Fonts
  result.fontFamily = ""
  result.fontStyle = {}
  result.fontSizePt = 12.0
  result.fontSize = result.fontSizePt / result.k
  result.fontSet = false
  result.fonts = initOrderedTable[string, FontInfo]()

  # Colors
  result.drawColor = "0 G"
  result.fillColor = "0 g"
  result.textColor = "0 g"
  result.colorFlag = false
  result.withAlpha = false

  # Graphics
  result.lineWidth = 0.567 / result.k  # 0.2mm in user units

  # Images
  result.images = initOrderedTable[string, ImageInfo]()

  # Links
  result.links = @[]
  result.pageLinks = @[]

  # Page breaks
  result.autoPageBreak = true
  result.pageBreakTrigger = result.h - result.bMargin
  result.inHeader = false
  result.inFooter = false

  # Callbacks
  result.headerProc = nil
  result.footerProc = nil
  result.acceptPageBreakProc = nil

  # Metadata & display
  result.aliasNbPagesStr = "{nb}"
  result.zoomMode = zmDefault
  result.zoomFactor = 0
  result.layoutMode = lmDefault
  result.metadata = initTable[string, string]()
  result.metadata["Producer"] = "FPDF 0.1"

  # Compression
  result.compress = true

  # Word spacing
  result.ws = 0

  # PDF version
  result.pdfVersion = "1.3"

# ---- Page lifecycle ----

proc beginPage(doc: Fpdf, orientation: Orientation, size: PageSize, rotation: int) =
  doc.page += 1
  doc.pages.add("")
  doc.state = dsActivePage

  # Set page dimensions
  doc.curOrientation = orientation
  doc.curPageSize = size
  doc.curRotation = rotation
  if orientation == orPortrait:
    doc.w = size.wPt / doc.k
    doc.h = size.hPt / doc.k
  else:
    doc.w = size.hPt / doc.k
    doc.h = size.wPt / doc.k
  doc.wPt = doc.w * doc.k
  doc.hPt = doc.h * doc.k
  doc.pageBreakTrigger = doc.h - doc.bMargin

  # Reset position
  doc.x = doc.lMargin
  doc.y = doc.tMargin

  # Page info
  doc.pageInfos.add(PageInfo(
    n: 0,
    size: size,
    orientation: orientation,
    rotation: rotation
  ))

  # Page links
  doc.pageLinks.add(@[])

proc endPage(doc: Fpdf) =
  doc.state = dsBetween

proc header*(doc: Fpdf) =
  if doc.headerProc != nil:
    doc.inHeader = true
    doc.headerProc(doc)
    doc.inHeader = false

proc footer*(doc: Fpdf) =
  if doc.footerProc != nil:
    doc.inFooter = true
    doc.footerProc(doc)
    doc.inFooter = false

import ./serialize

proc addPage*(doc: Fpdf, orientation = none(Orientation),
              size = none(PageSize), rotation = 0) =
  let actualOrientation = orientation.get(doc.defOrientation)
  let actualSize = size.get(doc.defPageSize)

  if doc.state == dsActivePage:
    # Close current page
    doc.footer()
    doc.endPage()
  elif doc.state == dsClosed:
    doc.error("Document is closed, cannot add page")

  doc.beginPage(actualOrientation, actualSize, rotation)

  # Restore drawing state on the new page
  doc.output(fmtFloat(doc.lineWidth * doc.k) & " w")
  if doc.drawColor != "0 G":
    doc.output(doc.drawColor)
  if doc.fillColor != "0 g":
    doc.output(doc.fillColor)

  # Set font on page if one was selected
  if doc.fontSet:
    doc.output("BT /F" & $doc.currentFont.i & " " &
               fmtFloat(doc.fontSizePt) & " Tf ET")

  doc.header()

proc pageNo*(doc: Fpdf): int =
  doc.page

proc close*(doc: Fpdf) =
  if doc.state == dsClosed:
    return
  if doc.page == 0:
    doc.addPage()
  doc.footer()
  doc.endPage()
  doc.endDoc()

# ---- Margins & Position ----

proc setMargins*(doc: Fpdf, left, top: float64, right: float64 = -1) =
  doc.lMargin = left
  doc.tMargin = top
  if right < 0:
    doc.rMargin = left
  else:
    doc.rMargin = right

proc setLeftMargin*(doc: Fpdf, margin: float64) =
  doc.lMargin = margin
  if doc.page > 0 and doc.x < margin:
    doc.x = margin

proc setTopMargin*(doc: Fpdf, margin: float64) =
  doc.tMargin = margin

proc setRightMargin*(doc: Fpdf, margin: float64) =
  doc.rMargin = margin

proc setAutoPageBreak*(doc: Fpdf, auto: bool, margin: float64 = 0) =
  doc.autoPageBreak = auto
  doc.bMargin = margin
  doc.pageBreakTrigger = doc.h - margin

proc getPageWidth*(doc: Fpdf): float64 = doc.w
proc getPageHeight*(doc: Fpdf): float64 = doc.h

proc getX*(doc: Fpdf): float64 = doc.x
proc setX*(doc: Fpdf, x: float64) =
  if x >= 0:
    doc.x = x
  else:
    doc.x = doc.w + x

proc getY*(doc: Fpdf): float64 = doc.y
proc setY*(doc: Fpdf, y: float64, resetX = true) =
  if resetX:
    doc.x = doc.lMargin
  if y >= 0:
    doc.y = y
  else:
    doc.y = doc.h + y

proc setXY*(doc: Fpdf, x, y: float64) =
  doc.setY(y, resetX = false)
  doc.setX(x)

# ---- Metadata ----

proc setTitle*(doc: Fpdf, title: string) =
  doc.metadata["Title"] = title

proc setAuthor*(doc: Fpdf, author: string) =
  doc.metadata["Author"] = author

proc setSubject*(doc: Fpdf, subject: string) =
  doc.metadata["Subject"] = subject

proc setKeywords*(doc: Fpdf, keywords: string) =
  doc.metadata["Keywords"] = keywords

proc setCreator*(doc: Fpdf, creator: string) =
  doc.metadata["Creator"] = creator

proc aliasNbPages*(doc: Fpdf, alias = "{nb}") =
  doc.aliasNbPagesStr = alias

# ---- Display mode ----

proc setDisplayMode*(doc: Fpdf, zoom: ZoomMode, layout = lmDefault) =
  doc.zoomMode = zoom
  doc.layoutMode = layout

proc setDisplayMode*(doc: Fpdf, zoomFactor: float64, layout = lmDefault) =
  doc.zoomMode = zmCustom
  doc.zoomFactor = zoomFactor
  doc.layoutMode = layout

# ---- Header/Footer callbacks ----

proc setHeaderProc*(doc: Fpdf, p: proc(doc: Fpdf) {.closure.}) =
  doc.headerProc = p

proc setFooterProc*(doc: Fpdf, p: proc(doc: Fpdf) {.closure.}) =
  doc.footerProc = p

# ---- Output ----

proc outputToString*(doc: Fpdf): string =
  if doc.state < dsClosed:
    doc.close()
  result = doc.buffer

proc outputToFile*(doc: Fpdf, filename: string) =
  let content = doc.outputToString()
  writeFile(filename, content)

proc outputToStream*(doc: Fpdf, s: Stream) =
  let content = doc.outputToString()
  s.write(content)
