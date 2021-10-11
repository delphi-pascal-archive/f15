unit Util;

interface

uses
 Windows, Messages;

{$I Common.inc}

const
  TOOLTIPS_CLASS	= 'tooltips_class32';
  TTF_IDISHWND		= $0001;
  TTF_SUBCLASS		= $0010;
  TTS_ALWAYSTIP		= $01;
  TTM_ACTIVATE		= WM_USER + 1;
  TTM_ADDTOOL		= WM_USER + 4;
  TTM_RELAYEVENT	= WM_USER + 7;
  TTM_UPDATETIPTEXT	= WM_USER + 12;

type
  PToolInfoA		= ^TToolInfoA;
  PToolInfo		= PToolInfoA;
  TToolInfoA		= packed record
    cbSize		: UINT;
    uFlags		: UINT;
    hwnd		: HWND;
    uId			: UINT;
    Rect		: TRect;
    hInst		: THandle;
    lpszText		: PAnsiChar;
  end;
  TToolInfo		= TToolInfoA;

  TShadowPosition	= (spNone, spLeftTop, spLeftBottom, spRightBottom, spRightTop);
  TFontStyle		= (fsNone, fsBold, fsItalic, fsUnderline, fsStrikeOut);
  TFontStyles		= set of TFontStyle;
  TTextStyle		= (tsLeft, tsCenter, tsRight, tsSingle, tsBreak);
  TTextStyles		= set of TTextStyle;

  //  TButton
  TButton	= class
  private
    Parent	: Integer;
    fCaption	: String;
    fHandle	: THandle;
    fHeight,
    fLeft, 
    fTop,
    fWidth    	: Integer;
    fRect	: TRect;
    fPressed	: Boolean;
    fVisible	: Boolean;
    tti		: TToolInfo;
    fDC, memDC	: HDC;
    procedure	SetCaption(Value : String);
    procedure	SetVisible(Value : Boolean);
  public
    bmBmp1,
    bmBmp2,
    bmMask1,
    bmMask2	: HBITMAP;
    CanvasSrc	: HDC;
    constructor Create(x, y, w, h : Integer; hParent : THandle; fHint : String);
    destructor  Destroy; override;
    procedure   SetHint(Value : String);
    procedure   Redraw;
  published
    property Handle	: THandle read fHandle;
    property Rect	: TRect	  read fRect;
    property Caption	: String  read fCaption write SetCaption;
    property Visible	: Boolean read fVisible write SetVisible;
  end;

var
  hToolTip	: HWND;
  hHook		: HWND;
  fSound,
  OldSound	: Boolean;
  XPos, YPos	: Integer;
  Step		: Integer = 4;		// Шаг сдвига
  OldStep	: Integer;

{ ====== REGISTRY CONTROL =================== }
  
var
  HK		: HKEY;
  dwType,
  dwKeySize	: DWORD;

const
  ROOT		: UInt = HKEY_LOCAL_MACHINE;
  SubKey	: PChar = 'Software\DSoft\Fifteen';

//=================   REGISTRY CONTROL  =================

function  ReadString(Ident : PChar; Default : String) : String;
function  ReadInteger(Ident : PChar; Default : Integer) : Integer;
procedure WriteString(Ident : PChar; Value : String);
procedure WriteInteger(Ident : PChar; Value : Integer);
function  ReadRegistryInfo : Boolean;
function  WriteRegistryInfo : Boolean;

//====================      Работа с текстом       =====================

procedure DrawShadowTextDC(DC : HDC; S: PChar;
			   Rect: TRect;
			   ShadowSize: Byte;
			   TextColor,
			   ShadowColor: TColorRef;
			   ShadowPos: TShadowPosition;
			   SelFont : Boolean;
			   FntName : String;
			   SizeFont : Integer;
			   FontStyle : TFontStyles;
			   TextStyle : TTextStyles);

// SysUtils

function  StrToInt(S : String) : Integer;
function  IntToStr(I : Integer) : String;
function  Rect(ALeft, ATop, ARight, ABottom: Integer): TRect;
function  Bounds(ALeft, ATop, AWidth, AHeight: Integer): TRect;
function  Power(Base, Exponent: Extended): Extended;
function  FloatToStr(Value: Extended; Width, Decimals: Integer): string;


// Graphics

function  CreateBmp(DC : HDC; W, H : Integer) : HBITMAP;
procedure SplitBitmap(Wnd : HWND; var bmResult : HBitmap; sResName : String; x, y, cx, cy : Integer);
procedure TransparentBmp(DC : HDC; Bitmap : HBitmap; xStart, yStart : Integer);
procedure SemiTransparent(var bmp : HBitmap; aLeft, aTop, Alpha : Integer);
procedure DrawBitmap(Wnd : HWND; X, Y: Integer; bmSrc, bmMask: HBitmap;
		     var bmResult: HBitmap);
