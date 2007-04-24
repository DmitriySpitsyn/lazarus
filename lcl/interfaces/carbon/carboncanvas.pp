{ $Id$
                  -----------------------------------------
                  carboncanvas.pp  -  Carbon device context
                  -----------------------------------------

 *****************************************************************************
 *                                                                           *
 *  This file is part of the Lazarus Component Library (LCL)                 *
 *                                                                           *
 *  See the file COPYING.modifiedLGPL, included in this distribution,        *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************
}
unit CarbonCanvas;

{$mode objfpc}{$H+}

interface

// debugging defines
{$I carbondebug.inc}

uses
 // rtl+ftl
  Types, Classes, SysUtils, Math, Contnrs,
 // carbon bindings
  FPCMacOSAll,
 // LCL
  LCLProc, LCLType, Graphics, Controls, Forms,
 // LCL Carbon
  CarbonDef, CarbonGDIObjects;

type
  // device context data for SaveDC/RestoreDC
  TCarbonDCData = class
    CurrentFont: TCarbonFont;
    CurrentBrush: TCarbonBrush;
    CurrentPen: TCarbonPen;

    BkColor: TColor;
    BkMode: Integer;
    BkBrush: TCarbonBrush;

    TextColor: TColor;
    TextBrush: TCarbonBrush;

    ROP2: Integer;
    PenPos: TPoint;
  end;
  
  TCarbonBitmapContext = class;

  { TCarbonDeviceContext }

  TCarbonDeviceContext = class(TCarbonContext)
  private
    FCurrentFont: TCarbonFont;
    FCurrentBrush: TCarbonBrush;
    FCurrentPen: TCarbonPen;

    FBkColor: TColor;
    FBkMode: Integer;
    FBkBrush: TCarbonBrush;

    FTextColor: TColor;
    FTextBrush: TCarbonBrush; // text color is fill color

    FROP2: Integer;
    FPenPos: TPoint;
    
    FSavedDCList: TFPObjectList;

    procedure SetBkColor(const AValue: TColor);
    procedure SetBkMode(const AValue: Integer);
    procedure SetCurrentBrush(const AValue: TCarbonBrush);
    procedure SetCurrentFont(const AValue: TCarbonFont);
    procedure SetCurrentPen(const AValue: TCarbonPen);
    procedure SetROP2(const AValue: Integer);
    procedure SetTextColor(const AValue: TColor);
  protected
    function GetSize: TPoint; virtual; abstract;
    function SaveDCData: TCarbonDCData; virtual;
    procedure RestoreDCData(const AData: TCarbonDCData); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset; override;
    
    function SaveDC: Integer;
    function RestoreDC(ASavedDC: Integer): Boolean;
    
    function BeginTextRender(AStr: PChar; ACount: Integer; out ALayout: ATSUTextLayout): Boolean;
    procedure EndTextRender(var ALayout: ATSUTextLayout);
    
    procedure SetAntialiasing(AValue: Boolean);
  public
    procedure Ellipse(X1, Y1, X2, Y2: Integer);
    procedure ExcludeClipRect(Left, Top, Right, Bottom: Integer);
    function ExtTextOut(X, Y: Integer; Options: Longint; Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
    procedure FillRect(Rect: TRect; Brush: TCarbonBrush);
    procedure Frame3D(var ARect: TRect; const FrameWidth: integer; const Style: TBevelCut);
    function GetTextExtentPoint(Str: PChar; Count: Integer; var Size: TSize): Boolean;
    function GetTextMetrics(var TM: TTextMetric): Boolean;
    procedure LineTo(X, Y: Integer);
    procedure PolyBezier(Points: PPoint; NumPts: Integer; Filled, Continuous: boolean);
    procedure Polygon(Points: PPoint; NumPts: Integer; Winding: boolean);
    procedure Polyline(Points: PPoint; NumPts: Integer);
    procedure Rectangle(X1, Y1, X2, Y2: Integer);
    function StretchDraw(X, Y, Width, Height: Integer; SrcDC: TCarbonBitmapContext;
      XSrc, YSrc, SrcWidth, SrcHeight: Integer; Rop: DWORD): Boolean;
  public
    property Size: TPoint read GetSize;

    property CurrentFont: TCarbonFont read FCurrentFont write SetCurrentFont;
    property CurrentBrush: TCarbonBrush read FCurrentBrush write SetCurrentBrush;
    property CurrentPen: TCarbonPen read FCurrentPen write SetCurrentPen;

    property BkColor: TColor read FBkColor write SetBkColor;
    property BkMode: Integer read FBkMode write SetBkMode;
    property BkBrush: TCarbonBrush read FBkBrush;

    property TextColor: TColor read FTextColor write SetTextColor;
    property TextBrush: TCarbonBrush read FTextBrush;

    property ROP2: Integer read FROP2 write SetROP2;
    property PenPos: TPoint read FPenPos write FPenPos;
  end;

  { TCarbonScreenContext }

  TCarbonScreenContext = class(TCarbonDeviceContext)
  protected
    function GetSize: TPoint; override;
  public
    constructor Create; // TODO
  end;

  { TCarbonControlContext }

  TCarbonControlContext = class(TCarbonDeviceContext)
  private
    FOwner: TCarbonWidget;    // owner widget
  protected
    function GetSize: TPoint; override;
  public
    constructor Create(AOwner: TCarbonWidget);
  end;

  { TCarbonBitmapContext }

  TCarbonBitmapContext = class(TCarbonDeviceContext)
  private
    FBitmap: TCarbonBitmap;
  protected
    function GetSize: TPoint; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset; override;
  public
    function GetBitmap: TCarbonBitmap;
    procedure SetBitmap(const AValue: TCarbonBitmap);
  end;
  
  // TODO: TCarbonPrinterContext
  
function CheckDC(const DC: HDC; const AMethodName: String; AParamName: String = ''): Boolean;

var
  // context for calculating text parameters for invisible controls
  DefaultContext: TCarbonBitmapContext;
  ScreenContext: TCarbonScreenContext;

implementation

uses LCLIntf, CarbonProc, CarbonDbgConsts;

{------------------------------------------------------------------------------
  Name:    CheckDC
  Params:  DC          - Handle to a device context (TCarbonDeviceContext)
           AMethodName - Method name
           AParamName  - Param name
  Returns: If the DC is valid
 ------------------------------------------------------------------------------}
function CheckDC(const DC: HDC; const AMethodName: String;
  AParamName: String): Boolean;
begin
  if TObject(DC) is TCarbonDeviceContext then Result := True
  else
  begin
    Result := False;
    
    if Pos('.', AMethodName) = 0 then
      DebugLn(SCarbonWSPrefix + AMethodName + ' Error - invalid DC ' +
        AParamName + ' = ' + DbgS(DC) + '!')
    else
      DebugLn(AMethodName + ' Error - invalid DC ' + AParamName + ' = ' +
        DbgS(DC) + '!');
  end;
end;

{ TCarbonDeviceContext }

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetBkColor
  Params:  AValue - New background color

  Sets the background color
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetBkColor(const AValue: TColor);
begin
  if FBkColor <> AValue then
  begin
    FBkColor := AValue;
    FBkBrush.SetColor(ColorToRGB(AValue), BkMode = OPAQUE);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetBkMode
  Params:  AValue - New background mode (OPAQUE, TRANSPARENT)

  Sets the background mode
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetBkMode(const AValue: Integer);
begin
  if FBkMode <> AValue then
  begin
    FBkMode := AValue;
    FBkBrush.SetColor(ColorToRGB(BkColor), FBkMode = OPAQUE);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetCurrentBrush
  Params:  AValue - New brush

  Sets the current brush
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetCurrentBrush(const AValue: TCarbonBrush);
begin
  if AValue = nil then
  begin
    DebugLn('TCarbonDeviceContext.SetCurrentBrush Error - Value is nil!');
    Exit;
  end;
  
  if FCurrentBrush <> AValue then
  begin
    FCurrentBrush := AValue;
    FCurrentBrush.Apply(Self);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetCurrentFont
  Params:  AValue - New font

  Sets the current font
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetCurrentFont(const AValue: TCarbonFont);
begin
  if AValue = nil then
  begin
    DebugLn('TCarbonDeviceContext.SetCurrentFont Error - Value is nil!');
    Exit;
  end;
  
  if FCurrentFont <> AValue then
  begin
    FCurrentFont := AValue;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetCurrentPen
  Params:  AValue - New pen

  Sets the current pen
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetCurrentPen(const AValue: TCarbonPen);
begin
  if AValue = nil then
  begin
    DebugLn('TCarbonDeviceContext.SetCurrentPen Error - Value is nil!');
    Exit;
  end;
  
  if FCurrentPen <> AValue then
  begin
    FCurrentPen := AValue;
    FCurrentPen.Apply(Self);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetROP2
  Params:  AValue - New binary raster operation

  Sets the binary raster operation
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetROP2(const AValue: Integer);
begin
  if FROP2 <> AValue then
  begin
    FROP2 := AValue;
    CurrentPen.Apply(Self);
    CurrentBrush.Apply(Self);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetTextColor
  Params:  AValue - New text color

  Sets the text color
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetTextColor(const AValue: TColor);
begin
  if FTextColor <> AValue then
  begin
    FTextColor := AValue;
    TextBrush.SetColor(ColorToRGB(AValue), True);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Create

  Creates new Carbon device context
 ------------------------------------------------------------------------------}
