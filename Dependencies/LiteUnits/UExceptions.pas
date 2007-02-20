{$I-}
{checked}
unit UExceptions;

interface

type
  Exception = class(TObject)
  private
    FMessage: string;
  public
    constructor Create(const Msg: string);
    property Message: string read FMessage write FMessage;
  end;

  ExceptClass = class of Exception;

  EAbort = class(Exception);

procedure Abort;

implementation

{ Exception class }

constructor Exception.Create(const Msg: string);
begin
  FMessage := Msg;
end;

{ Raise abort exception }

procedure Abort;

  function ReturnAddr: Pointer;
  asm
          MOV     EAX,[EBP + 4]
  end;

begin
  raise EAbort.Create('Operation aborted') at ReturnAddr;
end;

end.
