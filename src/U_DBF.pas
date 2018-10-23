unit U_DBF;

interface

uses
  Windows, SysUtils, Dialogs, StrUtils, Controls, Messages, Classes, Forms, IniFiles;

const
  //֧�ֵ�DBF�ֶ���������(Dbf Field Variable Type)��
  DFVT_NUMERIC = 'N';     //��ֵ�����������͸���С��
  DFVT_CHAR = 'C';        //�ַ����ַ���
  DFVT_DATE = 'D';        //����
  DFVT_LOGICAL = 'L';     //�߼�(����)
  DFVT_FLOAT = 'F';       //����С������Ҫ�ṩС��λ��

  //DBF�еı�ǣ�
  DBFEOF: Byte = $1A;         //DBF�ļ�����
  HDREND: Byte = $0D;         //ͷ����
  FOXPRODBF: Byte = $03;      //FoxPro�ļ���ʶ
  SPACE: Byte = ORD(' ');     //�ո��ַ�
  DELETED: Byte = ORD('*');   //ɾ�����
  FDARSVLEN = 14;             //FDA�еı����ֽ���
  HDRRSVLEN = 20;             //HDR�еı����ֽ���

  //�ֶ�ȱʡ����:
  DEFLEN_CHAR: Integer = 15;      //�ַ���
  DEFLEN_NUMERIC: Integer = 12;   //��ֵ
  DEFLEN_DATE: Integer = 8;       //����
  DEFLEN_LOGICAL: Integer = 1;    //�߼�
  DEFLEN_FLOAT: Integer = 15;     //С���ܳ�
  DEFLEN_PREC: Integer = 4;       //С�����ֳ���

  //�ֶγ������ޣ�
  LIMLEN_CHAR: Integer = 254;
  LIMLEN_NUMERIC: Integer = 20;
  LIMLEN_DATE: Integer = 8;
  LIMLEN_LOGICAL: Integer = 1;
  LIMLEN_FLOAT: Integer = 20;

  TRY_READ_TIMES: Integer = 50;   //��ȡ���Դ���

type
  PStrings = ^TStrings;
  PStringList = ^TStringList;

  //DBF�ļ��ṹ��Ϊ���󲿷֣��ļ��ṹ˵��������������
  //�ļ��ṹ˵�����������ݿ�������ͼ�¼�ṹ���������ݿ������ռ32���ֽڣ�
  //��¼�ṹ�����������ֶβ�����ÿ���ֶ�ռ32�ֽ�

  // DBF�ļ�ͷ�ṹ
  PDBFHead = ^TDBFHead;
  TDBFHead = packed record
    Mark: Char;         //1   0+1
    Year: Byte;         //2   1+1   ��
    Month: Byte;        //3   2+1   ��
    Day: Byte;          //4   3+1   ��
    RecCount: Integer;  //8   4+4   ��¼��
    DataOffset: Word;   //10  8+2
    RecSize: Word;      //12  10+2
    Reserved: array[0..19] of Char;
  end;

  //DBF�ļ�ÿ�ֶνṹ
  PDBFField = ^TDBFField;
  TDBFField = packed record
    FieldName: array[0..10] of Char;    //�ֶ�����
    FieldType: Char;                    //�ֶ�����
    FieldOffset: Integer;
    Width: Byte;                        //�ֶο��
    Scale: Byte;                        //�ֶξ���
    Reserved: array[0..13] of Char;
  end;

  //DBF�ṹ����
  //1.�ֶ�����������(Field Descriptor Array Header)
  FDA = record
    sName: array[0..10] of AnsiChar;  //�ֶ�����[ascii field name, 0x00 termin]
    cType: AnsiChar;                  //�ֶ��������ͣ�����������[ascii field type]
    ulOffset: LongWord;               //�Ӽ�¼��ʼ��ƫ����[offset from record begin]
    btLength: Byte;                   //�ֶγ���[field length, bin]
    btDecimalCount: Byte;             //С��λ��[decimal count, bin]
    _Reserved: array[0..FDARSVLEN - 1] of Byte; //�����ֽڣ���0[reserved]
  end;
  FDAPTR = ^FDA;

  //2.���ȹ̶��ļ�¼�ṹ(Fix Each Dbf Record)
  FEDR = record
    btDeleted: Byte;    //ɾ�����[deleted flag "*" or not deleted " "]
    sData: AnsiString;  //���ݼ�¼����¼����Ϊ����FDA��fLength�ĳ���֮��(���ֶ�������)
  end;
  EDR = FEDR;
  EDRPTR = ^EDR;

  //3.�ļ�ͷ�ṹ(Header)�����ļ�ͷ��û�а���FDA���飬��Ϊ�⽫ʹ�ṹ��С����֪
  DBFHDR = record
    _btType: BYTE;                      //DBF���ͣ���0x03
    btUpdateDate: array[0..2] of BYTE;  //�޸����ڣ������ƣ�Ϊyymmdd��ʽ
    ulRecordCount: LongWord;            //��¼����
    usHeaderSize: Word;                 //�ļ�ͷ���ȣ������ļ�ͷ������־
    usRecordSize: Word;                 //������¼���ȣ��Ǹ��ֶγ���֮��(�������ݺ�ɾ����ǳ���)
    _Reserved: array[0..HDRRSVLEN - 1] of Byte; //�����ֽڣ�ȫ0
  end;
  HDR = DBFHDR;
  HDRPTR = ^HDR;

  TField = class
  private
    FDataBuf: PChar;
    FPtr: PDBFField;
    FFieldBuf: array[0..255] of Char;
  protected
    function GetAsBoolean: Boolean;
    function GetAsChar: Char;
    function GetAsDate: TDateTime;
    function GetAsFloat: Double;
    function GetAsInteger: Integer;
    function GetAsInt64: Int64;
    function GetAsString: string;
    function GetAsStringX: string;    //����β���ո�
    function GetAsPointer: PChar;
    function GetFieldType: Char;
    function GetFieldName: string;
    function GetWidth: Byte;
    function GetScale: Byte;
    procedure SetAsBoolean(Value: Boolean);
    procedure SetAsChar(Value: Char);
    procedure SetAsDate(Value: TDateTime);
    procedure SetAsFloat(Value: Double);
    procedure SetAsInteger(Value: Integer);
    procedure SetAsInt64(Value: Int64);
    procedure SetAsString(const Value: string);
    procedure SetAsPointer(const Value: PChar);
  public
    constructor Create(Ptr: PDBFField);
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsChar: Char read GetAsChar write SetAsChar;
    property AsDateTime: TDateTime read GetAsDate write SetAsDate;
    property AsFloat: Double read GetAsFloat write SetAsFloat;
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
    property AsInt64: Int64 read GetAsInt64 write SetAsInt64;
    property AsString: string read GetAsString write SetAsString;
    property AsStringX: string read GetAsStringX;
    property AsPointer: PChar read GetAsPointer write SetAsPointer;
    property FieldType: Char read GetFieldType;
    property FieldName: string read GetFieldName;
    property Width: Byte read GetWidth;
    property Scale: Byte read GetScale;
  end;

  TFieldList = class(TList)
  private
    function GetField(Index: Integer): TField;
  protected
  public
    procedure Clear; override;
    property Fields[Index: Integer]: TField read GetField;
  end;

  TDataStatus = (dsBrowse, dsEdit, dsAppend);
  TLockMode = (lmFoxFile, lmFoxRecord, lmRawFile, lmNoLock);
  
  TDBF = class
  private
    FHead: TDBFHead;
    FDBFFields: array[0..253] of TDBFField;
    FFieldList: TFieldList;
    FFieldCount: Integer;
    FFileStream: TFileStream;
    FTableName: TFileName;
    FExclusive: Boolean;
    FReadOnly: Boolean;
    FActive: Boolean;
    FRecNo: Integer;
    FBof: Boolean;
    FEof: Boolean;
    FDataStatus: TDataStatus;
    FLockMode: TLockMode;
    FLockTime: DWORD;
    FRecBuf: PChar;
    FReadNoLock: Boolean;
    FErrorMsg: string; 
    function GetRecordCount: Integer;
    function GetDeleted: Boolean;
    function GetField(Index: Integer): TField;
    procedure SetTablename(Value: TFileName);
    procedure SetExclusive(Value: Boolean);
    procedure SetReadOnly(Value: Boolean);
    procedure SetActive(Value: Boolean);
    procedure SetRecNo(Value: Integer);
    procedure SetDeleted(Value: Boolean);
    function Lock(RecordNo: Integer): Boolean;
    procedure Unlock(RecordNo: Integer);
    function ReadHead: Boolean;
    function ReadRecord(RecordNo: Integer): Boolean;
    procedure CheckActive(Flag: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    procedure First;
    procedure Last;
    procedure Prior;
    procedure Next;
    function MoveBy(Distance: Integer): Integer;
    procedure Go(RecordNo: Integer);
    function GoX(RecordNo: Integer): Boolean; 
    procedure Fresh;
    procedure Append;
    procedure Edit;
    procedure Post;
    procedure Empty;
    
    procedure LockTable;
    procedure AppendWithLock;
    procedure UnLockTable;
    function FieldByName(const FieldName: string): TField;
    property TableName: TFileName read FTableName write SetTableName;
    property Exclusive: Boolean read FExclusive write SetExclusive;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    property Active: Boolean read FActive write SetActive;
    property Bof: Boolean read FBof;
    property Deleted: Boolean read GetDeleted write SetDeleted;
    property Eof: Boolean read FEof;
    property FieldCount: Integer read FFieldCount;
    property Fields[Index: Integer]: TField read GetField;
    property LockMode: TLockMode read FLockMode write FLockMode;
    property LockTime: DWORD read FLockTime write FLockTime;
    property RecNo: Integer read FRecNo write SetRecNo;
    property RecordCount: Integer read GetRecordCount;
    property ReadNoLock: Boolean read FReadNoLock write FReadNoLock;
    property ErrorMsg: string read FErrorMsg;
  end;

function CreateDbf(const sFileName: string; var sFields: TStringList): Boolean;

implementation

function GetPart(sSource: string; cDelimiter: Char; byPart: Integer): string;
var
  byCount: Integer;

  function GetFront(sSource: string; cDelimiter: Char): string;
  var
    iPos: Integer;
  begin
    iPos := Pos(cDelimiter, sSource);
    if iPos > 0 then
    begin
      Result := Copy(sSource, 1, iPos - 1)
    end
    else
    begin
      Result := '';
    end;
  end;

  function GetBack(sSource: string; cDelimiter: Char): string;
  var
    iPos: Integer;
  begin
    iPos := Pos(cDelimiter, sSource);
    if iPos > 0 then
    begin
      Result := Copy(sSource, iPos + 1, (Length(sSource) - iPos))
    end
    else
    begin
      Result := '';
    end;
  end;
begin
  sSource := sSource + cDelimiter;
  if byPart > 0 then
  begin
    for byCount := 2 to byPart do
    begin
      sSource := GetBack(sSource, cDelimiter);
    end;
    Result := GetFront(sSource, cDelimiter);
  end
  else
  begin
    Result := '';
  end;
end;

{ TField }

constructor TField.Create(Ptr: PDBFField);
begin
  inherited Create;
  FPtr := Ptr;
end;

function TField.GetAsBoolean: Boolean;
begin
  Result := (FPtr^.FieldType = 'L') and ((FDataBuf + FPtr^.FieldOffset)^ = 'T');
end;

function TField.GetAsChar: Char;
begin
  Result := (FDataBuf + FPtr^.FieldOffset)^;
end;

function TField.GetAsDate: TDateTime;
begin
  GetAsPointer;
  try
    Result := EncodeDate(StrToIntDef(Copy(FFieldBuf, 1, 4), 0),
      StrToIntDef(Copy(FFieldBuf, 5, 2), 0),
      StrToIntDef(Copy(FFieldBuf, 7, 2), 0));
  except
    Result := EncodeDate(1980, 01, 01);
  end;
end;

function TField.GetAsFloat: Double;
begin
  //GetAsPointer;
  try
    Result := StrToFloat(GetAsString); //FFieldBuf);
  except
    Result := 0;
  end;
end;

function TField.GetAsInteger: Integer;
begin
  //GetAsPointer;
  Result := StrToIntDef(GetAsString, 0); //FFieldBuf, 0);
end;

function TField.GetAsInt64: Int64;
begin
  Result := StrToInt64Def(GetAsString, 0);
end;

function TField.GetAsString: string;
var
  i: Integer;
begin
  GetAsPointer;
  for i := FPtr^.Width - 1 downto 0 do
  begin
    if FFieldBuf[i] <> ' ' then
    begin
      Break;
    end;
  end;
  FFieldBuf[i + 1] := #0;
  Result := FFieldBuf;
end;

function TField.GetAsStringX: string;
begin
  Result := GetAsPointer;
end;

function TField.GetAsPointer: PChar;
begin
  Move((FDataBuf + FPtr^.FieldOffset)^, FFieldBuf, FPtr^.Width);
  FFieldBuf[FPtr^.Width] := #0;
  Result := FFieldBuf;
end;

function TField.GetFieldType: Char;
begin
  Result := FPtr^.FieldType;
end;

function TField.GetWidth: Byte;
begin
  Result := FPtr^.Width;
end;

function TField.GetScale: Byte;
begin
  Result := FPtr^.Scale;
end;

procedure TField.SetAsBoolean(Value: Boolean);
begin
  if FPtr^.Width > 1 then
  begin
    FillChar((FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width, $20);
  end;

  if Value then
  begin
    (FDataBuf + FPtr^.FieldOffset)^ := 'T'
  end
  else
  begin
    (FDataBuf + FPtr^.FieldOffset)^ := 'F';
  end;
end;

procedure TField.SetAsChar(Value: Char);
begin
  if FPtr^.Width > 1 then
  begin
    FillChar((FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width, $20);
  end;
  (FDataBuf + FPtr^.FieldOffset)^ := Value;
end;

procedure TField.SetAsDate(Value: TDateTime);
begin
  SetAsString(FormatDateTime('yyyymmdd', Value));
end;

procedure TField.SetAsFloat(Value: Double);
begin
  SetAsString(Format('%*.*f', [FPtr^.Width, FPtr^.Scale, Value]));
end;

procedure TField.SetAsInteger(Value: Integer);
begin
  SetAsString(IntToStr(Value));
end;

procedure TField.SetAsInt64(Value: Int64);
begin
  SetAsString(IntToStr(Value));
end;

procedure TField.SetAsString(const Value: string);
var
  iDataLen: Integer;
begin
  iDataLen := Length(Value);
  if iDataLen > FPtr^.Width then
  begin
    iDataLen := FPtr^.Width
  end
  else if iDataLen < FPtr^.Width then
  begin
    FillChar((FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width, $20);
  end;

  if (FPtr^.FieldType = 'N') or (FPtr^.FieldType = 'F') then
  begin
    Move(PChar(Value)^, (FDataBuf + FPtr^.FieldOffset + FPtr^.Width - iDataLen)^, iDataLen)
  end
  else
  begin
    Move(PChar(Value)^, (FDataBuf + FPtr^.FieldOffset)^, iDataLen);
  end;
end;

procedure TField.SetAsPointer(const Value: PChar);
begin
  Move(Value^, (FDataBuf + FPtr^.FieldOffset)^, FPtr^.Width);
end;

function TField.GetFieldName: string;
begin
  Result := FPtr^.FieldName;
end;


{ TFieldList }

procedure TFieldList.Clear;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    TField(Items[i]).Free;
  end;
  inherited;
end;

function TFieldList.GetField(Index: Integer): TField;
begin
  Result := Items[Index];
end;

{ THsDBF }

constructor TDBF.Create;
begin
  inherited Create;
  FFieldCount := 0;
  FFileStream := nil;
  FExclusive := False;
  FReadOnly := False;
  FActive := False;
  FRecNo := 0;
  FBof := True;
  FEof := True;
  FDataStatus := dsBrowse;
  FLockMode := lmFoxFile;
  FLockTime := 4000;
  FFieldList := TFieldList.Create;
  FRecBuf := nil;
{$IFDEF ReadNoLock}
  FReadNoLock := True;
{$ELSE}
  FReadNoLock := False;
{$ENDIF}
end;

destructor TDBF.Destroy;
begin
  Close;
  FFieldList.Free;
  inherited;
end;

function TDBF.GetRecordCount: Integer;
begin
  CheckActive(True);
  Result := FHead.RecCount;
end;

function TDBF.GetDeleted: Boolean;
begin
  CheckActive(True);
  Result := FRecBuf[0] = Chr($2A);
end;

function TDBF.GetField(Index: Integer): TField;
begin
  CheckActive(True);
  Result := FFieldList.Fields[Index];
end;

procedure TDBF.SetTablename(Value: TFileName);
begin
  CheckActive(False);
  FTableName := Value;
end;

procedure TDBF.SetExclusive(Value: Boolean);
begin
  CheckActive(False);
  FExclusive := Value;
end;

procedure TDBF.SetReadOnly(Value: Boolean);
begin
  CheckActive(False);
  FReadOnly := Value;
end;

procedure TDBF.SetActive(Value: Boolean);
begin
  if Value then
  begin
    Open
  end
  else
  begin
    Close;
  end;
end;

procedure TDBF.SetRecNo(Value: Integer);
begin
  CheckActive(True);
  Go(Value);
end;

procedure TDBF.SetDeleted(Value: Boolean);
var
  cDeleted: Char;
begin
  CheckActive(True);
  if Value then
  begin
    cDeleted := Chr($2A)
  end
  else
  begin
    cDeleted := Chr($20);
  end;

  if FRecBuf[0] = cDeleted then
  begin
    Exit;
  end;

  with FFileStream do
  begin
    if Lock(FRecNo) then
    begin
      try
        Seek(FHead.DataOffset + (FRecNo - 1) * FHead.RecSize, soFromBeginning);
        Write(cDeleted, 1);
      finally
        Unlock(0);
      end;
    end;
  end;
  FRecBuf[0] := cDeleted;
end;

function TDBF.Lock(RecordNo: Integer): Boolean;
var
  dwCount, dwCount2: DWORD;
  i: Integer;
begin
  dwCount := GetTickCount;
  dwCount2 := 0;
  i := 0;
  repeat
    if (FLockMode = lmFoxFile) or ((FLockMode = lmFoxRecord) and (RecordNo < 1)) then
    begin
      Result := LockFile(FFileStream.Handle, $40000000, 0, $C0000000, 0)
    end
    else if FLockMode = lmFoxRecord then
    begin
      Result := LockFile(FFileStream.Handle, $40000000 + FHead.DataOffset + (RecordNo - 1) * FHead.RecSize, 0, FHead.RecSize, 0)
    end
    else if FLockMode = lmRawFile then
    begin
      Result := LockFile(FFileStream.Handle, $00000000, 0, $FFFFFFFF, 0)
    end
    else
    begin
      Result := True;
    end;

    if Result then
    begin
      Break;
    end;
    
    dwCount2 := GetTickCount;
    Inc(i);
  until (dwCount2 >= dwCount) and (dwCount2 - dwCount >= FLockTime)
    or (dwCount2 < dwCount) and (MAXDWORD - dwCount + dwCount2 >= FLockTime);

  if not Result then
  begin
    raise Exception.Create(FTableName + '����ʧ��:���Լ�������:' + inttostr(i) + '���Լ���ʱ��:' + inttostr(FLockTime));
  end;
end;

procedure TDBF.Unlock(RecordNo: Integer);
begin
  if (FLockMode = lmFoxFile) or ((FLockMode = lmFoxRecord) and (RecordNo < 1)) then
  begin
    UnlockFile(FFileStream.Handle, $40000000, 0, $C0000000, 0)
  end
  else if FLockMode = lmFoxRecord then
  begin
    UnlockFile(FFileStream.Handle, $40000000 + FHead.DataOffset + (RecordNo - 1) * FHead.RecSize, 0, FHead.RecSize, 0)
  end
  else if FLockMode = lmRawFile then
  begin
    UnlockFile(FFileStream.Handle, $00000000, 0, $FFFFFFFF, 0);
  end;
end;

function TDBF.ReadHead: Boolean;
begin
  Result := False;
  with FFileStream do
  begin
    if Lock(0) then
    begin
      try
        Seek(0, soFromBeginning);
        Result := Read(FHead, SizeOf(TDBFHead)) = SizeOf(TDBFHead);
      finally
        Unlock(0);
      end
    end;
  end;
end;

function TDBF.ReadRecord(RecordNo: Integer): Boolean;
var
  Index: Integer;
  iLen: Longint;
  i: Integer;
begin
  Result := False;
  with FFileStream do
  begin
    if Lock(RecordNo) then
    begin
      try
        Move(FRecBuf^, (FRecBuf + FHead.RecSize)^, FHead.RecSize); //�������ã�
        for i := 0 to TRY_READ_TIMES do
        begin
          Seek(FHead.DataOffset + FHead.RecSize * (RecordNo - 1), soFromBeginning);
          iLen := Read(FRecBuf^, FHead.RecSize);
          if iLen <> FHead.RecSize then
          begin
            //���Գ�����,����
            if (i >= TRY_READ_TIMES) then
            begin
              //��ȡʧ��, ��ԭBufferֵ
              if iLen > 0 then
              begin
                Move((FRecBuf + FHead.RecSize)^, FRecBuf^, FHead.RecSize);
              end;

              raise Exception.Create(FTableName + '��ȡ��¼ʧ��(��¼��:' + IntToStr(RecordNo)
                + ',��¼����:' + IntToStr(FHead.RecSize) + ',��ȡ����:' + IntToStr(iLen) + ')');
            end;
          end
          else
          begin
            //��ȡ�ɹ�,�˳�ѭ��
            Break;
          end;
          Sleep(20);
        end;
        {for iLen := 0 to FHead.RecSize - 1 do
          if (FRecBuf + iLen)^ = #0 then
             (FRecBuf + iLen)^ := ' ';}
      finally
        Unlock(RecordNo);
      end;
      FRecNo := RecordNo;
      for Index := 0 to FFieldCount - 1 do
      begin
        FFieldList.Fields[Index].FDataBuf := FRecBuf;
      end;
      Result := True;
    end;
  end;
end;

procedure TDBF.CheckActive(Flag: Boolean);
begin
  if Flag and (not FActive) then
  begin
    raise Exception.Create('�ļ���δ��');
  end;

  if (not Flag) and FActive then
  begin
    raise Exception.Create('�ļ��Ѿ���');
  end;
end;

procedure TDBF.Open;
var
  Index: Integer;
  wMode: Word;
  lmSave: TLockMode;
begin
  if FActive then
  begin
    Exit;
  end;

  if FReadNoLock then
  begin
    lmSave := FLockMode;
    FLockMode := lmNoLock;
  end
  else
  begin
    lmSave := FLockMode; 
  end;
  
  try
    if FExclusive then
    begin
      wMode := fmShareExclusive
    end
    else
    begin
      wMode := fmShareDenyNone;
    end;

    if FReadOnly then
    begin
      wMode := wMode or fmOpenRead
    end
    else
    begin
      wMode := wMode or fmOpenReadWrite;
    end;


    FFileStream := TFileStream.Create(FTableName, wMode);
    FRecBuf := nil;
    with FFileStream do
    begin
      try
        //����DBFͷ�ṹ
        if not ReadHead then
        begin
          raise Exception.Create(FTableName + '������Ч��DBF�ļ�');
        end;

        //���㹲�м����ֶ�
        FFieldCount := (FHead.DataOffset - SizeOf(TDBFHead)) div SizeOf(TDBFField);
        if (FFieldCount < 1) or (FFieldCount > 254) then
        begin
          raise Exception.Create(FTableName + '���ֶθ�����Ч');
        end;

        if Read(FDBFFields, FFieldCount * SizeOf(TDBFField)) <> FFieldCount * SizeOf(TDBFField) then
        begin
          raise Exception.Create(FTableName + '���ֶθ�������');
        end;

        //��ĳЩDBF���ܲ��淶������ƫ����
        FDBFFields[0].FieldOffset := 1;
        for Index := 1 to FFieldCount - 1 do
        begin
          FDBFFields[Index].FieldOffset := FDBFFields[Index - 1].FieldOffset + FDBFFields[Index - 1].Width;
        end;
        GetMem(FRecBuf, FHead.RecSize * 2);
        FillChar(FRecBuf^, FHead.RecSize * 2, $20);
        FFieldList.Clear;
        for Index := 0 to FFieldCount - 1 do
        begin
          FFieldList.Add(TField.Create(@FDBFFields[Index]));
          FFieldList.Fields[Index].FDataBuf := FRecBuf;
        end;
        FActive := True;
        if FHead.RecCount > 0 then
        try
          Go(1);
        except
        
        end;
      except
        FFileStream.Free;
        if FRecBuf <> nil then
        begin
          FreeMem(FRecBuf);
          FRecBuf := nil;
        end;
        raise;
      end;
    end;
  finally
    if FReadNoLock then
    begin
      FLockMode := lmSave;
    end;
  end;
end;

procedure TDBF.Close;
begin
  if Active then
  begin
    FFieldCount := 0;
    FFileStream.Free;
    FFileStream := nil;
    //FExclusive := False;
    //FReadOnly := False;
    FActive := False;
    FRecNo := 0;
    FBof := True;
    FEof := True;
    FDataStatus := dsBrowse;
    FreeMem(FRecBuf);
  end;
end;

procedure TDBF.First;
begin
  CheckActive(True);
  Go(1);
  FBof := True;
end;

procedure TDBF.Last;
begin
  CheckActive(True);
  ReadHead;
  Go(FHead.RecCount);
  FEof := True;
end;

procedure TDBF.Prior;
begin
  CheckActive(True);
  Go(FRecNo - 1);
end;

procedure TDBF.Next;
begin
  CheckActive(True);
  Go(FRecNo + 1);
end;

function TDBF.MoveBy(Distance: Integer): Integer;
var
  iPreRecNo: Integer;
begin
  CheckActive(True);
  iPreRecNo := FRecNo;
  Go(FRecNo + Distance);
  Result := FRecNo - iPreRecNo;
end;

procedure TDBF.Go(RecordNo: Integer);
var
  lmSave: TLockMode;
begin
  if FReadNoLock then
  begin
    lmSave := FLockMode;
    FLockMode := lmNoLock;
  end
  else
  begin
    lmSave := FLockMode; 
  end;

  try
    CheckActive(True);
    if (FHead.RecCount < 1) or FEof then
    try
      ReadHead;
    except
    end;
    if (RecordNo < 1) then
    begin
      FBof := True;
      if FHead.RecCount >= 1 then
      begin
        ReadRecord(1);
        FEof := False;
      end
      else
      begin
        FEof := True;
      end;
    end
    else if RecordNo > FHead.RecCount then
    begin
      try
        ReadHead;
      except
      
      end;
      if RecordNo > FHead.RecCount then
      begin
        FEof := True;
        FBof := FHead.RecCount < 1;
        FillChar(FRecBuf^, FHead.RecSize * 2, $20);
        FRecNo := RecordNo;
      end
      else
      begin
        FEof := False;
        FBof := False;
        ReadRecord(RecordNo);
      end;
    end
    else
    begin
      FBof := False;
      FEof := False;
      ReadRecord(RecordNo);
    end;
  finally
    if FReadNoLock then
    begin
      FLockMode := lmSave;
    end;
  end;
end;

function TDBF.GoX(RecordNo: Integer): Boolean;
var
  lmSave: TLockMode;
begin
  Result := True; FErrorMsg := '';
  if FReadNoLock then
  begin
    lmSave := FLockMode;
    FLockMode := lmNoLock;
  end
  else
  begin
    lmSave := FLockMode; 
  end;
  
  try
    try
      CheckActive(True);
      if (FHead.RecCount < 1) or FEof then
      try
        ReadHead;
      except
      end;
      if (RecordNo < 1) then
      begin
        FBof := True;
        if FHead.RecCount >= 1 then
        begin
          ReadRecord(1);
          FEof := False;
        end
        else
        begin
          FEof := True;
        end;
      end
      else if RecordNo > FHead.RecCount then
      begin
        try
          ReadHead;
        except
        
        end;
        if RecordNo > FHead.RecCount then
        begin
          FEof := True;
          FBof := FHead.RecCount < 1;
          FillChar(FRecBuf^, FHead.RecSize * 2, $20);
          FRecNo := RecordNo;
        end
        else
        begin
          FEof := False;
          FBof := False;
          ReadRecord(RecordNo);
        end;
      end
      else
      begin
        FBof := False;
        FEof := False;
        ReadRecord(RecordNo);
      end;
    except
      on E: Exception do
      begin
        Result := False;
        FErrorMsg := E.Message; //��¼������Ϣ
      end
    end;
  finally
    if FReadNoLock then
    begin
      FLockMode := lmSave;
    end;
  end;
end;

procedure TDBF.Fresh;
var
  lmSave: TLockMode;
begin
  if FReadNoLock then
  begin
    lmSave := FLockMode;
    FLockMode := lmNoLock;
  end
  else
  begin
    lmSave := FLockMode; 
  end;

  try
    CheckActive(True);
    ReadHead;
    if (FRecNo <= FHead.RecCount) and (FRecNo >= 1) and (FHead.RecCount > 0) then
    begin
      ReadRecord(FRecNo);
    end;
  finally
    if FReadNoLock then
    begin
      FLockMode := lmSave;
    end;
  end;
end;


procedure TDBF.Append;
begin
  CheckActive(True);
  FDataStatus := dsAppend;
  FillChar(FRecBuf^, FHead.RecSize * 2, $20);
end;

procedure TDBF.Edit;
begin
  CheckActive(True);
  FDataStatus := dsEdit;
end;

procedure TDBF.LockTable;
begin 
{
  if FDataStatus = dsAppend then
  begin
    with FFileStream do
    begin
      Lock(0);
    end;
  end;
}
  with FFileStream do
  begin
    Lock(0);
    Seek(0, soFromBeginning);
    Read(FHead, SizeOf(TDBFHead));
  end;
end;

procedure TDBF.UnLockTable;
begin
  try
    with FFileStream do
    begin
      UnLock(0);
    end;
  except
  end;
end;

procedure TDBF.AppendWithLock;
begin
  if FDataStatus = dsAppend then
  begin
    FDataStatus := dsBrowse;
    with FFileStream do
    begin
      try
        Seek(0, soFromBeginning);
                
        if Read(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + '��ȡ�ļ�ͷʧ�ܣ�������Ч��DBF�ļ���');
        end;
        Seek(FHead.DataOffset + FHead.RecCount * FHead.RecSize, soFromBeginning);
        (FRecBuf + FHead.RecSize)^ := Chr($1A);
        if Write(FRecBuf^, FHead.RecSize + 1) <> (FHead.RecSize + 1) then
        begin
          raise Exception.Create(FTableName + 'д�ļ�ʧ�ܣ�');
        end;
        Inc(FHead.RecCount);
        Seek(0, soFromBeginning);
        if Write(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + 'д�ļ�ͷʧ��');
        end;
        FRecNo := FHead.RecCount;
      finally
        Unlock(0);
      end;
    end;
  end;
end;

procedure TDBF.Post;
var
  lmSave: TLockMode;
begin
  CheckActive(True);
  if FDataStatus = dsEdit then
  begin
    FDataStatus := dsBrowse;
    lmSave := FLockMode;
    FLockMode := lmFoxRecord;
    try
      with FFileStream do
      begin
        if Lock(FRecNo) then
        try
          Seek(FHead.DataOffset + (FRecNo - 1) * FHead.RecSize, soFromBeginning);
          if Write(FRecBuf^, FHead.RecSize) <> FHead.RecSize then
          begin
            raise Exception.Create(FTableName + 'д�ļ�ʧ�ܣ�');
          end;
        finally
          Unlock(FRecNo);
        end;
      end;
    finally
      FLockMode := lmSave;
    end;
  end
  else if FDataStatus = dsAppend then
  begin
    FDataStatus := dsBrowse;
    with FFileStream do
    begin
      if Lock(0) then
      try
        Seek(0, soFromBeginning);
        if Read(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + '��ȡ�ļ�ͷʧ�ܣ�������Ч��DBF�ļ���');
        end;
        Seek(FHead.DataOffset + FHead.RecCount * FHead.RecSize, soFromBeginning);
        (FRecBuf + FHead.RecSize)^ := Chr($1A);
        if Write(FRecBuf^, FHead.RecSize + 1) <> (FHead.RecSize + 1) then
        begin
          raise Exception.Create(FTableName + 'д�ļ�ʧ�ܣ�');
        end;
        Inc(FHead.RecCount);
        Seek(0, soFromBeginning);
        if Write(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + 'д�ļ�ͷʧ��');
        end;
        FRecNo := FHead.RecCount;
      finally
        Unlock(0);
      end;
    end;
  end;
end;

//��DBF�е����м�¼�������
procedure TDBF.Empty;
var
  wYear, wMonth, wDay: WORD;
begin
  CheckActive(True);
  with FFileStream do
  begin
    if Lock(0) then
    begin
      try
        Seek(0, soFromBeginning);
        if Read(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + '��ȡ�ļ�ͷʧ�ܣ�������Ч��DBF�ļ���');
        end;
        DecodeDate(Date, wYear, wMonth, wDay);
        FHead.Year := wYear - (wYear div 100) * 100;
        FHead.Month := Byte(wMonth);
        FHead.Day := Byte(wDay);
        FHead.RecCount := 0;
        Seek(0, soFromBeginning);
        if Write(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + 'д�ļ�ͷʧ��');
        end;
        FRecNo := FHead.RecCount;
        FEof := True;
        FBof := True;
        FillChar(FRecBuf^, FHead.RecSize * 2, $20);
        FFileStream.Size := FHead.DataOffset;
        //Seek(FHead.DataOffset, soFromBeginning);
        //byEnd := $1A;
        //Write(byEnd, 1);
      finally
        Unlock(0);
      end;
    end;
  end;
end;

function TDBF.FieldByName(const FieldName: string): TField;
var
  Index: Integer;
begin
  Result := nil;
  CheckActive(True);
  for Index := 0 to FFieldCount - 1 do
  begin
    if StrIComp(FDBFFields[Index].FieldName, PChar(FieldName)) = 0 then
    begin
      Result := FFieldList.Fields[Index];
      Break;
    end;
  end;
  
  if Result = nil then
  begin
    raise Exception.Create(FTableName + '�Ҳ����ֶ�' + FieldName);
  end;
end;

//sfields Ϊ�ַ������飬ÿ����Ŀ����һ���ֶζ��壬�����ʽΪ '�ֶ���|�ֶ�����|���|����'
function CreateDbf(const sFileName: string; var sFields: TStringList): Boolean;
var
  tmpHead: TDBFHead;
  wYear, wMonth, wDay: word;
  tmpField: TDBFField;
  iOffset, c: byte;
  fBinFile, iRecsize, i: integer;
begin
  Result := True;
  if FileExists(sFileName) then
  begin
    Exit;
  end;

  fBinFile := FileCreate(sFileName);
  if (fBinFile < 0) then
  begin
    Result := False;
    Exit;
  end;
  try
    try
      with tmpHead do
      begin
        DecodeDate(Date, wYear, wMonth, wDay);
        Year := wYear - (wYear div 100) * 100;
        Month := Byte(wMonth);
        Day := Byte(wDay);
        RecCount := 0;
      end;
      FileWrite(fBinFile, tmpHead, SizeOf(TDBFHead));
      iOffset := 1;
      iRecsize := 0;
      for i := 0 to sFields.count - 1 do
      begin
        FillChar(tmpField.FieldName, SizeOf(tmpField.FieldName), #0);
        strpcopy(tmpField.FieldName, GetPart(sFields[i], '|', 1));
        tmpField.FieldType := GetPart(sFields[i], '|', 2)[1];
        tmpField.FieldOffset := iOffset;
        tmpField.Width := StrToIntdef(GetPart(sFields[i], '|', 3), 0);
        tmpField.Scale := StrToIntdef(GetPart(sFields[i], '|', 4), 0);
        FillChar(tmpField.Reserved, SizeOf(tmpField.Reserved), #0);
        iOffset := iOffset + tmpField.Width;
        FileWrite(fBinFile, tmpField, SizeOf(TDBFField));
        iRecsize := iRecsize + tmpField.Width;
      end;
      c := 13;
      FileWrite(fBinFile, c, 1);
      fileseek(fBinFile, 0, 0);
      with tmpHead do
      begin
        Mark := #03;
        DecodeDate(Date, wYear, wMonth, wDay);
        Year := wYear - (wYear div 100) * 100;
        Month := Byte(wMonth);
        Day := Byte(wDay);
        RecCount := 0;
        DataOffset := SizeOf(TDBFHead) + sFields.count * 32 + 1;
        RecSize := iRecsize + 1; //1ɾ�����
        FillChar(Reserved, SizeOf(Reserved), #0);
      end;
      FileWrite(fBinFile, tmpHead, SizeOf(tmpHead));
    except
      Result := False;
    end;
  finally
    FileClose(fBinFile);
  end;
end;

end.

