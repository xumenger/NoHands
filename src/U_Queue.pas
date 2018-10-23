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
      //Attention: Delphi��ֱ���ͷ�Pointer�����ָ��ָ��Ľṹ���а���string�ӱ����ᵼ��Disposeʱ�ڴ�й©
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