function  LoadBmpFromRes(Value : String) : HBITMAP;

implementation

uses
  Unpack, Streams;

var
  WndClass	: TWndClassEx;
  hfntDefault,
  hfntNew	: HFONT;


{ ====== REGISTRY CONTROL =================== }

function ReadString(Ident : PChar; Default : String) : String;
var
  St	: String;
begin
  Result := '';
  if (RegQueryValueEx(HK, Ident, NIL, @dwType, NIL, @dwKeySize) = ERROR_SUCCESS) and
     ((dwType = REG_SZ) or (dwType = REG_EXPAND_SZ)) then
  begin
    SetLength(St, dwKeySize - 1);
    if RegQueryValueEx(HK, Ident, NIL, NIl, @St[1], @dwKeySize) = ERROR_SUCCESS then
      Result := St
    else
      Result := Default;
  end
  else
    Result := Default;
end;

{----------------------------------------------------------}

function ReadInteger(Ident : PChar; Default : Integer) : Integer;
var
  St	: String;

  function StrToIntDef(const S: string; Default: Integer): Integer;
  var
    E: Integer;
  begin
    Val(S, Result, E);
    if E <> 0 then Result := Default;
  end;

begin
  St := ReadString(Ident, '');
  Result := StrToIntDef(St, Default);
end;

{----------------------------------------------------------}

procedure WriteString(Ident : PChar; Value : String);
begin
  RegSetValueEx(HK, Ident, 0, REG_SZ, PChar(Value), Length(Value) + 1);
end;

{----------------------------------------------------------}

procedure WriteInteger(Ident : PChar; Value : Integer);
begin
  RegSetValueEx(HK, Ident, 0, REG_SZ, PChar(IntToStr(Value)), Length(IntToStr(Value)) + 1);
end;

{----------------------------------------------------------}

function ReadRegistryInfo : Boolean;
begin
  Result := False;
  FSound := True;
  Step	 := 4;
  if RegOpenKeyEx(ROOT, SubKey, 0, KEY_READ, HK) = ERROR_SUCCESS then
  try
    XPos	:= ReadInteger('XPos', Xpos);
    YPos	:= ReadInteger('Ypos', YPos);
    FSound	:= Boolean(ReadInteger('Sound', 0));
    Step	:= ReadInteger('Step', Step);
  finally
    RegCloseKey(HK);
  end
  else
  begin
    if RegCreateKeyEx(ROOT, SubKey, 0, NIL,
		      REG_OPTION_NON_VOLATILE,
		      KEY_ALL_ACCESS, NIL, HK, @dwType) = ERROR_SUCCESS then
    RegCloseKey(HK);
    Exit;
  end;
end;

{----------------------------------------------------------}

function WriteRegistryInfo : Boolean;
begin
  Result := False;
  if RegOpenKeyEx(ROOT, SubKey, 0, KEY_WRITE, HK) = ERROR_SUCCESS then
  try
    WriteInteger('XPos', XPos);
    WriteInteger('YPos', YPos);
    WriteInteger('Sound', Integer(FSound));
    WriteInteger('Step', Step);
  finally
    RegCloseKey(HK);
  end;
end;

{----------------------------------------------------------}
// Работа с текстом
{----------------------------------------------------------}

function GetNewFont(DC : HDC; FntName : String; FontSize : Integer; Style : TFontStyles): hFont;
var
 Fnt	: hFont;
 Bold	: Integer;
 Name	: String;
begin
  if fsBold in Style then
    Bold := FW_BOLD
  else
    Bold := FW_NORMAL;
  Name   := 'MS Sans Serif';
  if Length(FntName) <> 0 then
    Name := FntName;
  Fnt := CreateFont(-MulDiv(FontSize, GetDeviceCaps(DC, LOGPIXELSY),
         72), 0, 0, 0,
         Bold,
         Byte(fsItalic in Style),
         Byte(fsUnderline in Style),
	 Byte(fsStrikeOut in Style),
	 ANSI_CHARSET or RUSSIAN_CHARSET,
         OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, PROOF_QUALITY,
         DEFAULT_PITCH or FF_MODERN,
         PChar(Name));
  Result := Fnt;
end;

{----------------------------------------------------------}

function SetNewFont(hWindow : HWND; FntName : String; FontSize : Integer; Style : TFontStyles): hFont;
var
  DC	: HDC;
