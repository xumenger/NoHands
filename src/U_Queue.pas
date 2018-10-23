unit U_Queue;

interface
uses
  Windows, Math, Classes, Contnrs, SysUtils;

type
  TLockQueue = class(TQueue)
  private
    FLock: TRTLCriticalSection;
  public
    constructor Create;
    destructor Destory; overload;
    procedure Clear;
    procedure Push(pPointer: Pointer);
    function Pop: Pointer;
  end;

implementation

constructor TLockQueue.Create;
begin
  InitializeCriticalSection(FLock);
  inherited;
end;

destructor TLockQueue.Destory;
var
  pTmp: Pointer;
begin
  while Count > 0 do
  begin
    pTmp := Pop;
    if Assigned(pTmp) then
    begin
      //Attention: Delphi下直接释放Pointer，如果指针指向的结构体中包含string子变量会导致Dispose时内存泄漏
      Dispose(Pop);
    end;
  end;
  DeleteCriticalSection(FLock);
  inherited;
end;

procedure TLockQueue.Push(pPointer: Pointer);
begin
  EnterCriticalSection(FLock);
  try
    inherited Push(pPointer);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TLockQueue.Pop: Pointer;
begin
  EnterCriticalSection(FLock);
  try
    if Count > 0 then
    begin
      Result := inherited Pop
    end
    else
    begin
      Result := nil;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TLockQueue.Clear;
var
  pTmp: Pointer;
begin
  while Count > 0 do
  begin
    pTmp := Pop;
    if Assigned(pTmp) then
    begin
      Dispose(pTmp);
    end;
  end;
end;


end.