constructor TCarbonDeviceContext.Create;
begin
  FBkBrush := TCarbonBrush.Create;
  FTextBrush := TCarbonBrush.Create;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Destroy

  Frees Carbon device context
 ------------------------------------------------------------------------------}
destructor TCarbonDeviceContext.Destroy;
begin
  BkBrush.Free;
  TextBrush.Free;
  
  FSavedDCList.Free;

  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Reset

  Resets the device context properties to defaults (pen, brush, ...)
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.Reset;
begin
  PenPos.x := 0;
  PenPos.y := 0;

  // create brush for bk color and mode
  FBkColor := clWhite;
  FBkMode := TRANSPARENT;
  FBkBrush.SetColor(clWhite, False);

  // create brush for text color
  FTextColor := clBlack;
  FTextBrush.SetColor(clBlack, True);

  // set raster operation to copy
  FROP2 := R2_COPYPEN;

  // set initial pen, brush and font
  FCurrentPen := BlackPen;
  FCurrentBrush := WhiteBrush;
  FCurrentFont := StockSystemFont;

  if CGContext <> nil then
  begin
    {$IFDEF VerboseCanvas}
      DebugLn('TCarbonDeviceContext.Reset set defaults');
    {$ENDIF}
    
    // enable anti-aliasing
    CGContextSetShouldAntialias(CGContext, 1);
    CGContextSetBlendMode(CGContext, kCGBlendModeNormal);
    
    CGContextSetRGBFillColor(CGContext, 1, 1, 1, 1);
    CGContextSetRGBStrokeColor(CGContext, 0, 0, 0, 1);
    CGContextSetLineWidth(CGContext, 1);
    CGContextSetLineDash(CGContext, 0, nil, 0);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SaveDC
  Returns: Index of saved device context state
  
  Note: must be used in pair with RestoreDC!
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.SaveDC: Integer;
begin
  Result := 0;
  if CGContext = nil then
  begin
    DebugLn('TCarbonDeviceContext.SaveDC CGContext is nil!');
    Exit;
  end;
  
  if FSavedDCList = nil then FSavedDCList := TFPObjectList.Create(True);
  
  CGContextSaveGState(CGContext);
  Result := FSavedDCList.Add(SaveDCData) + 1;
  
  {$IFDEF VerboseCanvas}
    DebugLn('TCarbonDeviceContext.SaveDC Result: ', DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.RestoreDC
  Params:  ASavedDC - Index of saved device context
  Returns: If the function succeeds
  
  Restores the previously saved state of device context
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.RestoreDC(ASavedDC: Integer): Boolean;
begin
  Result := False;
  if (FSavedDCList = nil) or (ASavedDC <= 0) or (ASavedDC > FSavedDCList.Count) then
  begin
    DebugLn(Format('TCarbonDeviceContext.RestoreDC SavedDC %d is not valid!', [ASavedDC]));
    Exit;
  end;
  
  if FSavedDCList.Count > ASavedDC then
    DebugLn(Format('TCarbonDeviceContext.RestoreDC Warning: SaveDC - RestoreDC' +
      ' not used in pair, skipped %d saved states!', [FSavedDCList.Count - ASavedDC]));
    
  while FSavedDCList.Count > ASavedDC do
  begin
    CGContextRestoreGState(CGContext);
    FSavedDCList.Delete(FSavedDCList.Count - 1);
  end;
  
  {$IFDEF VerboseCanvas}
    DebugLn('TCarbonDeviceContext.RestoreDC SavedDC: ', DbgS(ASavedDC));
  {$ENDIF}
  
  CGContextRestoreGState(CGContext);
  RestoreDCData(TCarbonDCData(FSavedDCList[ASavedDC - 1]));
  FSavedDCList.Delete(ASavedDC - 1);
  Result := True;
  
  {$IFDEF VerboseCanvas}
    DebugLn('TCarbonDeviceContext.RestoreDC End');
  {$ENDIF}
  
  if FSavedDCList.Count = 0 then FreeAndNil(FSavedDCList);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SaveDCData
  Returns: The device context data
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.SaveDCData: TCarbonDCData;
begin
  Result := TCarbonDCData.Create;
  
  Result.CurrentFont := FCurrentFont;
  Result.CurrentBrush := FCurrentBrush;
  Result.CurrentPen := FCurrentPen;

  Result.BkColor := FBkColor;
  Result.BkMode := FBkMode;
  Result.BkBrush := FBkBrush;

  Result.TextColor := FTextColor;
  Result.TextBrush := FTextBrush;

  Result.ROP2 := FROP2;
  Result.PenPos := FPenPos;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.RestoreDCData
  Params:  AData - Device context data
  
  Restores device context data
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.RestoreDCData(const AData: TCarbonDCData);
begin
  FCurrentFont := AData.CurrentFont;
  FCurrentBrush := AData.CurrentBrush;
  FCurrentPen := AData.CurrentPen;

  FBkColor := AData.BkColor;
  FBkMode := AData.BkMode;
  FBkBrush := AData.BkBrush;

  FTextColor := AData.TextColor;
  FTextBrush := AData.TextBrush;

  FROP2 := AData.ROP2;
  FPenPos := AData.PenPos;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.BeginTextRender
  Params:  AStr    - UTF8 string to render
           ACount  - Count of chars to render
           ALayout - ATSU layout
  Returns: If the function suceeds

  Creates the ATSU text layout for the specified text and manages the device
  context to render the text.
  NOTE: Coordination system is set upside-down!
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.BeginTextRender(AStr: PChar; ACount: Integer; out
  ALayout: ATSUTextLayout): Boolean;
var
  TextStyle: ATSUStyle;
  TextLength: LongWord;
  S: String;
  W: WideString;
  Tag: ATSUAttributeTag;
  DataSize: ByteCount;
  PContext: ATSUAttributeValuePtr;
const
  SName = 'BeginTextRender';
begin
  Result := False;

  // save context
  CGContextSaveGState(CGContext);

  // change coordination system
  CGContextScaleCTM(CGContext, 1, -1);
  CGContextTranslateCTM(CGContext, 0, 0);

  // convert UTF-8 string to UTF-16 string
  if ACount < 0 then S := AStr
  else S := Copy(AStr, 1, ACount);
  W := UTF8ToUTF16(S);

  TextStyle := CurrentFont.Style;

  // create text layout
  TextLength := kATSUToTextEnd;
  if OSError(ATSUCreateTextLayoutWithTextPtr(ConstUniCharArrayPtr(@W[1]),
      kATSUFromTextBeginning, kATSUToTextEnd, Length(W), 1, @TextLength,
      @TextStyle, ALayout), Self, SName, 'ATSUCreateTextLayoutWithTextPtr') then Exit;
      
  // set layout context
  Tag := kATSUCGContextTag;
  DataSize := SizeOf(CGContextRef);

  PContext := @CGContext;
  if OSError(ATSUSetLayoutControls(ALayout, 1, @Tag, @DataSize, @PContext),
    Self, SName, 'ATSUSetLayoutControls') then Exit;
    
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.EndTextRender
  Params:  ALayout - ATSU layout

  Frees the ATSU text layout and manages the device
  context to render ordinary graphic
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.EndTextRender(var ALayout: ATSUTextLayout);
begin
  // restore context
  CGContextRestoreGState(CGContext);

  if ALayout <> nil then
    OSError(ATSUDisposeTextLayout(ALayout), Self, 'EndTextRender', 'ATSUDisposeTextLayout');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.SetAntialiasing
  Params:  AValue - If should antialias

  Sets whether device context should antialias
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.SetAntialiasing(AValue: Boolean);
begin
  CGContextSetShouldAntialias(CGContext, CBool(AValue));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Ellipse
  Params:
           X1 - X-coord. of bounding rectangle's upper-left corner
           Y1 - Y-coord. of bounding rectangle's upper-left corner
           X2 - X-coord. of bounding rectangle's lower-right corner
           Y2 - Y-coord. of bounding rectangle's lower-right corner

  Draws a ellipse. The ellipse is outlined by using the current pen and filled
  by using the current brush.
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.Ellipse(X1, Y1, X2, Y2: Integer);
var
  R: CGRect;
begin
  if (X1 = X2) or (Y1 = Y2) then Exit;

  R := GetCGRectSorted(X1, Y1, X2, Y2);
  R.origin.x := R.origin.x + 0.5;
  R.origin.y := R.origin.y + 0.5;
  R.size.width := R.size.width - 1;
  R.size.height := R.size.height - 1;

  CGContextBeginPath(CGContext);
  CGContextAddEllipseInRect(CGContext, R);
  CGContextDrawPath(CGContext, kCGPathFillStroke);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.ExcludeClipRect
  Params:  Left, Top, Right, Bottom - Rectangle coordinates

  Subtracts all intersecting points of the passed bounding rectangle from the
  current clipping region of the device context.
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.ExcludeClipRect(Left, Top, Right, Bottom: Integer);
var
  ClipBox: TRect;
  Rects: CGRectArray;
begin
  if (Left < Right) and (Top < Bottom) then
  begin
    // get clip bounding box, exclude passed rect and intersect result
    // with clip region
    ClipBox := CGRectToRect(CGContextGetClipBoundingBox(CGContext));

    Rects := ExcludeRect(ClipBox, Classes.Rect(Left, Top, Right, Bottom));

    if Length(Rects) > 0 then
      CGContextClipToRects(CGContext, @Rects[0], Length(Rects))
    else
      CGContextClipToRect(CGContext, CGRectZero);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.ExtTextOut
  Params:  X       - X-coordinate of reference point
           Y       - Y-coordinate of reference point
           Options - Text-output options
           Rect    - Optional clipping and/or opaquing rectangle (TODO)
           Str     - Character string to be drawn
           Count   - Number of characters in string
           Dx      - Pointer to array of intercharacter spacing values (IGNORED)
  Returns: If the string was drawn

  Draws a character string by using the currently selected font
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.ExtTextOut(X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
var
  TextLayout: ATSUTextLayout;
  TextBefore, TextAfter, Ascent, Descent: ATSUTextMeasurement;
const
  SName = 'ExtTextOut';
begin
  Result := False;
  
  if not BeginTextRender(Str, Count, TextLayout) then Exit;
  try
    // get text ascent
    if OSError(
      ATSUGetUnjustifiedBounds(TextLayout, kATSUFromTextBeginning, kATSUToTextEnd,
        TextBefore, TextAfter, Ascent, Descent),
      Self, SName, SGetUnjustifiedBounds) then Exit;

    // fill drawed text background
    if (Options and ETO_OPAQUE) > 0 then
    begin
      BkBrush.Apply(Self, False); // do not use ROP2
      CGContextFillRect(CGContext, GetCGRectSorted(X - TextBefore shr 16,
        -Y, X + TextAfter shr 16, -Y - (Ascent + Descent) shr 16));
    end;

    // apply text color
    TextBrush.Apply(Self, False); // do not use ROP2


    // finally draw the text
    if OSError(ATSUDrawText(TextLayout, kATSUFromTextBeginning, kATSUToTextEnd,
        X shl 16 - TextBefore, -(Y shl 16) - Ascent),
       Self, SName, 'ATSUDrawText') then Exit;

    Result := True;
  finally
    EndTextRender(TextLayout);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.FillRect
  Params:  Rect  - Record with rectangle coordinates
           Brush - Carbon brush

  Fills the rectangle by using the specified brush
  It includes the left and top borders, but excludes the right and
  bottom borders of the rectangle!
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.FillRect(Rect: TRect; Brush: TCarbonBrush);
var
  SavedBrush: TCarbonBrush;
begin
  SavedBrush := FCurrentBrush;
  Brush.Apply(Self, False); // do not use ROP2
  try
    CGContextFillRect(CGContext, RectToCGRect(Rect));
  finally
    FCurrentBrush := SavedBrush;
    CurrentBrush.Apply(Self); // ensure that saved brush is applied
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Frame3D
  Params:  ARect      - Bounding box of frame
           FrameWidth - Frame width
           Style      - Frame style

  Draws a 3D border in Carbon native style
  TODO: lowered style
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.Frame3D(var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut);
var
  I, D: Integer;
  DrawInfo: HIThemeGroupBoxDrawInfo;
const
  SName = 'Frame3D';
begin
  if Style = bvRaised then
  begin
    if OSError(GetThemeMetric(kThemeMetricPrimaryGroupBoxContentInset, D),
      Self, SName, SGetThemeMetric) then D := 1;

    // draw frame as group box
    DrawInfo.version := 0;
    DrawInfo.state := kThemeStateActive;
    DrawInfo.kind := kHIThemeGroupBoxKindPrimary;

    for I := 1 to FrameWidth do
    begin
      OSError(
        HIThemeDrawGroupBox(RectToCGRect(ARect), DrawInfo, CGContext,
          kHIThemeOrientationNormal),
        Self, SName, 'HIThemeDrawGroupBox');

      InflateRect(ARect, -D, -D);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.GetTextExtentPoint
  Params:  Str   - Text string
           Count - Number of characters in string
           Size  - The record for the dimensions of the string
  Returns: If the function succeeds

  Computes the width and height of the specified string of text
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.GetTextExtentPoint(Str: PChar; Count: Integer;
  var Size: TSize): Boolean;
var
  TextLayout: ATSUTextLayout;
  TextBefore, TextAfter, Ascent, Descent: ATSUTextMeasurement;
const
  SName = 'GetTextExtentPoint';
begin
  Result := False;
  
  if not BeginTextRender(Str, Count, TextLayout) then Exit;
  try
    // finally compute the text dimensions
    if OSError(ATSUGetUnjustifiedBounds(TextLayout, kATSUFromTextBeginning,
        kATSUToTextEnd, TextBefore, TextAfter, Ascent, Descent),
      Self, SName, SGetUnjustifiedBounds) then Exit;

    Size.cx := (TextAfter - TextBefore) shr 16;
    Size.cy := (Descent + Ascent) shr 16;

    Result := True;
  finally
    EndTextRender(TextLayout);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.GetTextMetrics
  Params:  TM - The Record for the text metrics
  Returns: If the function succeeds

  Fills the specified buffer with the metrics for the currently selected font
  TODO: get exact max. and av. char width, pitch and charset
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.GetTextMetrics(var TM: TTextMetric): Boolean;
var
  TextStyle: ATSUStyle;
  M: ATSUTextMeasurement;
  B: Boolean;
  TextLayout: ATSUTextLayout;
  TextBefore, TextAfter, Ascent, Descent: ATSUTextMeasurement;
const
  SName = 'GetTextMetrics';
  SGetAttrName = 'ATSUGetAttribute';
begin
  Result := False;
  
  TextStyle := CurrentFont.Style;

  FillChar(TM, SizeOf(TM), 0);

  // According to the MSDN library, TEXTMETRIC:
  // the average char width is generally defined as the width of the letter x
  if not BeginTextRender('x', 1, TextLayout) then Exit;
  try
    if OSError(ATSUGetUnjustifiedBounds(TextLayout, kATSUFromTextBeginning,
          kATSUToTextEnd, TextBefore, TextAfter, Ascent, Descent),
        SName, SGetUnjustifiedBounds) then Exit
  finally
    EndTextRender(TextLayout);
  end;

  TM.tmAscent := Ascent shr 16;
  TM.tmDescent := Descent shr 16;
  TM.tmHeight := (Ascent + Descent) shr 16;

  if OSError(ATSUGetAttribute(TextStyle, kATSULeadingTag, SizeOf(M), @M, nil),
    Self, SName, SGetAttrName, 'kATSULeadingTag', kATSUNotSetErr) then Exit;
  TM.tmInternalLeading := M shr 16;
  TM.tmExternalLeading := 0;

  TM.tmAveCharWidth := (TextAfter - TextBefore) shr 16;

  TM.tmMaxCharWidth := TM.tmAscent; // TODO: don't know how to determine this right
  TM.tmOverhang := 0;
  TM.tmDigitizedAspectX := 0;
  TM.tmDigitizedAspectY := 0;
  TM.tmFirstChar := 'a';
  TM.tmLastChar := 'z';
  TM.tmDefaultChar := 'x';
  TM.tmBreakChar := '?';

  if OSError(ATSUGetAttribute(TextStyle, kATSUQDBoldfaceTag, SizeOf(B), @B, nil),
    Self, SName, SGetAttrName, 'kATSUQDBoldfaceTag', kATSUNotSetErr) then Exit;
  if B then TM.tmWeight := FW_NORMAL
       else TM.tmWeight := FW_BOLD;

  if OSError(ATSUGetAttribute(TextStyle, kATSUQDItalicTag, SizeOf(B), @B, nil),
    Self, SName, SGetAttrName, 'kATSUQDItalicTag', kATSUNotSetErr) then Exit;
  TM.tmItalic := Byte(B);

  if OSError(ATSUGetAttribute(TextStyle, kATSUQDUnderlineTag, SizeOf(B), @B, nil),
    Self, SName, SGetAttrName, 'kATSUQDUnderlineTag', kATSUNotSetErr) then Exit;
  TM.tmUnderlined := Byte(B);

  if OSError(ATSUGetAttribute(TextStyle, kATSUStyleStrikeThroughTag, SizeOf(B), @B, nil),
    Self, SName, SGetAttrName, 'kATSUStyleStrikeThroughTag', kATSUNotSetErr) then Exit;
  TM.tmStruckOut := Byte(B);

  // TODO: get these from font
  TM.tmPitchAndFamily := FIXED_PITCH or TRUETYPE_FONTTYPE;
  TM.tmCharSet := DEFAULT_CHARSET;

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.LineTo
  Params:  X  - X-coordinate of line's ending point
           Y  - Y-coordinate of line's ending point

  Draws a line from the current position up to the specified point and updates
  the current position
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.LineTo(X, Y: Integer);
begin
  CGContextBeginPath(CGContext);
  // add 0.5 to both coordinates for better rasterization
  CGContextMoveToPoint(CGContext, PenPos.x + 0.5, PenPos.y + 0.5);
  CGContextAddLineToPoint(CGContext, X + 0.5, Y + 0.5);
  CGContextStrokePath(CGContext);
  
  PenPos.x := X;
  PenPos.y := Y;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.PolyBezier
  Params:  Points    - Points defining the cubic B�zier curve
           NumPts    - Number of points passed
           Filled    - Fill the drawed shape
           Continous - Connect B�zier curves

  Draws a cubic B�zier curves. The first curve is drawn from the first point to
  the fourth point with the second and third points being the control points.
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.PolyBezier(Points: PPoint; NumPts: Integer;
  Filled, Continuous: boolean);
var
  C1, C2: TPoint;
begin
  if Points = nil then Exit;
  if NumPts < 4 then Exit;
  
  CGContextBeginPath(CGContext);

  if Continuous then
  begin
    CGContextMoveToPoint(CGContext, Points^.x + 0.5, Points^.y + 0.5);
    Dec(NumPts);

    while NumPts >= 3 do
    begin
      Inc(Points);
      C1 := Points^;
      Inc(Points);
      C2 := Points^;
      Inc(Points);

      CGContextAddCurveToPoint(CGContext, C1.x + 0.5, C1.y + 0.5, C2.x + 0.5, C2.y + 0.5,
        Points^.x + 0.5, Points^.y + 0.5);

      Dec(NumPts, 3);
    end;
  end
  else
  begin
    while NumPts >= 4 do
    begin
      CGContextMoveToPoint(CGContext, Points^.x + 0.5, Points^.y + 0.5);

      Inc(Points);
      C1 := Points^;
      Inc(Points);
      C2 := Points^;
      Inc(Points);
      
      CGContextAddCurveToPoint(CGContext, C1.x + 0.5, C1.y + 0.5, C2.x + 0.5, C2.y + 0.5,
        Points^.x + 0.5, Points^.y + 0.5);

      Inc(Points);
      Dec(NumPts, 4);
    end;
  end;

  if Filled and Continuous then
    CGContextDrawPath(CGContext, kCGPathFillStroke)
  else
    CGContextDrawPath(CGContext, kCGPathStroke);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Polygon
  Params:  Points  - Pointer to polygon's vertices
           NumPts  - Number of polygon's vertices
           Winding - Use winding fill rule

  Draws a closed, many-sided shape on the canvas, using the pen and brush.
  If Winding is set, Polygon fills the shape using the Winding fill algorithm.
  Otherwise, Polygon uses the even-odd (alternative) fill algorithm. The first
  point is always connected to the last point.
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.Polygon(Points: PPoint; NumPts: Integer;
  Winding: boolean);
begin
  if Points = nil then Exit;
  if NumPts < 2 then Exit;
  
  CGContextBeginPath(CGContext);
  CGContextMoveToPoint(CGContext, Points^.x + 0.5, Points^.y + 0.5);
  Dec(NumPts);

  while NumPts > 0 do
  begin
    Inc(Points);
    CGContextAddLineToPoint(CGContext, Points^.x + 0.5, Points^.y + 0.5);
    Dec(NumPts);
  end;

  CGContextClosePath(CGContext);

  if Winding then
    CGContextDrawPath(CGContext, kCGPathFillStroke)
  else
    CGContextDrawPath(CGContext, kCGPathEOFillStroke);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Polyline
  Params:  Points - Pointer to array containing points
           NumPts - Number of points in the array

  Draws a series of line segments by connecting the points in the specified
  array
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.Polyline(Points: PPoint; NumPts: Integer);
begin
  if Points = nil then Exit;
  if NumPts < 1 then Exit;

  CGContextBeginPath(CGContext);
  CGContextMoveToPoint(CGContext, Points^.x + 0.5, Points^.y + 0.5);
  Dec(NumPts);

  while NumPts > 0 do
  begin
    Inc(Points);
    CGContextAddLineToPoint(CGContext, Points^.x + 0.5, Points^.y + 0.5);
    Dec(NumPts);
  end;

  CGContextStrokePath(CGContext);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDeviceContext.Rectangle
  Params:  X1 - X-coordinate of bounding rectangle's upper-left corner
           Y1 - Y-coordinate of bounding rectangle's upper-left corner
           X2 - X-coordinate of bounding rectangle's lower-right corner
           Y2 - Y-coordinate of bounding rectangle's lower-right corner

  Draws a rectangle. The rectangle is outlined by using the current pen and
  filled by using the current brush.
 ------------------------------------------------------------------------------}
procedure TCarbonDeviceContext.Rectangle(X1, Y1, X2, Y2: Integer);
var
  R: CGRect;
begin
  if (X1 = X2) or (Y1 = Y2) then Exit;
  
  R := GetCGRectSorted(X1, Y1, X2, Y2);
  R.origin.x := R.origin.x + 0.5;
  R.origin.y := R.origin.y + 0.5;
  R.size.width := R.size.width - 1;
  R.size.height := R.size.height - 1;

  CGContextBeginPath(CGContext);
  CGContextAddRect(CGContext, R);
  CGContextDrawPath(CGContext, kCGPathFillStroke);
end;

{------------------------------------------------------------------------------
  Method:  StretchMaskBlt
  Params:  X, Y                - Left/top corner of the destination rectangle
           Width, Height       - Size of the destination rectangle
           SrcDC               - Carbon device context
           XSrc, YSrc          - Left/top corner of the source rectangle
           SrcWidth, SrcHeight - Size of the source rectangle
           Rop                 - Raster operation to be performed (TODO)
  Returns: If the function succeeds

  Copies a bitmap from a source rectangle into a destination rectangle using
  the specified raster operations. If needed it resizes the bitmap to
  fit the dimensions of the destination rectangle. Sizing is done according to
  the stretching mode currently set in the destination device context.
  TODO: copy from any canvas
        ROP
        stretch mode
 ------------------------------------------------------------------------------}
function TCarbonDeviceContext.StretchDraw(X, Y, Width, Height: Integer;
  SrcDC: TCarbonBitmapContext; XSrc, YSrc, SrcWidth, SrcHeight: Integer;
  Rop: DWORD): Boolean;
var
  Image: CGImageRef;
  FreeImage: Boolean;
  Bitmap: TCarbonBitmap;
begin
  Result := False;
  
  // save dest context
  CGContextSaveGState(CGContext);

  CGContextSetBlendMode(CGContext, kCGBlendModeNormal);
  try
    Image := nil;
    Bitmap := SrcDC.GetBitmap;
    if Bitmap <> nil then Image := Bitmap.CGImage;

    if Image = nil then Exit;
    
    if (XSrc <> 0) or (YSrc <> 0) or (SrcWidth <> Bitmap.Width) or
      (SrcHeight <> Bitmap.Height) then
    begin
      Image := Bitmap.GetSubImage(Bounds(XSrc, YSrc, SrcWidth, SrcHeight));
      FreeImage := True;
    end
    else
      FreeImage := False;
    
    try
      if OSError(
        HIViewDrawCGImage(CGContext,
          GetCGRectSorted(X, Y, X + Width, Y + Height), Image),
        'StretchMaskBlt', 'HIViewDrawCGImage') then Exit;
    finally
      if FreeImage then CGImageRelease(Image);
    end;
    
    Result := True;
    //DebugLn('StretchMaskBlt succeeds: ', Format('Dest %d Src %d X %d Y %d',
    //  [Integer(CGContext),
    //  Integer(Image),
    //  X, Y]));
  finally
    CGContextRestoreGState(CGContext);
  end;
end;

{ TCarbonScreenContext }

{------------------------------------------------------------------------------
  Method:  TCarbonScreenContext.GetSize
  Returns: Size of screen context
 ------------------------------------------------------------------------------}
function TCarbonScreenContext.GetSize: TPoint;
begin
  Result.X := CGDisplayPixelsWide(CGMainDisplayID);
  Result.Y := CGDisplayPixelsHigh(CGMainDisplayID);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonScreenContext.Create

  Creates new screen context
 ------------------------------------------------------------------------------}
