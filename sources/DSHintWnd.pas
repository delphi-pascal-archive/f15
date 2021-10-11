unit DSHintWnd;

interface

uses
  Windows, Messages;

{$I Common.inc}

type
  tagNMTTDISPINFOA = packed record
    hdr		: TNMHdr;
    lpszText	: PAnsiChar;
    szText	: array[0..79] of AnsiChar;
    hinst	: HINST;
    uFlags	: UINT;
    lParam	: LPARAM;
  end;
  tagNMTTDISPINFO = tagNMTTDISPINFOA;
  PNMTTDispInfoA  = ^TNMTTDispInfoA;
  PNMTTDispInfo   = PNMTTDispInfoA;
  TNMTTDispInfoA  = tagNMTTDISPINFOA;
  TNMTTDispInfo = TNMTTDispInfoA;

  PToolInfoA = ^TToolInfoA;
  PToolInfo = PToolInfoA;
  TToolInfoA = packed record
    cbSize	: UINT;
    uFlags	: UINT;
    hwnd	: HWND;
    uId		: UINT;
    Rect	: TRect;
    hInst	: THandle;
    lpszText	: PAnsiChar;
  end;
  TToolInfo = TToolInfoA;

const
  TTS_ALWAYSTIP		= $01;
  TTS_NOPREFIX		= $02;

  TTF_IDISHWND		= $0001;
  TTF_SUBCLASS		= $0010;

  TTM_ACTIVATE		= WM_USER + 1;
  TTM_SETDELAYTIME	= WM_USER + 3;
  TTM_ADDTOOL		= WM_USER + 4;
  TTM_DELTOOL		= WM_USER + 5;
  TTM_RELAYEVENT	= WM_USER + 7;
  TTM_UPDATETIPTEXT	= WM_USER + 12;
  TTM_GETTOOLCOUNT	= WM_USER + 13;
  TTM_SETTIPBKCOLOR	= WM_USER + 19;
  TTM_SETTIPTEXTCOLOR	= WM_USER + 20;
  TTM_GETTIPBKCOLOR	= WM_USER + 22;
  TTM_SETMAXTIPWIDTH	= WM_USER + 24;
  TTM_SETMARGIN		= WM_USER + 26;
  TTM_GETMARGIN		= WM_USER + 27;
  
  TTN_FIRST		= 0-520;
  TTN_GETDISPINFO	= TTN_FIRST;
  TTN_NEEDTEXTA		= TTN_FIRST - 0;
  TTN_NEEDTEXT		= TTN_NEEDTEXTA;
  
type
  TToolTip	= class
  private
    id		: UINT;
    fParent,
    Handle	: HWND;
    fActive	: Boolean;

    fHint	: String;
    fTxtColor,
    fBkColor	: TColorRef;

    procedure	SetActive(Value : Boolean);
    procedure   SetHint(Hint : String);
    procedure   SetTxtColor(Color : TColorRef);
    procedure   SetBkColor(Color : TColorRef);
  public
    constructor Create(hParent : HWND);
    destructor  Destroy; override;

    procedure   AddHintRect(R : TRect; Hint : String);
    procedure   RelayMouseMove(Pos: TSmallPoint);
    procedure   Clear;
    procedure   Activate;
    procedure   Deactivate;
  published
    property Active  : Boolean   read fActive	 write SetActive;
    property Hint    : String    read fHint      write SetHint;
    property HintTxtColor: TColorRef read fTxtColor  write SetTxtColor;
    property HintBkColor:  TColorRef read fBkColor   write SetBkColor;
  end;


implementation

const
  MAX_TOOLTIP_WINDOW_WIDTH = 220;
  TOOLTIPS_CLASS = 'tooltips_class32';

var
  ti	: TToolInfo;

constructor TToolTip.Create(hParent : HWND);
var
  R	: TRect;
