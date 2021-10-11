
{$IFDEF VER100} { Borland Delphi 3.0 }
  {$DEFINE D3}
{$ENDIF}
{$IFDEF VER120} { Borland Delphi 4.0 }
  {$DEFINE D3}
  {$DEFINE D4}
{$ENDIF}
{$IFDEF VER130} { Borland Delphi 5.0 }
  {$DEFINE D3}
  {$DEFINE D4}
  {$DEFINE D5}
{$ENDIF}
{$IFDEF VER140} { Borland Delphi 6.0 }
  {$DEFINE D3}
  {$DEFINE D4}
  {$DEFINE D5}
  {$DEFINE D6}
{$ENDIF}
{$IFDEF VER150} { Borland Delphi 7.0 }
  {$DEFINE D3}
  {$DEFINE D4}
  {$DEFINE D5}
  {$DEFINE D6}
  {$DEFINE D7}
{$ENDIF}
{$IFDEF VER180} { Borland Delphi 2006 }
  {$DEFINE D3}
  {$DEFINE D4}
  {$DEFINE D5}
  {$DEFINE D6}
  {$DEFINE D7}
  {$DEFINE D10}
{$ENDIF}
{$IFDEF VER200} { Borland Delphi 2009 }
  {$DEFINE D3}
  {$DEFINE D4}
  {$DEFINE D5}
  {$DEFINE D6}
  {$DEFINE D7}
  {$DEFINE D10}
  {$DEFINE D2009}
{$ENDIF}

{$IFDEF D7}
  {$WARN SYMBOL_PLATFORM OFF}
  {$WARN UNSAFE_TYPE OFF}
  {$WARN UNSAFE_CODE OFF}

// These flags requires library DbgHelp.dll on Windows NT 4.0 
// and Windows 95/98/Me.
  {$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED or
               IMAGE_FILE_DEBUG_STRIPPED or
               IMAGE_FILE_LINE_NUMS_STRIPPED or
               IMAGE_FILE_LOCAL_SYMS_STRIPPED or
               IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP or
               IMAGE_FILE_NET_RUN_FROM_SWAP}
{$ENDIF}

{$IFDEF D2009}
  {$WARN IMPLICIT_STRING_CAST OFF}
  {$WARN IMPLICIT_STRING_CAST_LOSS OFF}
{$ENDIF}