begin
  DC := GetWindowDC(hWindow);
  Result := GetNewFont(DC, FntName, FontSize, Style);
  ReleaseDC(hWindow, DC);
  SendMessage(hWindow, WM_SETFONT, Result, Ord(True));
end;

{----------------------------------------------------------}

procedure DrawShadowTextDC(DC : HDC; S: PChar;
			   Rect: TRect;
			   ShadowSize: Byte;
			   TextColor,
			   ShadowColor: TColorRef;
			   ShadowPos: TShadowPosition;
			   SelFont : Boolean;
			   FntName : String;
			   SizeFont : Integer;
			   FontStyle : TFontStyles;
			   TextStyle : TTextStyles);
var
  RText,
  RShadow	: TRect;
  TxtStyle	: Integer;
begin
  RText    := Rect;
  RShadow  := Rect;
  TxtStyle := 0;
  if tsLeft   in TextStyle then TxtStyle := TxtStyle or DT_LEFT;
  if tsCenter in TextStyle then TxtStyle := TxtStyle or DT_CENTER;
  if tsRight  in TextStyle then TxtStyle := TxtStyle or DT_RIGHT;
  if tsSingle in TextStyle then TxtStyle := TxtStyle or DT_SINGLELINE;
  if tsBreak  in TextStyle then TxtStyle := TxtStyle or DT_WORDBREAK;

  case ShadowPos of
    spNone	  : OffsetRect(RShadow, 0, 0);
    spLeftTop	  : OffsetRect(RShadow, -ShadowSize, -ShadowSize);
    spRightBottom : OffsetRect(RShadow,  ShadowSize,  ShadowSize);
    spLeftBottom  : OffsetRect(RShadow, -ShadowSize,  ShadowSize);
    spRightTop    : OffsetRect(RShadow,  ShadowSize, -ShadowSize);
  end; { case }

  if SelFont then
  begin
    hfntNew := GetNewFont(DC, FntName, SizeFont, FontStyle);
    if hfntNew <> 0 then
      hfntDefault := SelectObject(DC, hfntNew);
  end;
  try
    SetBkMode(DC, TRANSPARENT);

    SetTextColor(DC, ShadowColor);
    DrawText(DC, S, -1, RShadow, DT_VCENTER or TxtStyle);
    SetTextColor(DC, TextColor);
    DrawText(DC, S, -1, RText, DT_VCENTER or TxtStyle);

    UnionRect(Rect, RText, RShadow);
  finally
    if SelFont then
      if hfntNew <> 0 then
	DeleteObject(SelectObject(DC, hfntDefault));
  end;
end;

{----------------------------------------------------------}
// SysUtils
{----------------------------------------------------------}

function StrToInt(S : String) : Integer;
var
  Code	: Integer;
begin
  Val(S, Result, Code);
  if Code <> 0 then 
    Result := 0;
end;

{----------------------------------------------------------}

function IntToStr(I : Integer) : String;
var
  St : String[31];	// for Delphi 2009
begin
  Str(I, St);
  Result := String(St);
end;

{----------------------------------------------------------}

function Rect(ALeft, ATop, ARight, ABottom: Integer): TRect;
begin
  with Result do
  begin
    Left := ALeft;
    Top := ATop;
    Right := ARight;
    Bottom := ABottom;
  end;
end;

{----------------------------------------------------------}

function Bounds(ALeft, ATop, AWidth, AHeight: Integer): TRect;
begin
  with Result do
  begin
    Left := ALeft;
    Top := ATop;
    Right := ALeft + AWidth;
    Bottom :=  ATop + AHeight;
  end;
end;

{----------------------------------------------------------}

function IntPower(Base: Extended; Exponent: Integer): Extended;
asm
	mov     ecx, eax
	cdq
	fld1                      { Result := 1 }
	xor     eax, edx
	sub     eax, edx          { eax := Abs(Exponent) }
	jz      @@3
	fld     Base
	jmp     @@2
@@1:    fmul    ST, ST            { X := Base * Base }
@@2:    shr     eax,1
	jnc     @@1
	fmul    ST(1),ST          { Result := Result * X }
	jnz     @@1
	fstp    st                { pop X from FPU stack }
	cmp     ecx, 0
	jge     @@3
	fld1
	fdivrp                    { Result := 1 / Result }
@@3:
	fwait
end;

{----------------------------------------------------------}

function Power(Base, Exponent: Extended): Extended;
begin
  if Exponent = 0.0 then
    Result := 1.0               { n**0 = 1 }
  else if (Base = 0.0) and (Exponent > 0.0) then
    Result := 0.0               { 0**n = 0, n > 0 }
  else if (Frac(Exponent) = 0.0) and (Abs(Exponent) <= MaxInt) then
    Result := IntPower(Base, Trunc(Exponent))
  else
    Result := Exp(Exponent * Ln(Base))
