unit Solv;

interface

const
  mLEFT		= 0;
  mRIGHT	= 2;
  mUP		= 1;
  mDOWN		= 3;

type
  PMoves = ^tMoves;
  TMoves = packed record
    move	: Byte; 	// Move: 0 - Сдвиг влево
				//	 1 - Сдвиг вверх
				//	 2 - Сдвиг вправо
				//       3 - Сдвиг вниз
    next	: PMoves;	// Следующий сдвиг
  end;

var
  LastNumber	: Integer;
  AllMove	: Integer;

function  GetMoves : PMoves;
function  Solve(var SetOfNum) : Boolean;


implementation

var
  NumberArray	: array[0..3, 0..3] of Byte;	// Массив цифр на доске
  MoveMatrix	: array[0..3, 0..3] of Byte;
  Fmove		: PMoves = NIL;
  Cmove		: PMoves = NIL;			// Первый и текущий сдвиги

  tPosX,
  tPosY		: Byte;				// Space target Position X and Y
  TempPathBest	: array[0..15] of Byte;
  TotalStep	: Integer;

  TempPath,					// Временный путь
  TempPathX, 
  TempPathY	: array[0..15] of Byte;

function GetMoves : PMoves;
begin
  Result := Fmove;
end;

procedure MoveAndSave(sMove : Byte; var xpt, ypt : Byte);
//-----------------------------------------------------
// Эта процедура делает сдвиг и сохраняет в базе данных
// xp, yp  -  Space coordinates
//-----------------------------------------------------
var
  tempm	: PMoves;
begin	
  // First we do this move
  if (sMove = mLEFT) then
  begin
    NumberArray[ypt, xpt] := NumberArray[ypt, xpt - 1];
    NumberArray[ypt, xpt - 1] := 0;
    dec(xpt);
  end;
  if (sMove = mRIGHT) then
  begin
    NumberArray[ypt, xpt] := NumberArray[ypt, xpt + 1];
    NumberArray[ypt, xpt + 1] := 0;
    inc(xpt);
  end;
  if (sMove = mUP) then
  begin
    NumberArray[ypt, xpt] := NumberArray[ypt - 1, xpt];
    NumberArray[ypt - 1, xpt] := 0;
    dec(ypt);
  end;
  if (sMove = mDOWN) then
  begin
    NumberArray[ypt, xpt] := NumberArray[ypt + 1, xpt];
    NumberArray[ypt + 1, xpt] := 0;
    inc(ypt);
  end;
	
  // This block saving move in database
  if (Fmove = NIL) then
  begin
    new(Fmove);
    inc(AllMove);
    Cmove := Fmove;
  end
  else
  begin
    new(tempm);
    inc(AllMove);
    Cmove^.next := tempm;
    Cmove := tempm;
  end;

  Cmove^.next := NIL;
  Cmove^.move := sMove;
end;

procedure MoveAndSave4(sm1, sm2, sm3, sm4 : Byte; var xpt, ypt : Byte);
begin
  MoveAndSave(sm1, xpt, ypt);
  MoveAndSave(sm2, xpt, ypt);
  MoveAndSave(sm3, xpt, ypt);
  MoveAndSave(sm4, xpt, ypt);
end;

procedure RecalculatePositions(c : Byte; var xc, yc, xp, yp : Byte);
var
  I, J	: Integer;
begin
  for I := 0 to 3 do
  begin
    for J := 0 to 3 do
    begin
      if (NumberArray[I][J] = c) then
      begin
	xc := J;
	yc := I;
      end;
      if (NumberArray[I][J] = 0) then
      begin
	xp := J;
	yp := I;
      end;
    end;
  end;
end;

function byli(Step : Integer; cx, cy : Byte) : Boolean;
var
  I	: Integer;
begin
  Result := False;
  for I := 0 to pred(Step) do
  begin
   if ((TempPathX[I] = cx) and (TempPathY[I] = cy)) then
     Result := True;
  end;
end;

procedure FindShortPath(spX, spY : Byte; Step : Integer; lmX, lmY : Byte);
var
  I	: Integer;