constructor TCarbonScreenContext.Create;
begin
  inherited Create;

  Reset;
end;

{ TCarbonControlContext }

{------------------------------------------------------------------------------
  Method:  TCarbonControlContext.GetSize
  Returns: Size of control context
 ------------------------------------------------------------------------------}
function TCarbonControlContext.GetSize: TPoint;
begin
  Result.X := (FOwner.LCLObject as TControl).ClientWidth;
  Result.Y := (FOwner.LCLObject as TControl).ClientHeight;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlContext.Create
  Params:  AOwner - Context widget

  Creates new control context
 ------------------------------------------------------------------------------}
constructor TCarbonControlContext.Create(AOwner: TCarbonWidget);
begin
  inherited Create;

  FOwner := AOwner;
  Reset;
end;

{ TCarbonBitmapContext }

{------------------------------------------------------------------------------
  Method:  TCarbonBitmapContext.SetBitmap
  Params:  AValue - New bitmap

  Sets the bitmap
 ------------------------------------------------------------------------------}
procedure TCarbonBitmapContext.SetBitmap(const AValue: TCarbonBitmap);
begin
  if AValue = nil then
  begin
    DebugLn('TCarbonBitmapContext.SetBitmap Error - Value is nil!');
    Exit;
  end;
  
  if FBitmap <> AValue then
  begin
    FBitmap := AValue;
    Reset;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmapContext.GetSize
  Returns: Size of bitmap context
 ------------------------------------------------------------------------------}