end;

{----------------------------------------------------------}

function FloatToStr(Value: Extended; Width, Decimals: Integer): string;
var
  St : String[31];	// for Delphi 2009
begin
  Str(Value : Width : Decimals, St);
  Result := String(St);
end;

{----------------------------------------------------------}
// Graphics
{----------------------------------------------------------}

function CreateBmp(DC : HDC; W, H : Integer) : HBITMAP;
var
  bi		: TBitmapInfo;
  BitsMem	: Pointer;
begin
  FillChar(BI, SizeOf(BI), 0);
  with BI.bmiHeader do        // заполняем структуру с параметрами битмэпа
  begin
    biSize		:= SizeOf(BI.bmiHeader);
    biWidth		:= W;
    biHeight		:= H;
    biPlanes		:= 1;
    biBitCount		:= 24;
    biCompression	:= BI_RGB;
    biSizeImage		:= 0;
    biXPelsPerMeter	:= 0;
    biYPelsPerMeter	:= 0;
    biClrUsed		:= 0;
    biClrImportant	:= 0;
  end;
  Result := CreateDIBSection(DC, bi, DIB_RGB_COLORS, BitsMem, 0, 0);
end;

{----------------------------------------------------------}

procedure SplitBitmap(Wnd : HWND; var bmResult : HBitmap; sResName : String; x, y, cx, cy : Integer);
var
  DC,
  SrcDC, DstDC	: HDC;
  bmp		: HBITMAP;
begin
  DC := GetDC(Wnd);
  SrcDC := CreateCompatibleDC(DC);
  DstDC := CreateCompatibleDC(DC);
  bmp := LoadBitmap(hInstance, PChar(sResName));
  SelectObject(SrcDC, bmp);
  SelectObject(DstDC, bmResult);
  StretchBlt(DstDC, 0, 0, cx, cy, SrcDC, x, y, cx, cy, SRCCOPY);
  DeleteObject(bmp);
  DeleteDC(SrcDC);
  DeleteDC(DstDC);
  ReleaseDC(Wnd, DC);
end;

{----------------------------------------------------------}

procedure TransparentBmp(DC : HDC; Bitmap : HBitmap; xStart, yStart : Integer);
var
  bm		: Windows.TBitmap;
  hDCTemp	: HDC;
  ptSize	: TPoint;
  hDCBack,
  hDCObject,
  hDCMem,
  hDCSave	: hDC;
  bmAndBack,
  bmAndObject,
  bmAndMem,
  bmSave	: HBitmap;
  bmBackOld,
  bmObjectOld,
  bmMemOld,
  bmSaveOld	: HBitmap;
  sColor	: TColorRef;