begin
  // spX, spY - current space position
  // lmX, lmY - last space position

  TempPathX[Step] := spX;
  TempPathY[Step] := spY;

  if ((spX = tPosX) and (spY = tPosY)) then
  begin
    if (Step < TotalStep) then
    begin
      for I := 0 to pred(Step) do
	TempPathBest[I] := TempPath[I];
      TotalStep := Step;
    end;
    Exit;
  end;

  if (spX > 0) then
    if ((moveMatrix[spY][spX - 1] = 0) and not (((spX - 1) = lmX) and (spY = lmY))) then
    begin
      if (not byli(Step, spX - 1, spY)) then
      begin
	TempPath[Step] := mLEFT;
	(FindShortPath(spX - 1, spY, (Step + 1), spX, spY));
      end;
    end;

  if (spX < 3) then
    if ((moveMatrix[spY][spX + 1] = 0) and not (((spX + 1) = lmX) and (spY = lmY))) then
    begin
      if (not byli(Step, spX + 1, spY)) then
      begin
	TempPath[Step] := mRIGHT;
	(FindShortPath(spX + 1, spY, (Step + 1), spX, spY));
      end;
    end;

  if (spY > 0) then
    if ((moveMatrix[spY - 1][spX] = 0) and not (((spX) = lmX) and ((spY - 1) = lmY))) then
    begin
      if (not byli(Step, spX, spY - 1)) then
      begin
	TempPath[Step] := mUP;
	(FindShortPath(spX, spY - 1, (Step + 1), spX, spY));
      end;
    end;

  if (spY < 3) then
    if ((moveMatrix[spY + 1][spX] = 0) and not (((spX) = lmX) and ((spY + 1) = lmY))) then
    begin
      if (not byli(Step, spX, spY + 1)) then
      begin
	TempPath[Step] := mDOWN;
	(FindShortPath(spX, spY + 1, (Step + 1), spX, spY));
      end;
    end;
end;

//-------------------------

procedure Part1(c : Byte);
var
  xp, yp	: Byte;	// Space coordinates
  xc, yc	: Byte;	// Number coordinates
  I, J		: Integer;
  variant	: Integer;
  WhereMove	: Byte;
