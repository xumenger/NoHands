unit U_BaseDefine;

interface
uses
  Windows, SysUtils, U_Queue;

const
  const_XmlDocument = '<?xml version="1.0" encoding="utf-8"?><Document></Document>';
  LogError = 'Error';
  const_InitFuncName = 'Init';
  const_CallFuncName = 'Call';
  const_FreeFuncName = 'Release';
  InfoNum = 9;
  InfoStr: array[1..InfoNum] of string = (
      'ProductName',
      'ProductVersion',
      'FileDescription',
      'LegalCopyright',
      'FileVersion',
      'CompanyName',
      'LegalTradeMarks',
      'InternalName',
      'OriginalFileName');

type
  //���Բ��DLL��������ָ������
  TIniFunc = function(): Integer; stdcall;
  TCallFunc = function(FunNo: PChar; InPara: PChar): PChar; stdcall;
  TFreeFunc = function(): Integer; stdcall;

  //��������Ϣ����
  TMessageType = (mtHint, mtWarning, mtError);

  //��������Ϣ
  PMessage = ^TMessage;
  TMessage = record
    MsgType: TMessageType;
    Content: string;
  end;

var
  MsgQueue: TLockQueue;

procedure AddMessage(msgType: TMessageType; StrFormat: string; const Args: array of const);
function GetProductName(FilePath: string): string;
function GetProductVersion(FilePath: string): string;
//GetFileDescription����ȡ��ִ���ļ���������Ϣ
function GetFileDescription(FilePath: string): string;
function GetLegalCopyright(FilePath: string): string;
function GetFileVersion(FilePath: string): string;
function GetCompanyName(FilePath: string): string;
function GetLegalTradeMarks(FilePath: string): string;
function GetInternalName(FilePath: string): string;
function GetOriginalFileName(FilePath: string): string;

implementation

procedure AddMessage(msgType: TMessageType; StrFormat: string; const Args: array of const);
var
  aMsg: PMessage;
begin
  New(aMsg);
  aMsg.MsgType := msgType;
  aMsg.Content := Format(StrFormat, Args);

  MsgQueue.Push(aMsg);
end;

function GetProductName(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[1]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetProductVersion(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[2]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetFileDescription(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    //���β��Ҳ�ͬ����Ϣ����
    if VerQueryValue(Buf, PChar(Find + InfoStr[3]), Pointer(Value), Len) then
    begin
      Result := Value;
    end; 

    FreeMem(Buf, BufSize);
  end;
end;

function GetLegalCopyright(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[4]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetFileVersion(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[5]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetCompanyName(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[6]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetLegalTradeMarks(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[7]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetInternalName(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[8]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

function GetOriginalFileName(FilePath: string): string;
var
  Find: string;
  BufSize, Len, LangCode: DWORD;
  Buf, Value: PChar;
  PLang: Pointer;
begin
  BufSize := GetFileVersionInfoSize(PChar(FilePath), BufSize);
  if BufSize > 0 then
  begin
    Buf := AllocMem(BufSize);
    GetFileVersionInfo(PChar(FilePath), 0, BufSize, Buf);
    //��ȡ���Դ���
    VerQueryValue(Buf, PChar('\VarFileInfo\Translation'), PLang, Len);
    LangCode := PDWORD(PLang)^;
    //���ɲ��Ҵ�
    Find := Format('StringFileInfo\%.4x%.4x\', [Word(LangCode), HiWord(LangCode)]);

    if VerQueryValue(Buf, PChar(Find + InfoStr[9]), Pointer(Value), Len) then
    begin
      Result := Value;
    end;

    FreeMem(Buf, BufSize);
  end;
end;

initialization
  MsgQueue := TLockQueue.Create;

finalization
//  MsgQueue.Clear;
//  MsgQueue.Free;


end.