begin
  hDCTemp := CreateCompatibleDC(DC);
  SelectObject(hDCTemp, Bitmap);
  GetObject(Bitmap, Sizeof(bm), @bm);

  ptSize.x := bm.bmWidth;
  ptSize.y := bm.bmHeight;

  //создает временные DC
  hDCBack	:= CreateCompatibleDC(DC);
  hDCObject	:= CreateCompatibleDC(DC);
  hDCMem	:= CreateCompatibleDC(DC);
  hDCSave	:= CreateCompatibleDC(DC);

  //создаем битмапы для каждого DC
  bmAndBack	:= CreateBitmap(ptSize.x, ptSize.y, 1, 1, nil);
  bmAndObject	:= CreateBitmap(ptSize.x, ptSize.y, 1, 1, nil);
  bmAndMem	:= CreateCompatibleBitmap(DC, ptSize.x, ptSize.y);
  bmSave	:= CreateCompatibleBitmap(DC, ptSize.x, ptSize.y);

  //каждому DC выбрать витмап для сохранения данных пикселей
  bmBackOld	:= SelectObject(hDCBack, bmAndBack);
  bmObjectOld	:= SelectObject(hDCObject, bmAndObject);
  bmMemOld	:= SelectObject(hDCMem, bmAndMem);
  bmSaveOld	:= SelectObject(hDCSave, bmSave);

  //установка соответствующего mapping mode
  SetMapMode(hDCTemp, GetMapMode(DC));
  //сохраняем витмап в темпе, потому что он будет переписан
  BitBlt(HDCSave, 0, 0, ptSize.x, ptSize.y, HDCTemp, 0, 0, SRCCOPY);
  //устанавливаем задний план
  sColor := SetBkColor(hDCTemp, GetPixel(hDCTemp, 0, ptSize.y - 1));
  //создаем маску
  BitBlt(hDCObject, 0, 0, ptSize.x, ptSize.y, hDCTemp, 0, 0, SRCCOPY);
  //устанавливаем задний план обратно в оригинал
  SetBkColor(hDCTemp, sColor);
  //готовим инверсную маску
  BitBlt(hDCBack, 0, 0, ptSize.x, ptSize.y, hDCObject, 0, 0, NOTSRCCOPY);
  //копируем задний план основного DC
  BitBlt(hDCMem, 0, 0, ptSize.x, ptSize.y, DC, xStart, yStart, SRCCOPY);
  BitBlt(hDCMem, 0, 0, ptSize.x, ptSize.y, hDCObject, 0, 0, SRCAND);
  BitBlt(hDCTemp, 0, 0, ptSize.x, ptSize.y, hDCBack, 0, 0, SRCAND);
  BitBlt(hDCMem, 0, 0, ptSize.x, ptSize.y, hDCTemp, 0, 0, SRCPAINT);
  BitBlt(DC, xStart, yStart, ptSize.x, ptSize.y, hDCMem, 0, 0, SRCCOPY);
  BitBlt(hDCTemp, 0, 0, ptSize.x, ptSize.y, hDCSave, 0, 0, SRCCopy);

  DeleteObject(SelectObject(hDCBack, bmBackOld));
  DeleteObject(SelectObject(hDCObject, bmObjectOld));
  DeleteObject(SelectObject(hDCMem, bmMemOld));
  DeleteObject(SelectObject(hDCSave, bmSaveOld));
  DeleteDc(hDCBack);
  DeleteDc(hDCObject);
  DeleteDc(hDCMem);
  DeleteDc(hDCSave);
  DeleteDc(hDCTemp);
end;

{----------------------------------------------------------}

procedure SemiTransparent(var bmp : HBitmap; aLeft, aTop, Alpha : Integer);
var
  Bits	: Pointer;
  X, Y,
  I,
  Size	: Integer;
  bm	: Windows.TBitmap;
begin
  GetObject(bmp, SizeOf(bm), @bm);
  Size := bm.bmWidth * bm.bmHeight * 3;
  GetMem(Bits, Size);
  try
    GetBitmapBits(bmp, Size, Bits);
    for Y := aTop to aTop + bm.bmHeight - 1 do
      for X := aLeft to aLeft + bm.bmWidth - 1 do
      begin
	I := Y * bm.bmWidth * 3 + X * 3;
	asm
	  pushad
	  mov	esi, Bits
	  add	esi, I
	  mov	edi, esi
	  mov	ebx, Alpha
	  mov	ecx, 3
@loop:
	  lodsb
	  mul	bl
	  xchg	al, ah
	  stosb
	  loop	@loop
	  popad
	end;
      end;
    SetBitmapBits(bmp, Size, Bits);
  finally
    FreeMem(Bits);
  end;
end;

{----------------------------------------------------------}

procedure DrawBitmap(Wnd : HWND; X, Y: Integer; bmSrc, bmMask: HBitmap;
		     var bmResult: HBitmap);
var
  pSrc,
  pMask,
  pTmp		: Pointer;
  Size		: Integer;
  bmTmp,
  bmOldTmp,
  bmOldResult	: HBitmap;
  DC,
  dcResult,
  dcTmp		: HDC;
  bm		: Windows.TBitmap;
begin
  GetObject(bmSrc, SizeOf(bm), @bm);
  Size := bm.bmWidth * bm.bmHeight * 3;

  DC := GetDC(Wnd); 

  dcTmp := CreateCompatibleDC(DC);
  bmTmp := CreateBmp(dcTmp, bm.bmWidth, bm.bmHeight);
  bmOldTmp := SelectObject(dcTmp, bmTmp);

  dcResult := CreateCompatibleDC(DC);
  bmOldResult := SelectObject(dcResult, bmResult);
  BitBlt(dcTmp, 0, 0, bm.bmWidth, bm.bmHeight, dcResult, X, Y, SRCCOPY);
  try
    GetMem(pSrc,  Size);
    GetMem(pMask, Size);
    GetMem(pTmp,  Size);
    try
      GetBitmapBits(bmSrc,  Size, pSrc);
      GetBitmapBits(bmMask, Size, pMask);
      GetBitmapBits(bmTmp,  Size, pTmp);

      asm
	PUSHAD
	MOV	ESI, pSrc
	MOV	EDI, pTmp
	MOV	EDX, pMask
	MOV	ECX, Size
	XOR	EBX, EBX