begin
  // First we find the space and number positions
	
  RecalculatePositions(c, xc, yc, xp, yp); 

  // Check for number 10
  if (c = 10) then
  begin
    if (yp = 2) then
      MoveAndSave(mDOWN, xp, yp);

    while (xp > 0) do
      MoveAndSave(mLEFT, xp, yp);

    RecalculatePositions(c, xc, yc, xp, yp);	

    if ((xc = 1) and (yc = 3)) then
    begin
      MoveAndSave4(mUP, mRIGHT, mDOWN, mRIGHT, xp, yp);
      MoveAndSave4(mUP, mLEFT, mLEFT, mDOWN, xp, yp);
      MoveAndSave(mRIGHT, xp, yp);
      MoveAndSave(mUP, xp, yp);	
      MoveAndSave(mRIGHT, xp, yp);
      Exit;
    end;
  end;

  // Check for number 11
  if (c = 11) then
  begin
    if (yp = 2) then
      MoveAndSave(mDOWN, xp, yp);

    while (xp > 0) do
      MoveAndSave(mLEFT, xp, yp);

    RecalculatePositions(c, xc, yc, xp, yp);	

    if (((xc = 1) and (yc = 3)) or ((xc = 2) and (yc = 3))) then
    begin
      variant := 0;
      if ((xc = 2) and (yc = 3)) then
        variant := 1;
    
      MoveAndSave(mUP, xp, yp);
      MoveAndSave(mRIGHT, xp, yp);

      if (variant = 1) then
        MoveAndSave(mRIGHT, xp, yp);

      MoveAndSave(mDOWN, xp, yp);

      if (variant = 1) then
      begin
	MoveAndSave4(mLEFT, mUP, mLEFT, mDOWN, xp, yp);
	Exit;
      end;	

      MoveAndSave4(mRIGHT, mUP, mLEFT, mLEFT, xp, yp);			
      MoveAndSave(mDOWN, xp, yp);
      Exit;
    end;
  end;

  // Check for number 12
  if (c = 12) then
  begin
    if (yp = 2) then
      MoveAndSave(mDOWN, xp, yp);

    while (xp > 0) do
      MoveAndSave(mLEFT, xp, yp);

    RecalculatePositions(c, xc, yc, xp, yp);	

    if (yc = 3) then
    begin
      variant := 0;

      if (xc = 2) then
        variant := 1;

      if (xc = 3) then
        variant := 2;

      MoveAndSave(mUP, xp, yp);
      MoveAndSave(mRIGHT, xp, yp);
      MoveAndSave(mRIGHT, xp, yp);

      if (variant = 2) then
        MoveAndSave(mRIGHT, xp, yp);

      MoveAndSave(mDOWN, xp, yp);

      if (variant = 0) then
      begin
	MoveAndSave4(mLEFT, mLEFT, mUP, mRIGHT, xp, yp);
	MoveAndSave(mRIGHT, xp, yp);
	MoveAndSave(mDOWN, xp, yp);
      end;

      if ((variant = 0) or (variant = 1)) then
      begin
	MoveAndSave(mRIGHT, xp, yp);
	MoveAndSave(mUP, xp, yp);
      end;

      MoveAndSave(mLEFT, xp, yp);

      if (variant = 2) then
        MoveAndSave(mUP, xp, yp);

      MoveAndSave(mLEFT, xp, yp);
      MoveAndSave(mLEFT, xp, yp);
      MoveAndSave(mDOWN, xp, yp);

      if ((variant = 1) or (variant = 2)) then
        Exit;

      MoveAndSave4(mRIGHT, mRIGHT, mUP, mLEFT, xp, yp);
      MoveAndSave(mLEFT, xp, yp);
      MoveAndSave(mDOWN, xp, yp);
      Exit;
    end;
  end;

  while (True) do
  begin
    RecalculatePositions(c, xc, yc, xp, yp);	
    // First we check the number position.
    // If position correct then we exit from this procedure

    if ((((c - 1) shr 2) = yc) and (((c - 1) and 3) = xc)) then
      Exit;
	
    // Check for 4 or 8
    if (((c = 4) and (xc = 3) and (yc = 1)) or 
	((c = 8) and (xc = 3) and (yc = 2))) then
    begin
      if (((c = 4) and (xp = 3) and (yp = 0)) or
	  ((c = 8) and (xp = 3) and (yp = 1))) then
      begin
	MoveAndSave(mDOWN, xp, yp);
	Exit;
      end;
	
      for I := xp downto 1 do
        MoveAndSave(mLEFT, xp, yp);

      for I := yp downto 2 do
        MoveAndSave(mUP, xp, yp);

      if (c = 4) then
        MoveAndSave(mUP, xp, yp);

      for I := 0 to 2 do
        MoveAndSave(mRIGHT, xp, yp);
		
      MoveAndSave4(mDOWN, mLEFT, mUP, mLEFT, xp, yp);		
      MoveAndSave(mLEFT, xp, yp);
      MoveAndSave(mDOWN, xp, yp);
      Exit;
    end;
	
    WhereMove := 5;

    if (((c - 1) and 3) > xc) then
      WhereMove := mRIGHT;

    if (((c - 1) and 3) < xc) then
      WhereMove := mLEFT;

    if (WhereMove = 5) then
    begin
      if (((c - 1) shr 2) < yc) then
        WhereMove := mUP;

      if (((c - 1) shr 2) > yc) then
        WhereMove := mDOWN;
    end;

    for I := 0 to 3 do
      for J := 0 to 3 do
	moveMatrix[I][J] := 0;
	
    for I := 1 to pred(c) do
      moveMatrix[((I - 1) shr 2)][((i - 1) and 3)] := 1;

    moveMatrix[yc][xc] := 1;

    tPosX := xc;
    tPosY := yc;

    if (WhereMove = mLEFT) then
      dec(tPosX);

    if (WhereMove = mRIGHT) then
      inc(tPosX);

    if (WhereMove = mUP) then
      dec(tPosY);

    if (WhereMove = mDOWN) then
      inc(tPosY);

    TotalStep := 1000;
    FindShortPath(xp, yp, 0, xp, yp);
	
    for I := 0 to pred(TotalStep) do
      MoveAndSave(TempPathBest[I], xp, yp);

    if (WhereMove = mLEFT) then
      MoveAndSave(mRIGHT, xp, yp);

    if (WhereMove = mRIGHT) then
      MoveAndSave(mLEFT, xp, yp);

    if (WhereMove = mUP) then
      MoveAndSave(mDOWN, xp, yp);

    if (WhereMove = mDOWN) then
      MoveAndSave(mUP, xp, yp);
  end;
