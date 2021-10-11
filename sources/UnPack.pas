UNIT UnPack;

INTERFACE

Uses
  Windows, Streams;

const
  MAXFREQ	= 2000;		{ Max frequency count before table reset }
  MINCOPY	= 3;		{ Shortest string COPYING length }
  MAXCOPY	= 64;		{ Longest string COPYING length }
  COPYRANGES	= 6;		{ Number of string COPYING distance bit ranges @@@}
  CODESPERRANGE = (MAXCOPY - MINCOPY + 1);

{ Adaptive Huffman variables }
  TERMINATE	= 256;		{ EOF code }
  FIRSTCODE	= 257;		{ First code for COPYING lengths }
  MAXCHAR	= (FIRSTCODE + COPYRANGES * CODESPERRANGE - 1);
  SUCCMAX	= (MAXCHAR + 1);
  TWICEMAX	= (2 * MAXCHAR + 1);
  ROOT		= 1;
  MAXBUF	= 4096;

var
  {** Bit packing routines **}
  Input_Bit_Count	: Word = 0;	{ Input bits buffered }
  Input_Bit_Buffer	: Word = 0;	{ Input buffer }

  InBufCount	: Integer = 0;

type
  Copy_Type	= Array[0..pred(CopyRanges)] of Integer;

const
  CopyBits	: Array[0..pred(CopyRanges)] of Integer = (4,6,8,10,12,14);   { Distance bits }
  CopyMin	: Copy_Type = (0,16,80,336,1360,5456);
  MaxSize	= 21839 + MAXCOPY;	{ @@@ }

type
  Buffer_Type	= Array[0..MaxSize] of Byte;            { Convenient typecast. }
  Buffer_Ptr	= ^Buffer_Type;

  HTree_Type	= Array[0..MaxChar] of Word;

  THTree_Type	= Array[0..TwiceMax] of Word;

  BufType	= Array[0..pred(MAXBUF)] of Byte;
  BufPtr	= ^BufType;
  WDBufType	= Array[0..pred(MAXBUF)] of Word;
  WDBufPtr	= ^WDBufType;

var
  Buffer	: Buffer_Ptr;           { Text buffer }

  LeftC, RightC : HTree_Type;  { Huffman tree }
  Parent, Freq	: THTree_Type;

  WDBuf		: WDBufPtr;
  MemInput	: TMemoryStream;
  MemOutput	: TMemoryStream;

  procedure Decompress(Name : String; var MStream : TMemoryStream);

Implementation


{***************** Compression & Decompression *****************}

{ Initialize data for compression or decompression }

Procedure Initialize;
var
  I	: Word;
begin
  { Initialize Huffman frequency tree }
  for I := 2 to TWICEMAX do
    begin
      Parent[I] := I div 2;
      Freq[I] := 1;
    end;
  for I := 1 to MAXCHAR do
    begin
      LeftC[I] := 2 * I;
      RightC[I] := 2 * I + 1;
    end;
end;

{====================================================================}

{ Update frequency counts from leaf to root }
Procedure Update_Freq(A, B : Integer);
begin
  repeat                                 
    Freq[Parent[A]] := Freq[A] + Freq[B];
    A := Parent[A];                      
    if (A <> ROOT) THEN                  
      begin                              
        if (LeftC[Parent[A]] = A) then   
          B := RightC[Parent[A]]         
        else
          B := LeftC[Parent[A]];      
      end;                               
  until A = ROOT;                        

  { Periodically scale frequencies down by half to avoid overflow }
  { This also provides some local adaption and better compression }

  if (Freq[ROOT] = MAXFREQ) then
    for A := 1 to TWICEMAX do
      Freq[A] := Freq[A] shr 1;
end;

{====================================================================}

{ Update Huffman model for each character code }
Procedure Update_Model(Code : Integer);
var
  A, B, C, Ua, Uua : Integer;