function TCarbonBitmapContext.GetSize: TPoint;
begin
  if FBitmap <> nil then
  begin
    Result.X := FBitmap.Width;
    Result.Y := FBitmap.Height;
  end
  else
  begin
    Result.X := 0;
    Result.Y := 0;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmapContext.Create

  Creates new bitmap context
 ------------------------------------------------------------------------------}
constructor TCarbonBitmapContext.Create;
begin
  inherited Create;
  FBitmap := nil;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmapContext.Destroy

  Frees bitmap context
 ------------------------------------------------------------------------------}
destructor TCarbonBitmapContext.Destroy;
begin
  if CGContext <> nil then CGContextRelease(CGContext);

  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmapContext.Reset

  Resets the bitmap context properties to defaults (pen, brush, ...)
 ------------------------------------------------------------------------------}
procedure TCarbonBitmapContext.Reset;
begin
  if CGContext <> nil then CGContextRelease(CGContext);

  if FBitmap = nil then
    CGContext := nil
  else
  begin
    // create CGBitmapContext
    CGContext := CGBitmapContextCreate(FBitmap.Data, FBitmap.Width,
      FBitmap.Height, FBitmap.BitsPerComponent, FBitmap.BytesPerRow, RGBColorSpace,
      kCGImageAlphaNoneSkipLast);

    // flip and offset CTM to upper left corner
    CGContextTranslateCTM(CGContext, 0, FBitmap.Height);
    CGContextScaleCTM(CGContext, 1, -1);
  end;

  inherited Reset;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmapContext.GetBitmap
  Returns: The bitmap of bitmap context
 ------------------------------------------------------------------------------}
function TCarbonBitmapContext.GetBitmap: TCarbonBitmap;
begin
  if FBitmap = nil then Result := nil
  else
  begin
    // update bitmap to reflect changes made via canvas
    FBitmap.Update;
    Result := FBitmap;
  end;
end;

end.