begin
  Handle := CreateWindowEx(WS_EX_TOPMOST, TOOLTIPS_CLASS, nil, TTS_ALWAYSTIP, 
			   0, 0, 0, 0,
			   hParent, 0, hInstance, nil);

  if Handle <> 0 then
  begin
    FillChar(ti, SizeOf(ti), 0);
    ti.cbSize	:= SizeOf(TToolInfo);
    ti.uFlags	:= TTF_SUBCLASS;
    ti.hInst	:= hInstance;
    SendMessage(Handle, TTM_GETMARGIN, 0, Integer(@R));
    SetRect(R, R.Left + 2, R.Top + 2, R.Right + 2, R.Bottom + 2);
    SendMessage(Handle, TTM_SETMARGIN, 0, Integer(@R));
    SendMessage(Handle, TTM_SETMAXTIPWIDTH, 0, MAX_TOOLTIP_WINDOW_WIDTH);
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  end;

  fParent := hParent;
  fActive := True;
end;

destructor TToolTip.Destroy;
begin
  inherited;
  DestroyWindow(Handle);
end;

procedure TToolTip.AddHintRect(R: TRect; Hint: String);
begin
  ti.cbSize	:= sizeof(TToolInfo);
  ti.hwnd	:= fParent;
  ti.Rect	:= R;
  ti.lpszText	:= PAnsiChar(AnsiString(Hint));

  Inc(id);
  SendMessage(Handle, TTM_ADDTOOL, 0, Integer(@ti));
  fHint := Hint;
  SetActive(False);
end;

procedure TToolTip.SetHint(Hint : String);
var
  Rect	: TRect;
  Bol	: Boolean;
begin
  if (fParent <> 0) and (GetClientRect(fParent, Rect)) then
  begin
    ti.cbSize	:= SizeOf(TToolInfo);
    ti.hwnd	:= fParent;
    ti.Rect	:= Rect;
    Bol		:= Length(ti.lpszText) <> 0;
    ti.lpszText	:= PAnsiChar(AnsiString(Hint));

    if Bol then
      SendMessage(Handle, TTM_UPDATETIPTEXT, 0, Integer(@ti))
    else  
      SendMessage(Handle, TTM_ADDTOOL, 0, Integer(@ti));
    fHint := Hint;
  end;
  SetActive(False);
end;

procedure TToolTip.SetTxtColor(Color: TColorRef);
begin
  SendMessage(Handle, TTM_SETTIPTEXTCOLOR, Color, 0);
end;

procedure TToolTip.SetBkColor(Color: TColorRef);
begin
  SendMessage(Handle, TTM_SETTIPBKCOLOR, Color, 0);
end;

procedure TToolTip.RelayMouseMove(Pos: TSmallPoint);
var
  Msg	: TMsg;
begin
  Msg.wParam	:= 0;
  Msg.lParam	:= LongInt(Pos);
  Msg.message	:= wm_MouseMove;
  Msg.hwnd	:= fParent;

  SendMessage(Handle, TTM_RelayEvent, 0, LongInt(@Msg));
end;

procedure TToolTip.Clear;
var
  I	: Integer;
begin
  ti.cbSize	:= SizeOf(ti);
  ti.hwnd	:= fParent;
  for I := 0 to id -1 do
  begin
    ti.uId	:= I;
    SendMessage(Handle, TTM_DELTOOL, 0, LongInt(@ti));
  end;
  id := 0;
end;

procedure TToolTip.Activate;
begin
  if fActive then
    Exit;
  SendMessage(Handle, TTM_ACTIVATE, 1, 0);
  fActive:= True;
end;

procedure TToolTip.Deactivate;
begin
  if not fActive then
    Exit;
  SendMessage(Handle, TTM_ACTIVATE, 0, 0);
  fActive:= False;
end;

procedure TToolTip.SetActive(Value : Boolean);
begin
  if Value then Activate
  else Deactivate;
end;

end.