begin
  A := Code + SUCCMAX;
  INC(Freq[A]);
  if (Parent[A] <> ROOT) then
  begin
    ua := Parent[a];
    if (LeftC[ua] = a) then 
      update_freq(a, RightC[ua])
    else update_freq(a, LeftC[ua]);
    repeat
      uua := Parent[ua];
      if (LeftC[uua] = ua) then
	B := RightC[uua]
      else
	B := LeftC[uua];

      { if high Freq lower in tree, swap nodes }
      if Freq[A] > Freq[B] then
      begin
	if LeftC[Uua] = ua then
	  RightC[Uua] := A
	else 
	  LeftC[Uua] := A;
	if (LeftC[ua] = A) then
	begin
	  LeftC[Ua] := B;
	  C := RightC[ua];
	end
	else
	begin
	  RightC[Ua] := B;
	  C := LeftC[Ua];
	end;
	Parent[B] := Ua;
	Parent[A] := Uua;
	Update_Freq(B, C);
	A := B;
      end;
      A := Parent[A];
      Ua := Parent[A];
    until Ua = ROOT;
  end;
end;


{==========================================================}

procedure ShowExceptionMsg(const Fmt: PChar);
begin
  MessageBox(0, Fmt, 'Error', MB_OK or MB_ICONSTOP);
  Halt;
end;

{********************* Decompression Routines ********************}

procedure ErrorEndFile;
begin
  ShowExceptionMsg('UNEXPECTED end of File');
end;

{====================================================================}


{ Read multibit code from input file }
Function Input_Code(Bits:Integer): Word;
const
  Bit : Array[1..14] of Word = (1,2,4,8,16,32,64,128,256,512,1024,
				2048,4096,8192);
var
  I, Code, Res	: Integer;
begin
  Code := 0;
  for I := 1 to Bits do
  begin
    if (Input_Bit_Count = 0) then
    begin
      if (InBufCount = MAXBUF) then
      begin
	Res := MemInput.Read(WdBuf^, MAXBUF * 2);
	InBufCount := 0;
	if (Res = 0) then
	  ErrorEndFile;
      end;
      Input_Bit_Buffer := Wdbuf^[InBufCount];
      inc(InBufCount);
      Input_Bit_Count := 15;
    end
    else
      dec(Input_Bit_Count);
    if Input_Bit_Buffer > $7FFF then
      Code := Code or Bit[I];
    Input_Bit_Buffer := Input_Bit_Buffer shl 1;
  end;
  Result := Code;
end;

{====================================================================}

{ Uncompress a character code from input stream }
Function Uncompress: Word;
label
 top, aft, noread;
var
  Res	: Integer;
begin
  asm
	mov	ebx, 1
	mov	dx, Input_Bit_Count
	mov	cx, Input_Bit_Buffer
	mov	eax, InBufCount
Top:				{ repeat                               }
	or	dx, dx		{  if Input_Bit_Count <> 0 then        }
	jne	AFT		{    begin                             }
	cmp	eax, MAXBUF	{      if InBufCount = MAXBUF then     }
	jne	NoRead		{        begin                         }
	push	ebx
	push	ecx
	push	edx
	push	eax
  end;
  Res := MemInput.Read(WdBuf^, MAXBUF * 2);
  asm
	cmp	Res, 0
	jne	@@NoError
	jmp	ErrorEndFile
@@NoError:
	pop	eax
	pop	edx
	pop	ecx
	pop	ebx
	xor	eax, eax	{          InBufCount := 0;            }
NoRead:				{        end;                          }
	shl	eax, 1		{      Input_Bit_Buffer := InBuf^[InBufCount];}
	mov	edi, [WdBuf]
	add	edi, eax
	shr	eax, 1
	mov	cx, word ptr [edi]
	inc	eax		{      inc(InBufCount);                }
	mov	dx, $F		{      Input_Bit_Count := 15;          }
	jmp	@@Over		{    end                               }
AFT:
	dec	dx		{  else dec(Input_Bit_Count);          }