@Met:
	MOV	BL, [EDX]
	CMP	BL, $00
	JZ	@Empty
	PUSH	EDX
	MOV	AL, [ESI]
	MOV	AH, AL
	CMP	BL, $FF
	JZ	@Met2
	XOR	AL, AL
	XOR	DX, DX
	DIV	BX
	CMP	AX, $FF
	JLE	@Normal
	MOV	AX, $FF
@Normal:
	MOV	DL, [EDI]
	CMP	AL, DL
	JAE	@Met1
	PUSH	DX
	SUB	DL, AL
	MOV	AL, DL
	MUL	BL
	POP	DX
	SUB	DL, AH
	MOV	AH, DL
	JMP	@Met2
@Met1:
	SUB	AL, DL
	MUL	BL
	ADD	AH, DL
@Met2:
	MOV	[EDI], AH
	POP	EDX
@Empty:
	INC	ESI
	INC	EDI
	INC	EDX
	LOOP	@Met
	POPAD
      end;
      SetBitmapBits(bmTmp, Size, pTmp);
      BitBlt(dcResult, X, Y, bm.bmWidth, bm.bmHeight, dcTmp, 0, 0, SRCCOPY);
    finally
      FreeMem(pSrc);
      FreeMem(pMask);
      FreeMem(pTmp);
    end;
  finally
    DeleteObject(SelectObject(dcTmp, bmOldTmp));
    DeleteDC(dcTmp);
    SelectObject(dcResult, bmOldResult);
    DeleteDC(dcResult);
    ReleaseDC(Wnd, DC);
  end;
end;

{----------------------------------------------------------}
{                     Загрузка битмапа                     }
{----------------------------------------------------------}

function GetDInColors(BitCount: Word): Integer;
begin
  case BitCount of
    1, 4, 8: Result := 1 shl BitCount;
  else
    Result := 0;
  end;
end;

{----------------------------------------------------------}

function BytesPerScanline(PixelsPerScanline, BitsPerPixel, Alignment: Longint): Longint;
begin
  dec(Alignment);
  Result := ((PixelsPerScanline * BitsPerPixel) + Alignment) and not Alignment;
  Result := Result shr 3;
end;

{----------------------------------------------------------}

procedure BmpAssign(SrcBmp : HBitmap; var DstBmp : HBITMAP);
var
  DC,
  SrcDC,
  DstDC		: HDC;
  OldSrcBmp,
  OldDstBmp	: HBITMAP;
  bm		: Windows.TBitmap;
begin
  DC := GetDC(0);
  SrcDC  := CreateCompatibleDC(DC);
  DstDC  := CreateCompatibleDC(DC);
  OldSrcBmp := SelectObject(SrcDC, SrcBmp);
  OldDstBmp := SelectObject(DstDC, DstBmp);
  try
    GetObject(SrcBmp, SizeOf(bm), @bm);
    BitBlt(DstDC, 0, 0, bm.bmWidth, bm.bmHeight, SrcDC, 0, 0, SRCCOPY);
  finally
    DeleteObject(SelectObject(SrcDC, OldSrcBmp));
    SelectObject(DstDC, OldDstBmp);

    DeleteDC(SrcDC);
    DeleteDC(DstDC);
    ReleaseDC(0, DC);
  end;
end;

{----------------------------------------------------------}

// Часть выдранная из TGraphics

function ReadDIB(Stream: TStream; ImageSize: Longint) : HBITMAP;
const
  DIBPalSizes : Byte = SizeOf(TRGBQuad);
var
  DC, MemDC	: HDC;
  BitsMem	: Pointer;
  BitmapInfo	: PBitmapInfo;
  ColorTable	: Pointer;
  HeaderSize	: Integer;
  SectionHandle	: THandle;
  SectionOffset	: Integer;
  BMHandle	: HBITMAP;
  DIB		: TDIBSection;
