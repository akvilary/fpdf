import std/[strutils, math]
import ../src/fpdf

proc main() =
  let doc = newFpdf()
  doc.addPage()

  # Test all 14 base fonts can be set
  doc.setFont("Courier", {}, 12)
  assert doc.currentFont.name == "Courier"

  doc.setFont("Courier", {fsBold}, 12)
  assert doc.currentFont.name == "Courier-Bold"

  doc.setFont("Helvetica", {}, 12)
  assert doc.currentFont.name == "Helvetica"

  doc.setFont("Helvetica", {fsBold, fsItalic}, 12)
  assert doc.currentFont.name == "Helvetica-BoldOblique"

  doc.setFont("Times", {}, 12)
  assert doc.currentFont.name == "Times-Roman"

  doc.setFont("Times", {fsBold}, 12)
  assert doc.currentFont.name == "Times-Bold"

  doc.setFont("Times", {fsItalic}, 12)
  assert doc.currentFont.name == "Times-Italic"

  doc.setFont("Times", {fsBold, fsItalic}, 12)
  assert doc.currentFont.name == "Times-BoldItalic"

  doc.setFont("Symbol", {}, 12)
  assert doc.currentFont.name == "Symbol"

  doc.setFont("ZapfDingbats", {}, 12)
  assert doc.currentFont.name == "ZapfDingbats"

  # Test arial alias
  doc.setFont("Arial", {}, 12)
  assert doc.currentFont.name == "Helvetica"

  # Test GetStringWidth for Courier (monospaced, all 600)
  doc.setFont("Courier", {}, 10)
  let w = doc.getStringWidth("Hello")
  # 5 chars * 600 / 1000 * (10 / k)
  # fontSize = 10 / 2.835 = 3.527
  # w = 5 * 600 * 3.527 / 1000 = 10.581
  assert abs(w - 5.0 * 600.0 * doc.fontSize / 1000.0) < 0.001

  # Test GetStringWidth for Helvetica
  doc.setFont("Helvetica", {}, 10)
  let wH = doc.getStringWidth("A")
  # 'A' = char 65, Helvetica width = 667
  assert abs(wH - 667.0 * doc.fontSize / 1000.0) < 0.001

  doc.outputToFile("tests/test_fonts.pdf")
  echo "test_fonts PASSED"

main()
