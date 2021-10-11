unit Streams;

{$R-}

interface

uses
  Windows;

{$I Common.inc}

const

{ TStream seek origins }
  soFromBeginning = 0;
  soFromCurrent = 1;
  soFromEnd = 2;

type
  TStream	= class(TObject)
  private
    function  GetPosition: Longint;
    procedure SetPosition(Pos: Longint);
    function  GetSize: Longint;
  protected
    procedure SetSize(NewSize: Longint); virtual;
  public
    function  Read(var Buffer; Count: Longint): Longint; virtual; abstract;
    function  Write(const Buffer; Count: Longint): Longint; virtual; abstract;
    function  Seek(Offset: Longint; Origin: Word): Longint; virtual; abstract;
    procedure ReadBuffer(var Buffer; Count: Longint);
    procedure WriteBuffer(const Buffer; Count: Longint);
    function  CopyFrom(Source: TStream; Count: Longint): Longint;
    property  Position: Longint read GetPosition write SetPosition;
    property  Size: Longint read GetSize write SetSize;
  end;

{ TCustomMemoryStream abstract class }

  TCustomMemoryStream = class(TStream)
  private
    fMemory	: Pointer;
    fSize,
    fPosition	: Longint;
  protected
    procedure SetPointer(Ptr: Pointer; Size: Longint);
  public
    function  Read(var Buffer; Count: Longint): Longint; override;
    function  Seek(Offset: Longint; Origin: Word): Longint; override;
    procedure SaveToStream(Stream: TStream);
    property  Memory: Pointer read fMemory;
  end;

{ TMemoryStream }

  TMemoryStream = class(TCustomMemoryStream)
  private
    fCapacity	: Longint;
    procedure  SetCapacity(NewCapacity: Longint);
  protected
    function   Realloc(var NewCapacity: Longint): Pointer; virtual;
    property   Capacity: Longint read FCapacity write SetCapacity;
  public
    destructor Destroy; override;
    procedure  Clear;
    procedure  LoadFromStream(Stream: TStream);
    procedure  SetSize(NewSize: Longint); override;
    function   Write(const Buffer; Count: Longint): Longint; override;
  end;


implementation

{===========================================================}

{ TStream }

function TStream.GetPosition: Longint;
begin
  Result := Seek(0, 1);
end;

procedure TStream.SetPosition(Pos: Longint);
begin
  Seek(Pos, 0);
end;

function TStream.GetSize: Longint;
var
  Pos: Longint;
begin
  Pos := Seek(0, 1);
  Result := Seek(0, 2);
  Seek(Pos, 0);
end;

procedure TStream.SetSize(NewSize: Longint);
begin
end;

procedure TStream.ReadBuffer(var Buffer; Count: Longint);
begin
  Read(Buffer, Count);
end;

procedure TStream.WriteBuffer(const Buffer; Count: Longint);
begin
  Write(Buffer, Count);
end;

function TStream.CopyFrom(Source: TStream; Count: Longint): Longint;
const
  MaxBufSize = $F000;
var
  BufSize,
  N		: Integer;
  Buffer	: PChar;
begin
  if Count = 0 then
  begin
    Source.Position := 0;
    Count := Source.Size;
  end;
  Result := Count;
  if Count > MaxBufSize then
    BufSize := MaxBufSize
  else
    BufSize := Count;
  GetMem(Buffer, BufSize);
  try
    while Count <> 0 do
    begin
      if Count > BufSize then
        N := BufSize
      else
        N := Count;
      Source.ReadBuffer(Buffer^, N);
      WriteBuffer(Buffer^, N);
      Dec(Count, N);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

{ TCustomMemoryStream }

procedure TCustomMemoryStream.SetPointer(Ptr: Pointer; Size: Longint);
begin
  FMemory := Ptr;
  FSize := Size;
end;

function TCustomMemoryStream.Read(var Buffer; Count: Longint): Longint;
begin
  if (FPosition >= 0) and (Count >= 0) then
  begin
    Result := FSize - FPosition;
    if Result > 0 then
    begin
      if Result > Count then Result := Count;
      Move(Pointer(Longint(FMemory) + FPosition)^, Buffer, Result);
      Inc(FPosition, Result);
      Exit;
    end;
  end;
  Result := 0;
end;

function TCustomMemoryStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  case Origin of
    0: FPosition := Offset;
    1: Inc(FPosition, Offset);
    2: FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

procedure TCustomMemoryStream.SaveToStream(Stream: TStream);
begin
  if FSize <> 0 then Stream.WriteBuffer(FMemory^, FSize);
end;

{ TMemoryStream }

const
  MemoryDelta = $2000; { Must be a power of 2 }

destructor TMemoryStream.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TMemoryStream.Clear;
begin
  SetCapacity(0);
  FSize := 0;
  FPosition := 0;
end;

procedure TMemoryStream.LoadFromStream(Stream: TStream);
var
  Count: Longint;
begin
  Stream.Position := 0;
  Count := Stream.Size;
  SetSize(Count);
  if Count <> 0 then
    Stream.ReadBuffer(FMemory^, Count);
end;

procedure TMemoryStream.SetCapacity(NewCapacity: Longint);
begin
  SetPointer(Realloc(NewCapacity), FSize);
  FCapacity := NewCapacity;
end;

procedure TMemoryStream.SetSize(NewSize: Longint);
begin
  if FPosition > NewSize then
    Seek(0, soFromEnd);
  SetCapacity(NewSize);
  FSize := NewSize;
end;

function TMemoryStream.Realloc(var NewCapacity: Longint): Pointer;
begin
  if NewCapacity > 0 then
    NewCapacity := (NewCapacity + (MemoryDelta - 1)) and not (MemoryDelta - 1);
  Result := Memory;
  if NewCapacity <> FCapacity then
  begin
    if NewCapacity = 0 then
    begin
      GlobalFreePtr(Memory);
      Result := nil;
    end
    else
    begin
      if Capacity = 0 then
        Result := GlobalAllocPtr(HeapAllocFlags, NewCapacity)
      else
        Result := GlobalReallocPtr(Memory, NewCapacity, HeapAllocFlags);
    end;
  end;
end;

function TMemoryStream.Write(const Buffer; Count: Longint): Longint;
var
  Pos: Longint;
begin
  if (FPosition >= 0) and (Count >= 0) then
  begin
    Pos := FPosition + Count;
    if Pos > 0 then
    begin
      if Pos > FSize then
      begin
        if Pos > FCapacity then
          SetCapacity(Pos);
        FSize := Pos;
      end;
      System.Move(Buffer, Pointer(Longint(FMemory) + FPosition)^, Count);
      FPosition := Pos;
      Result := Count;
      Exit;
    end;
  end;
  Result := 0;
end;

end.
