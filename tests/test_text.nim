import std/strutils
import ../src/fpdf

proc main() =
  let doc = newFpdf()
  doc.addPage()

  # Title
  doc.setFont("Helvetica", {fsBold}, 16)
  doc.cell(0, 10, "NimFPDF Test Document", "0", 1, "C")
  doc.ln(5)

  # Horizontal line
  doc.setDrawColor(0, 0, 200)
  doc.line(10, doc.getY(), 200, doc.getY())
  doc.ln(5)

  # Regular text
  doc.setFont("Helvetica", {}, 12)
  doc.setTextColor(0)
  doc.cell(0, 6, "This is a test of Cell with left alignment.", "0", 1)
  doc.cell(0, 6, "This is center-aligned text.", "0", 1, "C")
  doc.cell(0, 6, "This is right-aligned text.", "0", 1, "R")
  doc.ln(5)

  # Bordered cells
  doc.setFont("Times", {}, 12)
  doc.cell(60, 8, "Cell with border", "1", 0)
  doc.cell(60, 8, "Another cell", "1", 0, "C")
  doc.cell(60, 8, "Right aligned", "1", 1, "R")
  doc.ln(3)

  # Fill
  doc.setFillColor(200, 220, 255)
  doc.cell(0, 8, "Cell with fill", "1", 1, "L", true)
  doc.ln(3)

  # MultiCell
  doc.setFont("Helvetica", {}, 10)
  doc.setTextColor(50, 50, 50)
  let longText = "This is a long paragraph that should automatically wrap " &
    "across multiple lines using the MultiCell function. The text will be " &
    "justified by default, distributing words evenly across each line. " &
    "This tests the word-wrapping algorithm and justified alignment."
  doc.multiCell(0, 5, longText, "0", "J")
  doc.ln(5)

  # Colors
  doc.setFont("Helvetica", {fsBold}, 12)
  doc.setTextColor(255, 0, 0)
  doc.cell(0, 8, "Red text", "0", 1)
  doc.setTextColor(0, 128, 0)
  doc.cell(0, 8, "Green text", "0", 1)
  doc.setTextColor(0, 0, 255)
  doc.cell(0, 8, "Blue text", "0", 1)
  doc.ln(5)

  # Rectangles
  doc.setTextColor(0)
  doc.setDrawColor(255, 0, 0)
  doc.rect(10, doc.getY(), 30, 15, "D")  # stroke only
  doc.setFillColor(0, 255, 0)
  doc.rect(50, doc.getY(), 30, 15, "F")  # fill only
  doc.setDrawColor(0, 0, 255)
  doc.setFillColor(200, 200, 255)
  doc.rect(90, doc.getY(), 30, 15, "DF") # stroke + fill

  doc.outputToFile("tests/test_text.pdf")

  assert doc.pageNo() == 1
  let content = readFile("tests/test_text.pdf")
  assert content.contains("/Type /Font")
  assert content.contains("BT")

  echo "test_text PASSED"

main()
