import ./types

proc error*(doc: Fpdf, msg: string) {.noreturn.} =
  raise newException(FpdfError, msg)

proc getOffset*(doc: Fpdf): int =
  doc.buffer.len

proc put*(doc: Fpdf, s: string) =
  doc.buffer.add(s)
  doc.buffer.add("\n")

proc output*(doc: Fpdf, s: string) =
  if doc.state != dsActivePage:
    doc.error("Cannot output content outside of a page")
  doc.pages[doc.page - 1].add(s)
  doc.pages[doc.page - 1].add("\n")

proc newObj*(doc: Fpdf): int {.discardable.} =
  doc.n += 1
  result = doc.n
  while doc.offsets.len < doc.n + 1:
    doc.offsets.add(0)
  doc.offsets[doc.n] = doc.getOffset()
  doc.put($doc.n & " 0 obj")

proc newObjId*(doc: Fpdf, id: int) =
  while doc.offsets.len < id + 1:
    doc.offsets.add(0)
  doc.offsets[id] = doc.getOffset()
  doc.put($id & " 0 obj")

proc putStream*(doc: Fpdf, data: string) =
  doc.put("stream")
  doc.put(data)
  doc.put("endstream")