begin
  Stream.Read(HeaderSize, SizeOf(HeaderSize));
  GetMem(BitmapInfo, HeaderSize + 256 * SizeOf(TRGBQuad));
  with BitmapInfo^ do
  try
    begin // support bitmap headers larger than TBitmapInfoHeader
      Stream.Read(Pointer(Longint(BitmapInfo) + SizeOf(HeaderSize))^,
        HeaderSize - SizeOf(HeaderSize));
      dec(ImageSize, HeaderSize);
    end;

    with bmiHeader do
    begin
      biSize := HeaderSize;
      ColorTable := Pointer(Longint(BitmapInfo) + HeaderSize);

      // 3 DWORD color element bit masks (ie 888 or 565) can precede colors
      if (HeaderSize = SizeOf(TBitmapInfoHeader)) and
        ((biBitCount = 16) or (biBitCount = 32)) and
        (biCompression = BI_BITFIELDS) then
      begin
        Stream.ReadBuffer(ColorTable^, 3 * SizeOf(DWORD));
	inc(Longint(ColorTable), 3 * SizeOf(DWORD));
        dec(ImageSize, 3 * SizeOf(DWORD));
      end;

      // Read the color palette
      if biClrUsed = 0 then
        biClrUsed := GetDInColors(biBitCount);
      Stream.ReadBuffer(ColorTable^, biClrUsed * DIBPalSizes);
      dec(ImageSize, biClrUsed * DIBPalSizes);

      // biSizeImage can be zero. If zero, compute the size.
      if biSizeImage = 0 then            // top-down DIBs have negative height
        biSizeImage := BytesPerScanLine(biWidth, biBitCount, 32) * Abs(biHeight);

      if biSizeImage < DWORD(ImageSize) then
        ImageSize := biSizeImage;
    end;

    SectionHandle := 0;
    SectionOffset := 0;

    DC := GetDC(0);
    try
      if (bmiHeader.biCompression = BI_RLE8) or
	 (bmiHeader.biCompression = BI_RLE4) then
      begin
	MemDC := 0;
	GetMem(BitsMem, ImageSize);
	try
	  Stream.ReadBuffer(BitsMem^, ImageSize);
	  MemDC := CreateCompatibleDC(DC);
	  DeleteObject(SelectObject(MemDC, CreateCompatibleBitmap(DC, 1, 1)));
	  BMHandle := CreateDIBitmap(MemDC, BitmapInfo^.bmiHeader, CBM_INIT, BitsMem, BitmapInfo^, DIB_RGB_COLORS);
	finally
	  if MemDC <> 0 then DeleteDC(MemDC);
	  FreeMem(BitsMem);
	end;
      end
      else
      begin
        BMHandle := CreateDIBSection(DC, BitmapInfo^, DIB_RGB_COLORS, BitsMem, SectionHandle, SectionOffset);
        try
          if SectionHandle = 0 then
	    Stream.ReadBuffer(BitsMem^, ImageSize);
        except
          DeleteObject(BMHandle);
	end;
      end;

      if BMHandle <> 0 then
      begin
        FillChar(DIB, SizeOf(DIB), 0);
        GetObject(BMHandle, Sizeof(DIB), @DIB);
        // Создать полноцветный битмап, независимо от загружаемого.
        Result := CreateBmp(DC, DIB.dsBm.bmWidth, DIB.dsBm.bmHeight);
        BmpAssign(BMHandle, Result);
      end;

    finally
      ReleaseDC(0, DC);
    end;
  finally
    FreeMem(BitmapInfo);
  end;
end;

{----------------------------------------------------------}

function LoadBmpFromRes(Value : String) : HBITMAP;
var
  MemStream	: TMemoryStream;
  Bmf		: TBitmapFileHeader;
begin
  MemStream := TMemoryStream.Create;
  try
    MemStream.Clear;
    Decompress(Value, MemStream);
    MemStream.Seek(0, 0);
    MemStream.ReadBuffer(Bmf, SizeOf(Bmf));
    Result := ReadDIB(MemStream, MemStream.Size - SizeOf(Bmf));
  finally
    MemStream.Free;
  end;
end;

{----------------------------------------------------------}
{			TButton				   }
{----------------------------------------------------------}

function MBWndProc(hWnd, iMsg, wParam, lParam : Integer): Integer; stdcall;
var
  mb	: TButton;
begin
  mb := TButton(GetWindowLong(hWnd, GWL_USERDATA));
  Case iMsg of
    WM_PAINT : mb.Redraw;

    WM_LBUTTONDOWN :
    begin
      mb.fPressed := True;
      mb.Redraw;
      SetCapture(hWnd);
    end;

    WM_LBUTTONUP:
    begin
      ReleaseCapture;
      if mb.fPressed then
	PostMessage(GetParent(hWnd), WM_COMMAND, wParam, hWnd);
      mb.fPressed := False;
      mb.Redraw;
    end;

    WM_MOUSEMOVE:
    begin
      if (wParam = MK_LBUTTON) and (GetCapture = DWord(hWnd)) then
      begin
	mb.fPressed := not ((LoWord(lParam) > mb.fWidth) or (HiWord(lParam) > mb.fHeight));
	mb.Redraw;
      end;
    end;
  end;
  Result := DefWindowProc(hWnd, iMsg, wParam, lParam);
end;