@@Over:
	mov	edi, ebx
	shl	edi, 1
	mov	bx, word ptr [edi + RightC]	{    A := RightC[A];                   }
	cmp	cx, $7FFF	{  if Input_Bit_Buffer > $7FFF then    }
	ja	@@After
	mov	bx, word ptr [edi + LeftC]	{  else A := LeftC[A];                 }
@@After:
	shl	cx, 1		{  Input_BitBuffer := Input_Bit_Buffer shl 1;}
	cmp	bx, MAXCHAR	{ until A > MAXCHAR;                   }
	jle	Top
	sub	bx, SUCCMAX	{ dec(A,SUCCMAX);                      }
	mov	Input_Bit_Count, dx
	mov	Input_Bit_Buffer, cx
	mov	InBufCount, eax
	mov	eax, ebx
	push	ebx
	call	UPDATE_MODEL	{ Model_Update(A);                     }
	pop	eax		{ Uncompress := A;                     }
	mov	Res, eax
  end;
  Result := Res;
end;

{====================================================================}
{ Decode file from input to output }

Procedure decode;
var
  I, J, Dist, Len, Index, K, T : Integer;
  N, C : Integer;
begin
  N := 0;
  InBufCount := MAXBUF;
  initialize;
  New(WDBuf);
  GetMem(Buffer, MaxSize);
  try
    if Buffer = NIL then
      ShowExceptionMsg('Недостаточно памяти');

    C := Uncompress;
    WHILE C <> TERMINATE do
    begin
      if C < 256 then
      begin
	MemOutput.Write(C, 1);
	Buffer^[N] := C;
	INC(N);
	IF (N = MaxSize) THEN
	  N := 0;
      end
      else
      begin		// else string copy length/distance codes 
	T := C - FIRSTCODE;
	Index := (T) div CODESPERRANGE;
	Len := T + MINCOPY - Index * CODESPERRANGE;
	Dist := Input_Code(CopyBits[Index]) + Len + CopyMin[Index];
	J := N;
	K := N - Dist;
	if (K < 0) then
	  inc(K, MaxSize);
	for I := 0 To pred(Len) do
	begin
	  MemOutput.Write(Buffer^[K], 1);
	  Buffer^[J] := Buffer^[K];
	  INC(J);
	  INC(K);
	  IF (J = Maxsize) THEN
	    J := 0;
	  IF (K = Maxsize) THEN
	    K := 0;
	end;
	inc(N, Len);
	if (N >= Maxsize) then
	  dec(N, MaxSize);
      end;
      C := Uncompress;
    end;
  finally
    FreeMem(buffer);
    Dispose(WdBuf);
  end;
end;

{====================================================================}

procedure Decompress(Name : String; var MStream : TMemoryStream);
var
  ResHandle	: THandle;
  MemHandle	: THandle;
  BufIn		: Pointer;
  ResSize	: Longint;	// Длина считанного ресурса 
  FileSize	: Longint;	// Оригинальная длина файла 
begin
  Input_Bit_Count  := 0;	// Input bits buffered 
  Input_Bit_Buffer := 0;	// Input buffer 

  ResHandle := FindResource(hInstance, PChar(Name), RT_RCDATA);
  if ResHandle = 0 then
    Exit;
  MemHandle := LoadResource(hInstance, ResHandle);
  ResSize   := SizeOfResource(hInstance, ResHandle);
  BufIn	    := LockResource(MemHandle);
  MemInput  := TMemoryStream.Create;
  try
    MemInput.SetSize(ResSize);
    MemInput.Write(BufIn^, ResSize);
    MemInput.Seek(3, 0);
    MemInput.Read(FileSize, SizeOf(FileSize));
    MemInput.Seek(11, 0);
    FreeResource(MemHandle);

    MemOutput := TMemoryStream.Create;
    try
      MemOutput.SetSize(FileSize);
      Decode;
      MemOutput.SaveToStream(MStream);
    finally
      MemOutput.Free;
    end;
  finally
    MemInput.Free;
  end;
end;

{====================================================================}

end.

