import std/[strutils, math]
import ./types

proc scaleFactorForUnit*(unit: Unit): float64 =
  case unit
  of utPoint: 1.0
  of utMillimeter: 72.0 / 25.4
  of utCentimeter: 72.0 / 2.54
  of utInch: 72.0

proc getPageSize*(name: string): PageSize =
  case name.toLowerAscii()
  of "a3": PageA3
  of "a4": PageA4
  of "a5": PageA5
  of "letter": PageLetter
  of "legal": PageLegal
  else:
    raise newException(FpdfError, "Unknown page size: " & name)

proc fmtFloat*(v: float64, decimals: int = 2): string =
  formatFloat(v, ffDecimal, decimals)

proc escape*(s: string): string =
  result = s
  result = result.replace("\\", "\\\\")
  result = result.replace("(", "\\(")
  result = result.replace(")", "\\)")
  result = result.replace("\r", "\\r")

proc textString*(s: string): string =
  "(" & escape(s) & ")"

proc yToPdf*(doc_h, y, k: float64): float64 =
  (doc_h - y) * k