end;

//-----------------------------------

function Part2 : Boolean;
var
  TempN		: array[0..2] of Byte;
  xc, yc,
  xp, yp	: Byte;
  I, J		: Integer;
begin
  // Part Two
  // Return TRUE  - if 15 can be building
  //	    FALSE - if can not!
  Result := False;
  LastNumber := 0;
  for I := 0 to 3 do
  if (NumberArray[3][I] <> 0) then
  begin
    TempN[LastNumber] := NumberArray[3][I];
    inc(LastNumber);
  end;

  LastNumber := (TempN[0] - 10) * 100 + (TempN[1] - 10) * 10 + (TempN[2] - 10);

  RecalculatePositions(13, xc, yc, xp, yp);

  if (LastNumber = 345) then
  begin
    while (xp < 3) do
      MoveAndSave(mRIGHT, xp, yp);

    Result := True;
    Exit;
  end;

  // Эта проверка не обязательна
  if ((LastNumber = 354) or (LastNumber = 435) or (LastNumber = 543)) then
  begin
    Result := False;
    Exit;
  end;

  if (LastNumber = 453) then
  begin
    while (xp > 0) do
      MoveAndSave(mLEFT, xp, yp);

    for I := 0 to 1 do
    begin
      MoveAndSave(mUP, xp, yp);

      for J := 0 to 2 do
        MoveAndSave(mRIGHT, xp, yp);

      MoveAndSave(mDOWN, xp, yp);
      MoveAndSave(mLEFT, xp, yp);

      if (I = 0) then
      begin
	MoveAndSave(mLEFT, xp, yp); 
	MoveAndSave(mLEFT, xp, yp);
      end;
    end;

    MoveAndSave4(mUP, mLEFT, mLEFT, mDOWN, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mRIGHT, xp, yp);

    MoveAndSave(mUP, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mLEFT, xp, yp);

    MoveAndSave(mDOWN, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mRIGHT, xp, yp);

    Result := True;
    Exit;
  end;

  if (LastNumber = 534) then
  begin
    MoveAndSave(mUP, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mRIGHT, xp, yp);

    MoveAndSave(mDOWN, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mLEFT, xp, yp);

    MoveAndSave4(mUP, mRIGHT, mRIGHT, mDOWN, xp, yp);
    MoveAndSave(mRIGHT, xp, yp);
    MoveAndSave(mUP, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mLEFT, xp, yp);

    MoveAndSave(mDOWN, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mRIGHT, xp, yp);

    MoveAndSave(mUP, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mLEFT, xp, yp);

    MoveAndSave(mDOWN, xp, yp);

    for J := 0 to 2 do
      MoveAndSave(mRIGHT, xp, yp);

    Result := True;
    Exit;
  end;
end;

function Solve(var SetOfNum) : Boolean;
var
  I, J	: Integer;
  Temp	: array[0..0] of Byte absolute SetOfNum;
begin
  // Return TRUE  - if solving found
  //	    FALSE - if solving not found
  Fmove := NIL;
  AllMove := 0;
  for I := 0 to 3 do
    for J := 0 to 3 do
      NumberArray[I, J] := Temp[I * 4 + J];

  for J := 1 to 12 do
    Part1(J);

  Result := Part2;
end;

end.

