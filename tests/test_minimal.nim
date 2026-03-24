import std/strutils
import ../src/fpdf

proc main() =
  let doc = newFpdf()
  doc.addPage()
  doc.outputToFile("tests/test_minimal.pdf")

  assert doc.pageNo() == 1
  assert doc.state == dsClosed

  # Verify PDF structure
  let content = readFile("tests/test_minimal.pdf")
  assert content.startsWith("%PDF-1.3")
  assert content.contains("%%EOF")
  assert content.contains("/Type /Page")
  assert content.contains("/Type /Catalog")
  assert content.contains("/Type /Pages")

  echo "test_minimal PASSED"

main()
