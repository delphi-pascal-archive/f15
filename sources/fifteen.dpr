{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
{                                                                 }
{  Fifteen - Пятнашки                                             }
{  c 1999-2006 DSoft                                              }
{  http://dsoft1961.narod.ru                                      }
{                                                                 }
{  Игра компилировалась на Delphi 3, Delphi 5, Delphi 7,          }
{  Delphi 2006 и Delphi 2009.                                     }
{                                                                 }
{  по всем вопросам обращаться:                                   }
{  DSoft1961@Yandex.ru                                            }
{                                                                 }
{~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}

program fifteen;

uses
  Windows, Messages, MMSystem, ShellAPI, Solv, Util, dshintwnd;

{$I Common.inc}

const
  BlockSize	= 64;
  SizeX		= 356;
  SizeY		= 276;
  OffsLeft	= 10;
  OffsTop	= 10;

var
  Window	: HWND;
  Msg		: TMsg;
  aBIcon,
  aSIcon	: HICON;
  WClass	: TWndClassEx;
  hand,
  arrow,
  none		: HCURSOR;
  Home, Mail	: TToolTip;

  CXSCREEN,
  CYSCREEN	: Integer;

  m_bmp		: array[0..15] of HBITMAP;
  m_bmpmain,
  m_bmptemp,
  m_bmppause,
  m_bmpinact,
  m_bmptitle,
  m_bmpabout,
  m_temp	: HBITMAP;
  m_clDC,
  ScreenDC,
  m_tempdc	: HDC;
  sRect		: TRect;

  btNew,
  btSolve,
  btOption,
  btExit,
  btSound,
  btOK,
  btCancel,
  btAbout	: TButton;
  btStep	: array[0..4] of TButton;

  AppActive	: Boolean;
  OldActive	: Boolean;

  Map		: array[0..15] of Byte;
  Displ		: array[0..3, 0..3] of Byte;
  StrFinal	: String;
  HandMove	: Integer;

  // Visual Moving
  CooX, CooY	: Integer;	// Start coordinates x, y
  OffsX, OffsY	: Integer;	// Offset x, y
  SrcX, SrcY	: Integer;	// Source x, y
  DestX, DestY	: Integer;	// Target x, y
  MouseEnabled,
  isGoMove	: Boolean;
  FirstMove, 
  CurMove	: PMoves;	// Первое и текущий сдвиг

const
  AppName	= 'Fifteen from the DSoft';

var  
  flag		: Boolean = False;	// Temporary moving flag
  isMoving	: Boolean = False;	// For Visualization
  isAutoMove	: Boolean = False;
  fPause	: Boolean = False;
  fOption	: Boolean = False;
  fAbout	: Boolean = False;
  isGame	: Boolean = True;


// имя ресурса меняем на любое не совпадающее с именем проекта
// из-за капризов визуальной оболочки Delphi
{$R f15.RES}

{----------------------------------------------------------}

procedure CreateToolTip(Wnd : HWND);
begin
  hTooltip := CreateWindow(TOOLTIPS_CLASS, nil, TTS_ALWAYSTIP,
			Integer(CW_USEDEFAULT),
			Integer(CW_USEDEFAULT),
			Integer(CW_USEDEFAULT),
			Integer(CW_USEDEFAULT),
			Wnd, 0, hInstance, nil);
end;

function HookProc(nCode, wParam, lParam : Integer): Integer; stdcall;
var
  i	: Integer;
begin
  i := PMsg(lParam)^.message;
  if (nCode >= 0) AND ((i = WM_MOUSEMOVE) OR
		       (i = WM_NCLBUTTONDOWN) OR
		       (i = WM_LBUTTONUP) OR
		       (i = WM_RBUTTONUP) OR
                       (i = WM_RBUTTONDOWN)) then
    SendMessage(hToolTip, TTM_RELAYEVENT, 0, lParam);
  Result := CallNextHookEx(hHook, nCode, wParam, lParam);
end;

{----------------------------------------------------------}

procedure PlaySnd(S : String);
begin
  if fSound then
    PlaySound(PChar(S), hInstance, SND_RESOURCE or SND_MEMORY or SND_ASYNC);
end;

{----------------------------------------------------------}

procedure Initialize;
var
  I, X, Y, Z	: Integer;
  TempMove	: PMoves;
begin
  FillChar(Map, SizeOf(Map), $FF);

  I := 0;
  while I < 16 do
  begin
    X := Random(4);
    Y := Random(4);
    if Map[X * 4 + Y] = $FF then
    begin
      Map[X * 4 + Y] := I;
      inc(I)
    end;
  end;

  X := 0;
  Y := 0;
  Z := 0;
  
  // проверка на решаемость
  if (not Solve(Map)) then
  begin
    // удалим предыдущее решение
    CurMove := GetMoves;
    while (CurMove <> NIL) do
    begin
      TempMove := CurMove.next;
      Dispose(CurMove);
      CurMove := TempMove;
    end;
    
    // коррекция
    for I := 0 to 15 do
    begin
      if Map[I] = 13 then
        X := I;
      if Map[I] = 14 then
        Y := I;
      if Map[I] = 15 then
	Z := I;
    end;

    // заключительная коррекция нерешаемых раскладов
    if (LastNumber = 354) then
    begin
      Map[Y] := 15;
      Map[Z] := 14;
    end
    else if (LastNumber = 435) then
    begin
      Map[X] := 15;
      Map[Z] := 13;
    end
    else if (LastNumber = 543) then
    begin
      Map[X] := 14;
      Map[Y] := 13;
    end
  end;
end;

{----------------------------------------------------------}

procedure UpdateMap(Show : Boolean);
var
  I, J	: Integer;
begin
  if Show then
  begin
    for I := 0 to 3 do
      for J := 0 to 3 do
	Displ[I][J] := Map[I * 4 + J];
  end
  else
  begin
    for I := 0 to 3 do
      for J := 0 to 3 do
	Map[I * 4 + J] := Displ[I][J];
  end;
end;

{----------------------------------------------------------}

procedure DrawBlock(DC, memDC : HDC);
var
  I, J	: Integer;
begin
  // отрисовка блоков
  if fPause or fOption or fAbout then Exit;
  for I := 0 to 3 do
    for J := 0 to 3 do
    begin
      if ((flag) and (I = DestY) and (J = DestX)) then
	continue;
      if (Map[I * 4 + J] <> 0) then
	TransparentBmp(DC, m_bmp[Map[I * 4 + J]], BlockSize * J + OffsLeft, BlockSize * I + OffsTop)
      else if (not flag) then
      begin
	SelectObject(memDC, m_bmptemp);
	BitBlt(DC, BlockSize * J + OffsLeft, BlockSize * I + OffsTop, BlockSize, BlockSize, memDC, BlockSize * J + OffsLeft, BlockSize * I + OffsTop, SRCCOPY);
      end
    end;
  SetRect(sRect, OffsLeft, OffsTop, 4 * BlockSize + OffsLeft, 4 * BlockSize + OffsTop);
end;

{----------------------------------------------------------}

procedure SetPause(Wnd : HWND; B : Boolean);
var
  DC		: HDC;
  memDC		: HDC;
  bmp		: HBITMAP;
  bi		: TBitmapInfo;
  BitsMem	: Pointer;
begin
  // выставим или снимем паузу
  DC := GetDC(Wnd);
  memDC := CreateCompatibleDC(DC);
  try
    if B then 
    begin
      FillChar(BI, SizeOf(BI), 0);
      with BI.bmiHeader do        // заполняем структуру с параметрами битмапа
      begin
	biSize		:= SizeOf(BI.bmiHeader);
	biWidth		:= 200;
	biHeight	:= 50;
	biPlanes	:= 1;
	biBitCount	:= 24;
	biCompression	:= BI_RGB;
	biSizeImage	:= 0;
	biXPelsPerMeter	:= 0;
	biYPelsPerMeter	:= 0;
	biClrUsed	:= 0;
	biClrImportant	:= 0;
      end;
      bmp := CreateDIBSection(memDC, bi, DIB_RGB_COLORS, BitsMem, 0, 0);
      SelectObject(memDC, bmp);
      BitBlt(memDC, 0, 0, 200, 50, ScreenDC, 40, 110, SRCCOPY);

      SemiTransparent(bmp, 0, 0, 120);

      BitBlt(ScreenDC, 40, 110, 200, 50, memDC, 0, 0, SRCCOPY);
      TransparentBmp(ScreenDC, m_bmpPause, 75, 114);
      DeleteObject(bmp);
    end
    else
    begin
      SelectObject(memDC, m_bmptemp);
      BitBlt(ScreenDC, 40, 110, 200, 50, memDC, 40, 110, SRCCOPY);
      DrawBlock(ScreenDC, memDC);
    end;
    InvalidateRect(Wnd, NIL, False);
  finally
    DeleteDC(memDC);
    ReleaseDC(Wnd, DC);
  end;
end;

{----------------------------------------------------------}

procedure DrawPhase(Wnd : HWND);
var
  DC,  memDC	: HDC;
  Oldbmp	: HBITMAP;
begin
  // отрисовка - WM_PAINT
  if isGoMove then Exit;

  DC := GetDC(Wnd);
  memDC := CreateCompatibleDC(DC);

  DrawBlock(ScreenDC, memDC);

  if (AppActive <> OldActive) and ((not fOption) and (not fAbout)) then
    if not AppActive then
    begin
      Oldbmp := SelectObject(memDC, m_bmpinact);
      BitBlt(ScreenDC, 278, 31, 61, 57, memDC, 0, 0, SRCCOPY);
      SelectObject(memDC, Oldbmp);
      fPause := True;
      SetPause(Wnd, True);
    end
    else
    begin
      Oldbmp := SelectObject(memDC, m_bmptemp);
      BitBlt(ScreenDC, 278, 31, 61, 57, memDC, 278, 31, SRCCOPY);
      SelectObject(memDC, Oldbmp);
      fPause := False;
      SetPause(Wnd, False);
    end;

  InvalidateRect(Wnd, @sRect, False);
  DeleteDC(memDC);
  ReleaseDC(Wnd, DC);
end;

{----------------------------------------------------------}

procedure EndAutoMove(Wnd : HWND);
var
  TempMove	: PMoves;
begin
  KillTimer(Wnd, 2);
  isGoMove := False;

  // удалим предыдущее решение
  CurMove := FirstMove;
  while (CurMove <> NIL) do
  begin
    TempMove := CurMove.next;
    Dispose(CurMove);
    CurMove := NIL;
    CurMove := TempMove;
  end;
end;

{----------------------------------------------------------}

procedure SolveGame(Wnd : HWND);
var
  aRect : TRect;
begin
  // решает компьютер
  if (fOption or fAbout) or not isGame then
  begin
    PlaySnd('error');
    Exit;
  end
  else
    PlaySnd('Clk');

  if isGoMove then
  begin
    EndAutoMove(Wnd);
    Exit;
  end;

  MouseEnabled := False;
  // В принципе эта проверка не нужна, т.к. на этапе генерации
  //  расклада идёт проверка на корректность.
  if (not Solve(Map)) then
    MessageBox(0, 'The Full solution is not found!', 'Information', MB_ICONINFORMATION or MB_OK);
  isGoMove := False;
  SetTimer(Wnd, 2, 300, NIL);
  FirstMove := GetMoves;
  CurMove := FirstMove;

  isGoMove := True;

  SetRect(aRect, OffsLeft, OffsTop, 4 * BlockSize + OffsLeft, 4 * BlockSize + OffsTop);
  InvalidateRect(Wnd, @aRect, False);
end;

{----------------------------------------------------------}

procedure AboutGame(Wnd : HWND);
var
  aRect 	: TRect;
  DC,  memDC	: HDC;
  Oldbmp, Bmp	: HBITMAP;
begin
  // О программе
  if isMoving then
  begin
    PlaySnd('error');
    Exit;
  end;

  if isGoMove then
    EndAutoMove(Wnd);

  fAbout := not fAbout;
  PostMessage(Wnd, WM_SETCURSOR, 0, 0);

  DC := GetDC(Wnd);
  memDC := CreateCompatibleDC(DC);
  try
    PlaySnd('Clk');

    if fAbout then
    begin
      Home.Active := True;
      Mail.Active := True;
      Bmp := CopyImage(m_bmptemp, IMAGE_BITMAP, 0, 0, LR_COPYRETURNORG);
      Oldbmp := SelectObject(memDC, Bmp);
      BitBlt(ScreenDC, 10, 10, 256, 256, memDC, 10, 10, SRCCOPY);
      TransparentBmp(ScreenDC, m_bmptitle, 11, 12);
      DeleteObject(SelectObject(memDC, Oldbmp)); // Delete Bmp
      TransparentBmp(ScreenDC, m_bmpAbout, 11, 46);
      btOk.Visible := True;
      btOk.SetHint('OK.');

      DrawShadowTextDC(ScreenDC, 'О ПРОГРАММЕ', Rect(73, 19, 205, 40),
		       2, $FFFFFF, 0, spRightBottom, True,
		       'Arial', 12, [fsBold], [tsCenter, tsSingle]);
    end
    else
    begin
      Home.Active := False;
      Mail.Active := False;
      btOk.Visible := False;
      Oldbmp := SelectObject(memDC, m_bmptemp);
      BitBlt(ScreenDC, 10, 10, 256, 256, memDC, 10, 10, SRCCOPY);
      SelectObject(memDC, Oldbmp);
      DrawBlock(ScreenDC, memDC);
    end;

    SetRect(aRect, OffsLeft, OffsTop, 4 * BlockSize + OffsLeft, 4 * BlockSize + OffsTop);
    InvalidateRect(Wnd, @aRect, False);
  finally
    DeleteDC(memDC);
    ReleaseDC(Wnd, DC);
  end;
end;

{----------------------------------------------------------}

procedure OptionGame(Wnd : HWND);
var
  aRect 	: TRect;
  DC,  memDC	: HDC;
  Oldbmp, Bmp	: HBITMAP;
  I		: Integer;
begin
  // Настройки
  if isMoving or isGoMove then
  begin
    PlaySnd('error');
    Exit;
  end;

  if isGoMove then
    EndAutoMove(Wnd);

  fOption := not fOption;
  fAbout  := False;
  PostMessage(Wnd, WM_SETCURSOR, 0, 0);

  DC := GetDC(Wnd);
  memDC := CreateCompatibleDC(DC);
  try
    PlaySnd('Clk');

    if fOption then
    begin
      Home.Active := False;
      Mail.Active := False;

      OldSound := fSound;
      OldStep  := Step;

      Bmp := CopyImage(m_bmptemp, IMAGE_BITMAP, 0, 0, LR_COPYRETURNORG);
      Oldbmp := SelectObject(memDC, Bmp);
      BitBlt(ScreenDC, 10, 10, 256, 256, memDC, 10, 10, SRCCOPY);
      TransparentBmp(ScreenDC, m_bmptitle, 11, 12);
      DeleteObject(SelectObject(memDC, Oldbmp)); // Delete Bmp

      btSound.Visible	:= True;
      btOk.Visible	:= True;
      btCancel.Visible	:= True;
      btAbout.Visible	:= True;
      btOk.SetHint('Принять измененния.');

      for I := 0 to 4 do
        btStep[I].Visible := True;

      DrawShadowTextDC(ScreenDC, 'НАСТРОЙКИ', Rect(73, 19, 205, 40),
		       2, $FFFFFF, 0, spRightBottom, True,
		       'Arial', 12, [fsBold], [tsCenter, tsSingle]);

      with btSound.Rect do
        aRect := Rect(Left, Top - 30, Right + 200, Top);

      DrawShadowTextDC(ScreenDC, 'Звуковые эффекты', aRect,
		       3, $E0E0E0, 0, spRightBottom, True,
		       'Arial', 12, [fsBold], [tsLeft, tsSingle]);

      with btStep[0].Rect do
        aRect := Rect(Left, Top - 30, Left + 220, Top);

      DrawShadowTextDC(ScreenDC, 'Шаг сдвига блоков', aRect,
		       3, $E0E0E0, 0, spRightBottom, True,
		       'Arial', 12, [fsBold], [tsLeft, tsSingle]);
      with btStep[4].Rect do
        aRect := Rect(Right + 10, Top - 5, Right + 80, Bottom + 5);

      BitBlt(m_tempdc, 0, 0, 70, 30, ScreenDC, aRect.Left, aRect.Top, SRCCOPY);
      DrawShadowTextDC(ScreenDC, PChar('Шаг = ' + IntToStr(Step)), aRect,
		       3, $E0E0E0, 0, spRightBottom, True,
		       'Arial', 12, [fsBold], [tsLeft, tsSingle]);
    end
    else
    begin
      btSound.Visible	:= False;
      btOk.Visible	:= False;
      btCancel.Visible	:= False;
      btAbout.Visible	:= False;

      for I := 0 to 4 do
        btStep[I].Visible := False;

      Oldbmp := SelectObject(memDC, m_bmptemp);
      BitBlt(ScreenDC, 10, 10, 256, 256, memDC, 10, 10, SRCCOPY);
      SelectObject(memDC, Oldbmp);
      DrawBlock(ScreenDC, memDC);

      fSound := OldSound;
      Step   := OldStep;
      if fSound then btSound.Caption := '+'
      else btSound.Caption := '';

      if fAbout then fAbout := False;
    end;

    SetRect(aRect, OffsLeft, OffsTop, 4 * BlockSize + OffsLeft, 4 * BlockSize + OffsTop);
    InvalidateRect(Wnd, @aRect, False);

  finally
    DeleteDC(memDC);
    ReleaseDC(Wnd, DC);
  end;
end;

{----------------------------------------------------------}

procedure NewGame(Wnd : HWND);
var
  aRect : TRect;
begin
  // новый расклад
  PlaySnd('Clk');
  if fOption then OptionGame(Wnd);
  if fAbout then AboutGame(Wnd);
  Initialize;
  UpdateMap(True);

  if isGoMove then
    EndAutoMove(Wnd);

  if Flag then
  begin
    KillTimer(Wnd, 1);
    Flag       := False;
    isMoving   := False;
    isAutoMove := False;
  end;
  MouseEnabled := True;
  StrFinal := '';
  HandMove := 0;
  IsGame := True;
  DrawPhase(Wnd);
  SetRect(aRect, OffsLeft, OffsTop, 4 * BlockSize + OffsLeft, 4 * BlockSize + OffsTop);
  InvalidateRect(Wnd, @aRect, False);
end;

{----------------------------------------------------------}

procedure OnButtonClick(Wnd : HWND; Btn : TButton);
var
  aRect 	: TRect;
begin
  // нажатие кнопок
  PlaySnd('Clk');

  if Btn = btNew    then NewGame(Wnd);
  if Btn = btSolve  then SolveGame(Wnd);
  if Btn = btOption then OptionGame(Wnd);
  if Btn = btExit   then
  begin
    if isGoMove then
      EndAutoMove(Wnd);
    PostMessage(Wnd, WM_CLOSE, 0, 0);
  end;

  if fOption then
  begin
    if Btn = btOk then
    begin
      OldSound := fSound;
      OldStep  := Step;
      OptionGame(Wnd);
    end;
    if Btn = btCancel then
    begin
      fSound := OldSound;
      Step   := OldStep;
      OptionGame(Wnd);
    end;
    if Btn = btSound then
    begin
      fSound := not fSound;
      if fSound then btSound.Caption := '+'
      else btSound.Caption := '';
    end;
    if (Btn = btStep[0]) or (Btn = btStep[1]) or (Btn = btStep[2]) or
       (Btn = btStep[3]) or (Btn = btStep[4]) then
    begin
      if (Btn = btStep[0]) then Step := 1
      else if (Btn = btStep[1]) then Step := 2
      else if (Btn = btStep[2]) then Step := 4
      else if (Btn = btStep[3]) then Step := 8
      else if (Btn = btStep[4]) then Step := 16;

      with btStep[4].Rect do
        aRect := Rect(Right + 10, Top - 5, Right + 80, Bottom + 5);
      BitBlt(ScreenDC, aRect.Left, aRect.Top, 70, 30, m_tempdc, 0, 0, SRCCOPY);

      DrawShadowTextDC(ScreenDC, PChar('Шаг = ' + IntToStr(Step)), aRect,
		       3, $E0E0E0, 0, spRightBottom, True,
		       'Arial', 12, [fsBold], [tsLeft, tsSingle]);
      InvalidateRect(Wnd, @aRect, False);
    end;
    if btn = btAbout then
    begin
      OptionGame(Wnd);
      AboutGame(Wnd);
    end;
  end
  else
  begin
    if (btn = btAbout) or (Btn = btOk) then
      AboutGame(Wnd);
  end;
end;

{----------------------------------------------------------}

function GetMessageStep(Step : Integer) : String;
var
  S, S1 : String;
begin
  // подсчет ходов 
  S := IntToStr(Step);
  S1 := S[Length(S)];
  S := ' ход';
  if (S1 = '2') or (S1 = '3') or (S1 = '4') then
    S := S + 'а'
  else
    S := S + 'ов';
  Result := 'Расклад собран за ' + IntToStr(Step) + S;
end;

{----------------------------------------------------------}

procedure UrlClick(Url : String);
begin
  ShellExecute(0, 'Open', PChar(Url), '', '', SW_SHOWNORMAL);
end;

procedure OnLButtonDown(Wnd : HWND; pt : TPoint);
var
  X, Y  : Integer;
  I, J	: Integer;
begin
  // обработка мышки
  if fPause or fOption then Exit;
  if fAbout then
  begin
    if PtInRect(Rect(120, 226, 250, 243), Pt) then
      UrlClick('http://dsoft1961.narod.ru')
    else if PtInRect(Rect(120, 244, 250, 259), Pt) then
      UrlClick('mailto:dsoft1961@yandex.ru');
    Exit;
  end;

  if (MouseEnabled) then
  begin
    if ((pt.x >= OffsLeft) and (pt.x < BlockSize * 4 + OffsLeft) and 
	(pt.y >= OffsTop)  and (pt.y < BlockSize * 4 + OffsTop)) then
    begin
      if (isMoving) or (fOption) then
	Exit;
      X := ((pt.x - OffsLeft) div BlockSize);
      Y := ((pt.y - OffsTop)  div BlockSize);    
      flag := False;
      OffsX := 0;
      OffsY := 0;
      if (((X - 1) >= 0) and (Displ[Y][X - 1] = 0)) then
      begin
	DestX := X - 1;
	DestY := Y;
	OffsX := -Step;
	flag := True;
      end;
      if (((Y - 1) >= 0) and (Displ[Y - 1][X] = 0)) then
      begin
	DestX := X;
	DestY := Y - 1;
	OffsY := -Step;
	flag := True;
      end;
      if (((X + 1) <= 3) and (Displ[Y][X + 1] = 0)) then
      begin
	DestX := X + 1;
	DestY := Y;
	OffsX := Step;
	flag := True;
      end;
      if (((Y + 1) <= 3) and (Displ[Y + 1][X] = 0)) then
      begin
	DestX := X;
	DestY := Y + 1;
	OffsY := Step;
	flag := True;
      end;

      if (flag) then
      begin
        PlaySnd('Ok');
	CooX := X * BlockSize + OffsLeft;
	CooY := Y * BlockSize + OffsTop;
	SrcX := CooX;
	SrcY := CooY;
	isMoving := True;
	Displ[DestY][DestX] := Displ[Y][X];
	Displ[Y][X] := 0;
	UpdateMap(False);
	SetTimer(Wnd, 1, 10, NIL);
	inc(HandMove);
	if Displ[3][2] = 15 then
	begin
	  for I := 0 to 3 do
	    for J := 0 to 3 do
	      StrFinal := StrFinal + IntToStr(Displ[I][J]);
	  // Тупо, но бодро проверим на завершение ручной сборки
	  if StrFinal = '1234567891011121314150' then
	  begin
	    PlaySnd('final');
	    MessageBox(Wnd, PChar(GetMessageStep(HandMove)), 'Сообщение', MB_OK);
	    HandMove := 0;
	    IsGame := False;
	    MouseEnabled := False;
	  end;
	end
	else
	  StrFinal := '';
	Exit;
      end
      else
	PlaySnd('Error');
    end;
  end;
end;

{----------------------------------------------------------}

procedure AutoMove(Wnd : HWND);
var
  I, J	: Integer;
  X, Y  : Integer;
begin
  // проверим на завершение автоматической сборки
  if (CurMove = NIL) then
  begin
    PlaySnd('final');
    EndAutoMove(Wnd);
    MessageBox(Wnd, PChar(GetMessageStep(AllMove)), 'Сообщение', MB_OK);
    AllMove := 0;
    IsGame := False;
    Exit;
  end;

  isAutoMove := True;

  OffsX := 0;
  OffsY := 0;

  // в соответствии с вычесленным ранее алгоритмом, двигаем фишки
  for I := 0 to 3 do
    for J := 0 to 3 do
      if (Displ[I][J] = 0) then
      begin
	DestX := J;
	DestY := I;
      end;

  X := DestX;
  Y := DestY;

  if (CurMove.move = mLEFT) then
  begin
    X	  := DestX - 1;
    OffsX := 16;
  end;

  if (CurMove.move = mRIGHT) then
  begin
    X	  := DestX + 1;
    OffsX := -16;
  end;

  if (CurMove.move = mUP) then
  begin
    Y	  := DestY - 1;
    OffsY := 16;
  end;

  if (CurMove.move = mDOWN) then
  begin
    Y	  := DestY + 1;
    OffsY := -16;
  end;

  CooX := X * BlockSize + OffsLeft;	// X * 64 + 10
  CooY := Y * BlockSize + OffsTop;	// Y * 64 + 10
  SrcX := CooX;
  SrcY := CooY;
  CurMove := CurMove.next;
  flag := True;

  Displ[DestY][DestX] := Displ[Y][X];
  Displ[Y][X] := 0;
  UpdateMap(False);   
  SetTimer(Wnd, 1, 10, NIL);
end;

{----------------------------------------------------------}

procedure OnTimer(ID : Longint; Wnd : HWND);
var
  DC		: HDC;
  memDC		: HDC;
  OldBmp	: HBITMAP;
  aRect		: TRect;
begin
  if ID = 2 then
  begin
    if isAutoMove then
      Exit;
    if (isGoMove) then
      AutoMove(Wnd);
    Exit;
  end;
  
  inc(CooX, OffsX);
  inc(CooY, OffsY);

  DC := GetDC(Wnd);
  memDC := CreateCompatibleDC(DC);
  try
    OldBmp := SelectObject(memDC, m_bmptemp);
    BitBlt(ScreenDC, SrcX, SrcY, BlockSize, BlockSize, memDC, SrcX, SrcY, SRCCOPY);
    BitBlt(ScreenDC, DestX * BlockSize + OffsLeft, DestY * BlockSize + OffsTop, BlockSize, BlockSize, memDC, DestX * BlockSize + OffsLeft, DestY * BlockSize + OffsTop, SRCCOPY);
    SelectObject(memDC, OldBmp);

    // рисуем прозрачно сдвигаемый блок
    TransparentBmp(ScreenDC, m_bmp[Displ[DestY][DestX]], CooX, CooY);

    if ((CooX = DestX * BlockSize + OffsLeft) and (CooY = DestY * BlockSize + OffsTop)) then
    begin
      KillTimer(Wnd, 1);
      flag       := False;
      isMoving   := False;
      isAutoMove := False;
    end;
    SetRect(aRect, OffsLeft, OffsTop, 4 * BlockSize + OffsLeft, 4 * BlockSize + OffsTop);
    InvalidateRect(Wnd, @aRect, False);
  finally
    DeleteDC(memDC);
    ReleaseDC(Wnd, DC);
  end;
end;

{----------------------------------------------------------}

procedure ChangeCursor(Wnd : HWND; Pt : TPoint);
var
  X, Y	: Integer;

begin
  // меняем вид курсора
  if (isMoving) or (fOption) or (not MouseEnabled) then
  begin
    SetCursor(LoadCursor(0, IDC_ARROW));
    Exit;
  end;

  if (fAbout) then
  begin
    if PtInRect(Rect(120, 226, 250, 243), Pt) or 
       PtInRect(Rect(120, 244, 250, 259), Pt) then
      SetCursor(hand)
    else
      SetCursor(LoadCursor(0, IDC_ARROW));
    Exit;
  end;

  if ((pt.x >= OffsLeft) and (pt.x < BlockSize * 4 + OffsLeft) and 
      (pt.y >= OffsTop)  and (pt.y < BlockSize * 4 + OffsTop)) then
  begin
    X := ((pt.x - OffsLeft) div BlockSize);
    Y := ((pt.y - OffsTop)  div BlockSize);    
    if Displ[Y][X] <> 0 then
      if (((X - 1) >= 0) and (Displ[Y][X - 1] = 0)) or
         (((Y - 1) >= 0) and (Displ[Y - 1][X] = 0)) or
         (((X + 1) <= 3) and (Displ[Y][X + 1] = 0)) or
         (((Y + 1) <= 3) and (Displ[Y + 1][X] = 0)) then
        SetCursor(arrow)
      else
        SetCursor(none)
    else
      SetCursor(LoadCursor(0, IDC_ARROW));
  end
  else
    SetCursor(LoadCursor(0, IDC_ARROW));
end;

{----------------------------------------------------------}

procedure LoadBlock(Wnd : HWND; var bmp : HBITMAP; I : Integer);
var
  tmp		: HBITMAP;
  DC		: HDC;
  memDC		: HDC;
  tmpDC		: HDC;
begin
  // загрузка битмапов из ресурса
  bmp := LoadBmpFromRes('bmChip');
  tmp := LoadBmpFromRes('bmNumber');
  DC := GetDC(Wnd);
  memDC := CreateCompatibleDC(DC);
  tmpDC := CreateCompatibleDC(DC);
  SelectObject(memDC, bmp);
  SelectObject(tmpDC, tmp);
  BitBlt(memDC, 15, 13, 34, 38, tmpDC, pred(I) * 34, 0, SRCCOPY);
  DeleteObject(tmp);
  DeleteDC(memDC);
  DeleteDC(tmpDC);
  ReleaseDC(Wnd, DC);
end;

{----------------------------------------------------------}

procedure InitApp(Wnd : HWND);
var
  I	: Integer;
begin
  // инициализация всего и вся
  CreateToolTip(Wnd);
  hHook := SetWindowsHookEx(WH_GETMESSAGE, @HookProc, 0, GetCurrentThreadID);
  MouseEnabled := True;

  Home := TToolTip.Create(Wnd);
  Mail := TToolTip.Create(Wnd);
  Home.AddHintRect(Rect(120, 226, 250, 243), 'Домашняя страничка.');
  Home.AddHintRect(Rect(120, 244, 250, 259), 'Написать письмо.');

  // загрузка курсоров
  hand  := LoadCursor(hInstance, 'handpt');
  arrow := LoadCursor(hInstance, 'arrow');
  none  := LoadCursor(hInstance, 'none');

  m_bmp[0] := 0;
  for I := 1 to 15 do
    LoadBlock(Wnd, m_bmp[I], I);

  m_bmpmain  := LoadBmpFromRes('bmMain');
  m_bmptemp  := LoadBmpFromRes('bmMain');
  m_bmppause := LoadBmpFromRes('bmPause');
  m_bmpinact := LoadBmpFromRes('bmInact');
  m_bmpabout := LoadBmpFromRes('bmAbout');
  m_bmptitle := LoadBmpFromRes('bmtitle');

  m_clDC  := GetDC(Wnd);
  ScreenDC := CreateCompatibleDC(m_clDC);
  SelectObject(ScreenDC, m_bmpmain);

  m_temp   := CreateBmp(ScreenDC, 70, 30);
  m_tempdc := CreateCompatibleDC(ScreenDC);
  SelectObject(m_tempdc, m_temp);
  
  // Создать кнопки
  //----------------------------
  btNew := TButton.Create(277, 100, 66, 32, Wnd, 'Новая игра');
  with btNew do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btNew',  0,  0, 66, 32);
    SplitBitmap(Wnd, bmBmp2,  'btNew',  0, 32, 66, 32);
    SplitBitmap(Wnd, bmMask1, 'btMono', 0,  0, 66, 32);
    SplitBitmap(Wnd, bmMask2, 'btMono', 0, 32, 66, 32);
    CanvasSrc := ScreenDC;
    Visible := True;
  end;

  btSolve := TButton.Create(277, 135, 66, 32, Wnd, 'Решает компьютер');
  with btSolve do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btSolve', 0,  0, 66, 32);
    SplitBitmap(Wnd, bmBmp2,  'btSolve', 0, 32, 66, 32);
    SplitBitmap(Wnd, bmMask1, 'btMono',  0,  0, 66, 32);
    SplitBitmap(Wnd, bmMask2, 'btMono',  0, 32, 66, 32);
    CanvasSrc := ScreenDC;
    Visible := True;
  end;

  btOption := TButton.Create(277, 170, 66, 32, Wnd, 'Настройки');
  with btOption do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btOption', 0,  0, 66, 32);
    SplitBitmap(Wnd, bmBmp2,  'btOption', 0, 32, 66, 32);
    SplitBitmap(Wnd, bmMask1, 'btMono',   0,  0, 66, 32);
    SplitBitmap(Wnd, bmMask2, 'btMono',   0, 32, 66, 32);
    CanvasSrc := ScreenDC;
    Visible := True;
  end;

  btExit := TButton.Create(277, 205, 66, 32, Wnd, 'Выход из игры');
  with btExit do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btExit', 0,  0, 66, 32);
    SplitBitmap(Wnd, bmBmp2,  'btExit', 0, 32, 66, 32);
    SplitBitmap(Wnd, bmMask1, 'btMono', 0,  0, 66, 32);
    SplitBitmap(Wnd, bmMask2, 'btMono', 0, 32, 66, 32);
    CanvasSrc := ScreenDC;
    Visible := True;
  end;

  btSound := TButton.Create(30, 80, 22, 22, Wnd, 'Включить/выключить звук');
  with btSound do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btCheck',  0,  0, 22, 22);
    SplitBitmap(Wnd, bmBmp2,  'btCheck',  0, 22, 22, 22);
    SplitBitmap(Wnd, bmMask1, 'btCheckm', 0,  0, 22, 22);
    SplitBitmap(Wnd, bmMask2, 'btCheckm', 0, 22, 22, 22);
    CanvasSrc := ScreenDC;
    if fSound then Caption := '+'
    else Caption := '';
    Visible := False;
  end;
  
  for I := 0 to 4 do
  begin
    btStep[I] := TButton.Create(30 * I + 30, 130, 22, 22, Wnd, 'Шаг сдвига блока');
    with btStep[I] do
    begin
      SplitBitmap(Wnd, bmBmp1,  'btCheck',  0,  0, 22, 22);
      SplitBitmap(Wnd, bmBmp2,  'btCheck',  0, 22, 22, 22);
      SplitBitmap(Wnd, bmMask1, 'btCheckm', 0,  0, 22, 22);
      SplitBitmap(Wnd, bmMask2, 'btCheckm', 0, 22, 22, 22);
      CanvasSrc := ScreenDC;
      Caption := FloatToStr(Power(2, I), 1, 0);
      Visible := False;
    end;
  end;
  
  btOk := TButton.Create(30, 230, 64, 22, Wnd, '');
  with btOK do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btOk',  0,  0, 64, 22);
    SplitBitmap(Wnd, bmBmp2,  'btOk',  0, 22, 64, 22);
    SplitBitmap(Wnd, bmMask1, 'btOkm', 0,  0, 64, 22);
    SplitBitmap(Wnd, bmMask2, 'btOkm', 0, 22, 64, 22);
    CanvasSrc := ScreenDC;
    Caption := 'OK';
    Visible := False;
  end;

  btCancel := TButton.Create(107, 230, 64, 22, Wnd, 'Отказ от изменений');
  with btCancel do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btOk',  0,  0, 64, 22);
    SplitBitmap(Wnd, bmBmp2,  'btOk',  0, 22, 64, 22);
    SplitBitmap(Wnd, bmMask1, 'btOkm', 0,  0, 64, 22);
    SplitBitmap(Wnd, bmMask2, 'btOkm', 0, 22, 64, 22);
    CanvasSrc := ScreenDC;
    Caption := 'Отмена';
    Visible := False;
  end;

  btAbout := TButton.Create(184, 230, 64, 22, Wnd, 'О программе...');
  with btAbout do
  begin
    SplitBitmap(Wnd, bmBmp1,  'btOk',  0,  0, 64, 22);
    SplitBitmap(Wnd, bmBmp2,  'btOk',  0, 22, 64, 22);
    SplitBitmap(Wnd, bmMask1, 'btOkm', 0,  0, 64, 22);
    SplitBitmap(Wnd, bmMask2, 'btOkm', 0, 22, 64, 22);
    CanvasSrc := ScreenDC;
    Caption := 'Автора';
    Visible := False;
  end;

  // Initialize Random generator
  Randomize;
  Initialize;
  UpdateMap(True);

  DrawPhase(Wnd);
end;

{----------------------------------------------------------}

procedure DeInitApp(Wnd : HWND);
var
  I	: Integer;
begin
  // перед выходом освободим все ресурсы
  if (isGoMove) then
    EndAutoMove(Wnd);

  DestroyWindow(hToolTip);
  Home.Free;
  Mail.Free;
  
  // удалить курсоры
  DestroyCursor(hand);
  DestroyCursor(arrow);
  DestroyCursor(none);
  
  // Освободим битмапы
  // ---------------------------
  for I := 1 to 15 do
    DeleteObject(m_bmp[I]);

  DeleteObject(m_bmpmain);
  DeleteObject(m_bmptemp);
  DeleteObject(m_bmppause);
  DeleteObject(m_bmpinact);
  DeleteObject(m_bmptitle);
  DeleteObject(m_bmpabout);

  // Удалить кнопки
  // ---------------------------
  btNew.Free;
  btSolve.Free;
  btOption.Free;
  btExit.Free;
  btSound.Free;
  btOk.Free;
  btCancel.Free;
  btAbout.Free;

  for I := 0 to 4 do
    btStep[I].Free;

  // Удалить оконный битмап
  // ---------------------------
  DeleteObject(m_temp);
  DeleteDC(m_tempdc);

  DeleteDC(ScreenDC);
  ReleaseDC(Wnd, m_clDC);
end;

{----------------------------------------------------------}

function WindowProc(Wnd : HWnd; Msg, WParam : Word;
		    LParam : LongInt) : LongInt; stdcall;
var
  ps		: TPaintStruct;
  pt		: TPoint;
  MainRect,
  aRect		: TRect;
  idBtn		: TButton;
begin
  WindowProc := 0;
  case Msg of
    WM_CREATE :
    begin
      InitApp(Wnd);
    end;

    WM_NCACTIVATE :
    begin
      AppActive := Boolean(wParam);
      OldActive := not AppActive;
      DrawPhase(Wnd);
    end;

    WM_NCHITTEST:
    begin
      Result := htClient;
      pt.x := LoWord(lParam);
      pt.y := HiWord(lParam);
      ScreenToClient(Wnd, pt);
      GetClientRect(Wnd, MainRect);
      SetRect(aRect, OffsLeft, OffsTop, BlockSize * 4 + OffsLeft, BlockSize * 4 + OffsTop);
      if PtInRect(MainRect, pt) and not PtInRect(aRect, Pt) then
	Result := htCaption;
      Exit;
    end;

    WM_SETCURSOR :
    begin
      GetCursorPos(Pt);
      ScreenToClient(Wnd, Pt);
      ChangeCursor(Wnd, Pt);
      Exit;
    end;
    
    WM_LBUTTONDOWN :
    begin
      Pt.x := LOWORD(lParam);
      Pt.y := HIWORD(lParam);
      OnLButtonDown(Wnd, Pt);
    end;

    WM_PAINT :
    begin
      BeginPaint(Wnd, ps);
      BitBlt(ps.hdc, 0, 0, SizeX, SizeY, ScreenDC, 0, 0, SRCCOPY);
      EndPaint(Wnd, ps);
    end;

    WM_TIMER :
    begin
      OnTimer(wParam, Wnd);
    end;

    WM_KEYDOWN:
    begin
      case (LOWORD(wParam)) of
        VK_F1	: SendMessage(Wnd, WM_COMMAND, 0, btAbout.Handle);
        VK_F2	: NewGame(Wnd);
        VK_F3	: SolveGame(Wnd);
        VK_F9	: OptionGame(Wnd);
        VK_ESCAPE : 
          if fOption then OptionGame(Wnd)
          else if fAbout then AboutGame(Wnd)
          else if isGoMove then SolveGame(Wnd);
        VK_RETURN : SendMessage(Wnd, WM_COMMAND, 0, btOk.Handle);
      end;
    end;

    WM_COMMAND :
    begin
      if LoWord(wParam) = 0 then
      begin
	idBtn := TButton(GetWindowLong(lParam, GWL_USERDATA));
	OnButtonClick(Wnd, idBtn);
      end;
    end;

    WM_DESTROY :
    begin
      DeInitApp(Wnd);

      GetWindowRect(Wnd, MainRect);
      XPos := MainRect.Left;
      YPos := MainRect.Top;
      WriteRegistryInfo;

      PostQuitMessage(0);
      Exit;
    end;
  end;
  WindowProc := DefWindowProc(Wnd, Msg, WParam, LParam);
end;

{----------------------------------------------------------}

procedure WinMain;
var
  R	: TRect;
begin
  Window := FindWindow(AppName, NIL);
  if Window <> 0 then
  begin
    if IsIconic(Window) then
      ShowWindow(Window, SW_RESTORE);
    SetForegroundWindow(Window);
    Halt(254);
  end;

  CXSCREEN := GetSystemMetrics(SM_CXSCREEN);
  CYSCREEN := GetSystemMetrics(SM_CYSCREEN);

  aBIcon := LoadIcon(hInstance, 'icoMain');
  aSIcon := LoadImage(hInstance, 'icoMain', IMAGE_ICON, 16, 16, 0);

  WClass.cbSize		:= SizeOf(WClass);
  WClass.style		:= CS_HREDRAW or CS_VREDRAW;
  WClass.lpfnWndProc	:= @WindowProc;
  WClass.cbClsExtra	:= 0;
  WClass.cbWndExtra	:= 0;
  WClass.hInstance	:= hInstance;
  WClass.hIcon		:= aBIcon;
  WClass.hCursor	:= LoadCursor(0, IDC_ARROW);
  WClass.hbrBackground	:= COLOR_WINDOW + 1;//GetStockObject(LTGRAY_BRUSH);
  WClass.lpszMenuName	:= '';
  WClass.lpszClassName	:= AppName;
  WClass.hIconSm	:= aSIcon;

  if RegisterClassEx(WClass) = 0 then
    Halt(255);

  ReadRegistryInfo;

  Window := CreateWindow(AppName, 'Пятнашки',
			 WS_POPUP or WS_SYSMENU or WS_MINIMIZEBOX,
			 0, 0, SizeX, SizeY,
			 0, 0, hInstance, NIL);

  SetRectEmpty(R);
  GetWindowRect(FindWindow('Shell_TrayWnd', Nil), R);

  if XPos < 0 then XPos := 0;
  if YPos < 0 then YPos := 0;
  if XPos + SizeX > CXSCREEN then
     XPos := CXSCREEN - SizeX;
  if YPos + SizeY > CYSCREEN - (R.Bottom - R.Top) then
     YPos := CYSCREEN - (R.Bottom - R.Top) - SizeY;
  SetWindowPos(Window, 0, XPos, YPos, 0, 0, SWP_NOSIZE or SWP_NOACTIVATE);

  ShowWindow(Window, CmdShow);
  UpdateWindow(Window);

  while GetMessage(Msg, 0, 0, 0) do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
  DestroyIcon(aSIcon);
  DestroyIcon(aBIcon);
  Halt(Msg.wParam);
end;

begin
  WinMain;
end.

