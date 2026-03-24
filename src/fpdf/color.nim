import ./types
import ./buffer
import ./utils

proc setDrawColor*(doc: Fpdf, r: int, g: int = -1, b: int = -1) =
  if g == -1:
    doc.drawColor = fmtFloat(float64(r) / 255.0) & " G"
  else:
    doc.drawColor = fmtFloat(float64(r) / 255.0) & " " &
                    fmtFloat(float64(g) / 255.0) & " " &
                    fmtFloat(float64(b) / 255.0) & " RG"
  if doc.page > 0:
    doc.output(doc.drawColor)

proc setFillColor*(doc: Fpdf, r: int, g: int = -1, b: int = -1) =
  if g == -1:
    doc.fillColor = fmtFloat(float64(r) / 255.0) & " g"
  else:
    doc.fillColor = fmtFloat(float64(r) / 255.0) & " " &
                    fmtFloat(float64(g) / 255.0) & " " &
                    fmtFloat(float64(b) / 255.0) & " rg"
  doc.colorFlag = doc.fillColor != doc.textColor
  if doc.page > 0:
    doc.output(doc.fillColor)

proc setTextColor*(doc: Fpdf, r: int, g: int = -1, b: int = -1) =
  if g == -1:
    doc.textColor = fmtFloat(float64(r) / 255.0) & " g"
  else:
    doc.textColor = fmtFloat(float64(r) / 255.0) & " " &
                    fmtFloat(float64(g) / 255.0) & " " &
                    fmtFloat(float64(b) / 255.0) & " rg"
  doc.colorFlag = doc.fillColor != doc.textColor
