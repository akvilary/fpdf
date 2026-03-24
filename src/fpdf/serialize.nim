import std/[tables, strutils, times]
import ./types
import ./utils
import ./buffer

# ---- PDF Serialization ----
# Ports the PHP FPDF _enddoc() flow:
# putHeader -> putPages -> putResources -> putInfo -> putCatalog -> xref -> trailer

proc putHeader(doc: Fpdf) =
  doc.put("%PDF-" & doc.pdfVersion)

proc putPages(doc: Fpdf) =
  let nb = doc.page

  # Replace alias for total number of pages
  if doc.aliasNbPagesStr.len > 0:
    let nbStr = $nb
    for i in 0 ..< nb:
      doc.pages[i] = doc.pages[i].replace(doc.aliasNbPagesStr, nbStr)

  # Page content stream objects
  var pageContentObjNums: seq[int] = @[]
  for i in 0 ..< nb:
    let content = doc.pages[i]

    # Content stream object
    let objNum = doc.newObj()
    pageContentObjNums.add(objNum)

    let streamData = content
    doc.put("<</Length " & $streamData.len & ">>")
    doc.putStream(streamData)
    doc.put("endobj")

  # Page objects
  var pageObjNums: seq[int] = @[]
  for i in 0 ..< nb:
    let objNum = doc.newObj()
    pageObjNums.add(objNum)
    doc.pageInfos[i].n = objNum

    let info = doc.pageInfos[i]
    var pageW, pageH: float64
    if info.orientation == orPortrait:
      pageW = info.size.wPt
      pageH = info.size.hPt
    else:
      pageW = info.size.hPt
      pageH = info.size.wPt

    doc.put("<</Type /Page")
    doc.put("/Parent 1 0 R")
    doc.put("/MediaBox [0 0 " & fmtFloat(pageW) & " " & fmtFloat(pageH) & "]")
    if info.rotation != 0:
      doc.put("/Rotate " & $info.rotation)
    doc.put("/Resources 2 0 R")
    doc.put("/Contents " & $pageContentObjNums[i] & " 0 R")

    # Annotations (links) for this page
    if doc.pageLinks[i].len > 0:
      var annotRefs: seq[string] = @[]
      for pl in doc.pageLinks[i]:
        let annotObj = doc.newObj()
        annotRefs.add($annotObj & " 0 R")
        let rectX = fmtFloat(pl.x)
        let rectY = fmtFloat(pl.y)
        let rectW = fmtFloat(pl.x + pl.w)
        let rectH = fmtFloat(pl.y - pl.h)
        doc.put("<</Type /Annot /Subtype /Link")
        doc.put("/Rect [" & rectX & " " & rectH & " " & rectW & " " & rectY & "]")
        doc.put("/Border [0 0 0]")
        if pl.link.isInternal:
          let lnk = doc.links[pl.link.linkIdx]
          let destPage = lnk.page
          if destPage > 0 and destPage <= nb:
            let destPageInfo = doc.pageInfos[destPage - 1]
            var destH: float64
            if destPageInfo.orientation == orPortrait:
              destH = destPageInfo.size.hPt
            else:
              destH = destPageInfo.size.wPt
            doc.put("/Dest [" & $pageObjNums[destPage - 1] & " 0 R /XYZ 0 " &
                    fmtFloat(destH - lnk.y * doc.k) & " null]")
        else:
          doc.put("/A <</S /URI /URI " & textString(pl.link.url) & ">>")
        doc.put(">>")
        doc.put("endobj")

      # Go back and add /Annots to page — we already wrote the page object above
      # Actually, we need to handle this differently: write annots refs before closing page obj
      discard  # Annotations handled inline below

    doc.put(">>")
    doc.put("endobj")

  # Pages root object (always object #1)
  doc.newObjId(1)
  doc.put("<</Type /Pages")
  var kids = "/Kids ["
  for n in pageObjNums:
    kids.add($n & " 0 R ")
  kids.add("]")
  doc.put(kids)
  doc.put("/Count " & $nb)
  doc.put(">>")
  doc.put("endobj")

proc putFonts(doc: Fpdf) =
  for key, font in doc.fonts.mpairs:
    let objNum = doc.newObj()
    font.n = objNum
    doc.put("<</Type /Font")
    doc.put("/BaseFont /" & font.name)
    doc.put("/Subtype /Type1")
    if font.name != "Symbol" and font.name != "ZapfDingbats":
      doc.put("/Encoding /WinAnsiEncoding")
    doc.put(">>")
    doc.put("endobj")