constructor TButton.Create(x, y, w, h : Integer; hParent : THandle; fHint : String);
begin
  Parent	:= hParent;
  fHandle	:= CreateWindow('DSButton', NIL, WS_CHILD, x, y, w, h, Parent, 0, HInstance, NIL);
  fPressed	:= False;
  fVisible	:= False;
  fLeft		:= x;
  fTop		:= y;
  fWidth	:= w;
  fHeight	:= h;
  fCaption	:= '';
  SetRect(fRect, fLeft, fTop, fLeft + fWidth, fTop + fHeight);

  fDC		:= GetDC(Parent);
  memDC		:= CreateCompatibleDC(fDC);
  bmBmp1	:= CreateBmp(memDC, fWidth, fHeight);
  bmBmp2	:= CreateBmp(memDC, fWidth, fHeight);
  bmMask1	:= CreateBmp(memDC, fWidth, fHeight);
  bmMask2	:= CreateBmp(memDC, fWidth, fHeight);

  with tti do
  begin
    cbSize	:= SizeOf(TToolInfo);
    uFlags	:= TTF_IDISHWND;
    uId		:= fHandle;
    hWnd	:= Parent;
    hInst	:= hInstance;
    lpszText	:= PAnsiChar(AnsiString(fHint));
  end;
  SendMessage(hToolTip, TTM_ADDTOOL, 0, Integer(@tti));

  SetWindowLong(fHandle, GWL_USERDATA, Integer(Self));
end;

destructor TButton.Destroy;
begin
  DeleteObject(bmBmp1);
  DeleteObject(bmBmp2);
  DeleteObject(bmMask1);
  DeleteObject(bmMask2);
  DeleteDC(memDC);
  ReleaseDC(Parent, fDC);
end;

procedure TButton.SetCaption(Value : String);
begin
  if Value = fCaption then
    Exit;
  fCaption := Value;
  Redraw;
end;

procedure TButton.SetHint(Value : String);
begin
  tti.lpszText := PAnsiChar(AnsiString(Value));
  SendMessage(hToolTip, TTM_UPDATETIPTEXT, 0, Integer(@tti));
end;

procedure TButton.SetVisible(Value : Boolean);
var
  I	: Integer;
begin
  if Value = fVisible then Exit;
  fVisible := Value;
  if Value then I := SW_SHOW else I := SW_HIDE;
  ShowWindow(fHandle, I);
end;

procedure TButton.Redraw;
var
  DC, 
  CanvasBtn	: HDC;
  bmTemp	: HBitmap;
  OldBmp	: HBitmap;
  Offset	: Integer;
  aRect		: TRect;
begin
  DC := GetDC(fHandle);
  CanvasBtn := CreateCompatibleDC(DC);
  bmTemp := CreateBmp(CanvasBtn, fWidth, fHeight);
  OldBmp := SelectObject(CanvasBtn, bmTemp);
  try
    BitBlt(CanvasBtn, 0, 0, fWidth, fHeight, CanvasSrc, fLeft, fTop, SRCCOPY);
    SelectObject(CanvasBtn, OldBmp);

    if not fPressed then
      DrawBitmap(Parent, 0, 0, bmBmp1, bmMask1, bmTemp)
    else
      DrawBitmap(Parent, 0, 0, bmBmp2, bmMask2, bmTemp);

    OldBmp := SelectObject(CanvasBtn, bmTemp);

    Offset := 0;
    if fPressed then
      Offset := 1;

    SetRect(aRect, Offset, Offset, fWidth + Offset, fHeight + Offset);
    OffsetRect(aRect, -1, -1);

    if fCaption <> '' then
      DrawShadowTextDC(CanvasBtn, PChar(fCaption), aRect, 1, $FFFFFF, $0, spRightBottom, True, 'Tahoma', 10, [fsBold], [tsCenter, tsSingle]);

    BitBlt(DC, 0, 0, fWidth, fHeight, CanvasBtn, 0, 0, SRCCOPY);
  finally
    DeleteObject(SelectObject(CanvasBtn, OldBmp));
    DeleteDC(CanvasBtn);
    ReleaseDC(fHandle, DC);
  end;
end;

{----------------------------------------------------------}

initialization

  ZeroMemory(@WndClass, SizeOf(TWndClassEx));
  WndClass.hInstance := hInstance;
  with WndClass do
  begin
    cbSize		:= SizeOf(TWndClassEx);
    lpfnWndProc		:= @MBWndProc;
    lpszClassName	:= 'DSButton';
    hCursor		:= LoadCursor(hInstance, 'HANDPT');
  end;
  RegisterClassEx(WndClass);

finalization
  DestroyCursor(WndClass.hCursor);

end.
