import std/tables

type
  Unit* = enum
    utPoint       ## 1 pt = 1/72 inch
    utMillimeter  ## default
    utCentimeter
    utInch

  Orientation* = enum
    orPortrait, orLandscape

  PageSize* = object
    wPt*, hPt*: float64  ## dimensions in points

  FontStyleFlag* = enum
    fsBold, fsItalic, fsUnderline

  FontStyle* = set[FontStyleFlag]

  Align* = enum
    alLeft, alCenter, alRight, alJustify

  ZoomMode* = enum
    zmDefault, zmFullPage, zmFullWidth, zmReal, zmCustom

  LayoutMode* = enum
    lmDefault, lmSingle, lmContinuous, lmTwo

  DocumentState* = enum
    dsInitial = 0
    dsBetween = 1
    dsActivePage = 2
    dsClosed = 3

  FontInfo* = object
    i*: int                  ## font index (1-based, for /F1, /F2...)
    fontType*: string        ## "Core"
    name*: string            ## PDF base font name
    up*: int                 ## underline position
    ut*: int                 ## underline thickness
    cw*: array[256, int]     ## character widths (cp1252 indexed, in 1/1000 of text space)
    n*: int                  ## PDF object number (assigned during serialization)

  ImageInfo* = object
    i*: int                  ## image index (1-based, for /I1, /I2...)
    w*, h*: int              ## pixel dimensions
    cs*: string              ## color space: DeviceRGB, DeviceGray, DeviceCMYK
    bpc*: int                ## bits per component
    f*: string               ## filter: DCTDecode or FlateDecode
    data*: string            ## raw image data
    smask*: string           ## alpha channel data (PNG)
    dp*: string              ## DecodeParms
    pal*: string             ## palette data (indexed PNG)
    trns*: seq[int]          ## transparency info
    n*: int                  ## PDF object number

  PageInfo* = object
    n*: int                  ## PDF object number
    size*: PageSize
    orientation*: Orientation
    rotation*: int           ## 0, 90, 180, 270

  InternalLink* = object
    page*: int
    y*: float64

  LinkTarget* = object
    case isInternal*: bool
    of true:
      linkIdx*: int
    of false:
      url*: string

  PageLink* = object
    x*, y*, w*, h*: float64
    link*: LinkTarget

  FpdfError* = object of CatchableError

  Fpdf* = ref object
    # State machine
    state*: DocumentState
    page*: int               ## current page number (1-based)
    n*: int                  ## current PDF object number
    offsets*: seq[int]       ## byte offset of each object in buffer
    buffer*: string          ## global PDF output buffer
    pages*: seq[string]      ## per-page content streams (0-indexed: pages[0] = page 1)
    pageInfos*: seq[PageInfo]

    # Scale & dimensions
    k*: float64              ## scale factor: user units -> points
    defOrientation*: Orientation
    curOrientation*: Orientation
    defPageSize*: PageSize
    curPageSize*: PageSize
    curRotation*: int
    w*, h*: float64          ## page dims in user units
    wPt*, hPt*: float64      ## page dims in points

    # Margins & position
    lMargin*, rMargin*, tMargin*, bMargin*: float64
    cMargin*: float64        ## cell margin
    x*, y*: float64          ## current position in user units
    lastH*: float64          ## height of last cell

    # Fonts
    fontFamily*: string
    fontStyle*: FontStyle
    fontSizePt*: float64
    fontSize*: float64       ## in user units
    currentFont*: FontInfo
    fontSet*: bool
    fonts*: OrderedTable[string, FontInfo]

    # Colors
    drawColor*: string       ## PDF operator string
    fillColor*: string
    textColor*: string
    colorFlag*: bool         ## true if textColor != fillColor
    withAlpha*: bool

    # Graphics
    lineWidth*: float64

    # Images
    images*: OrderedTable[string, ImageInfo]

    # Links
    links*: seq[InternalLink]
    pageLinks*: seq[seq[PageLink]]

    # Page breaks
    autoPageBreak*: bool
    pageBreakTrigger*: float64
    inHeader*: bool
    inFooter*: bool

    # Header/Footer callbacks
    headerProc*: proc(doc: Fpdf) {.closure.}
    footerProc*: proc(doc: Fpdf) {.closure.}
    acceptPageBreakProc*: proc(doc: Fpdf): bool {.closure.}

    # Metadata & display
    aliasNbPagesStr*: string
    zoomMode*: ZoomMode
    zoomFactor*: float64
    layoutMode*: LayoutMode
    metadata*: Table[string, string]

    # Compression
    compress*: bool

    # Word spacing (justified text)
    ws*: float64

    # PDF version
    pdfVersion*: string

const
  PageA3* = PageSize(wPt: 841.89, hPt: 1190.55)
  PageA4* = PageSize(wPt: 595.28, hPt: 841.89)
  PageA5* = PageSize(wPt: 420.94, hPt: 595.28)
  PageLetter* = PageSize(wPt: 612.0, hPt: 792.0)
  PageLegal* = PageSize(wPt: 612.0, hPt: 1008.0)

proc noLink*(): LinkTarget =
  LinkTarget(isInternal: false, url: "")

proc extLink*(url: string): LinkTarget =
  LinkTarget(isInternal: false, url: url)

proc intLink*(idx: int): LinkTarget =
  LinkTarget(isInternal: true, linkIdx: idx)