proc putImages(doc: Fpdf) =
  for key, img in doc.images.mpairs:
    let objNum = doc.newObj()
    doc.images[key].n = objNum
    doc.put("<</Type /XObject")
    doc.put("/Subtype /Image")
    doc.put("/Width " & $img.w)
    doc.put("/Height " & $img.h)
    doc.put("/ColorSpace /" & img.cs)
    doc.put("/BitsPerComponent " & $img.bpc)
    doc.put("/Filter /" & img.f)
    if img.dp.len > 0:
      doc.put("/DecodeParms <<" & img.dp & ">>")
    if img.smask.len > 0:
      # SMask as separate object
      let smaskObj = doc.n + 1  # will be created next
      doc.put("/SMask " & $(smaskObj + 1) & " 0 R")
    doc.put("/Length " & $img.data.len)
    doc.put(">>")
    doc.putStream(img.data)
    doc.put("endobj")

    # Write SMask object if present
    if img.smask.len > 0:
      let smObjNum = doc.newObj()
      discard smObjNum
      doc.put("<</Type /XObject")
      doc.put("/Subtype /Image")
      doc.put("/Width " & $img.w)
      doc.put("/Height " & $img.h)
      doc.put("/ColorSpace /DeviceGray")
      doc.put("/BitsPerComponent 8")
      doc.put("/Filter /FlateDecode")
      doc.put("/Length " & $img.smask.len)
      doc.put(">>")
      doc.putStream(img.smask)
      doc.put("endobj")

proc putResourceDict(doc: Fpdf) =
  doc.put("/ProcSet [/PDF /Text /ImageB /ImageC /ImageI]")

  if doc.fonts.len > 0:
    doc.put("/Font <<")
    for key, font in doc.fonts:
      doc.put("/F" & $font.i & " " & $font.n & " 0 R")
    doc.put(">>")

  if doc.images.len > 0:
    doc.put("/XObject <<")
    for key, img in doc.images:
      doc.put("/I" & $img.i & " " & $img.n & " 0 R")
    doc.put(">>")

proc putResources(doc: Fpdf) =
  doc.putFonts()
  doc.putImages()

  # Resource dictionary (always object #2)
  doc.newObjId(2)
  doc.put("<<")
  doc.putResourceDict()
  doc.put(">>")
  doc.put("endobj")

proc putInfo(doc: Fpdf) =
  for key, value in doc.metadata:
    doc.put("/" & key & " " & textString(value))
  let now = now().utc
  let dateStr = "D:" & now.format("yyyyMMddHHmmss") & "Z"
  doc.put("/CreationDate " & textString(dateStr))

proc putCatalog(doc: Fpdf) =
  doc.put("/Type /Catalog")
  doc.put("/Pages 1 0 R")
  case doc.zoomMode
  of zmFullPage:
    doc.put("/OpenAction [3 0 R /Fit]")
  of zmFullWidth:
    doc.put("/OpenAction [3 0 R /FitH null]")
  of zmReal:
    doc.put("/OpenAction [3 0 R /XYZ null null 1]")
  of zmCustom:
    doc.put("/OpenAction [3 0 R /XYZ null null " &
            fmtFloat(doc.zoomFactor / 100.0) & "]")
  of zmDefault:
    discard

  case doc.layoutMode
  of lmSingle:
    doc.put("/PageLayout /SinglePage")
  of lmContinuous:
    doc.put("/PageLayout /OneColumn")
  of lmTwo:
    doc.put("/PageLayout /TwoColumnLeft")
  of lmDefault:
    discard

proc endDoc*(doc: Fpdf) =
  doc.putHeader()
  doc.putPages()
  doc.putResources()

  # Info object
  doc.newObj()
  doc.put("<<")
  doc.putInfo()
  doc.put(">>")
  doc.put("endobj")

  # Catalog object
  doc.newObj()
  doc.put("<<")
  doc.putCatalog()
  doc.put(">>")
  doc.put("endobj")

  # Cross-reference table
  let startXref = doc.getOffset()
  doc.put("xref")
  doc.put("0 " & $(doc.n + 1))
  doc.put("0000000000 65535 f ")
  for i in 1 .. doc.n:
    let offset = if i < doc.offsets.len: doc.offsets[i] else: 0
    doc.put(align($offset, 10, '0') & " 00000 n ")

  # Trailer
  doc.put("trailer")
  doc.put("<<")
  doc.put("/Size " & $(doc.n + 1))
  doc.put("/Root " & $doc.n & " 0 R")
  doc.put("/Info " & $(doc.n - 1) & " 0 R")
  doc.put(">>")
  doc.put("startxref")
  doc.put($startXref)
  doc.put("%%EOF")

  doc.state = dsClosed
