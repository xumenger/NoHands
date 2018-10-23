unit U_DBF;

interface

uses
  Windows, SysUtils, Dialogs, StrUtils, Controls, Messages, Classes, Forms, IniFiles;

const
  //支持的DBF字段数据类型(Dbf Field Variable Type)：
  DFVT_NUMERIC = 'N';     //数值，包括整数和浮点小数
  DFVT_CHAR = 'C';        //字符、字符串
  DFVT_DATE = 'D';        //日期
  DFVT_LOGICAL = 'L';     //逻辑(布尔)
  DFVT_FLOAT = 'F';       //浮点小数，需要提供小数位数

  //DBF中的标记：
  DBFEOF: Byte = $1A;         //DBF文件结束
  HDREND: Byte = $0D;         //头结束
  FOXPRODBF: Byte = $03;      //FoxPro文件标识
  SPACE: Byte = ORD(' ');     //空格字符
  DELETED: Byte = ORD('*');   //删除标记
  FDARSVLEN = 14;             //FDA中的保留字节数
  HDRRSVLEN = 20;             //HDR中的保留字节数

  //字段缺省长度:
  DEFLEN_CHAR: Integer = 15;      //字符串
  DEFLEN_NUMERIC: Integer = 12;   //数值
  DEFLEN_DATE: Integer = 8;       //日期
  DEFLEN_LOGICAL: Integer = 1;    //逻辑
  DEFLEN_FLOAT: Integer = 15;     //小数总长
  DEFLEN_PREC: Integer = 4;       //小数部分长度

  //字段长度上限：
  LIMLEN_CHAR: Integer = 254;
  LIMLEN_NUMERIC: Integer = 20;
  LIMLEN_DATE: Integer = 8;
  LIMLEN_LOGICAL: Integer = 1;
  LIMLEN_FLOAT: Integer = 20;

  TRY_READ_TIMES: Integer = 50;   //读取重试次数

type
  PStrings = ^TStrings;
  PStringList = ^TStringList;

  //DBF文件结构分为两大部分：文件结构说明区和数据区。
  //文件结构说明区包括数据库参数区和记录结构表区。数据库参数区占32个字节：
  //记录结构表区包括各字段参数，每个字段占32字节

  // DBF文件头结构
  PDBFHead = ^TDBFHead;
  TDBFHead = packed record
    Mark: Char;         //1   0+1
    Year: Byte;         //2   1+1   年
    Month: Byte;        //3   2+1   月
    Day: Byte;          //4   3+1   日
    RecCount: Integer;  //8   4+4   记录数
    DataOffset: Word;   //10  8+2
    RecSize: Word;      //12  10+2
    Reserved: array[0..19] of Char;
  end;

  //DBF文件每字段结构
  PDBFField = ^TDBFField;
  TDBFField = packed record
    FieldName: array[0..10] of Char;    //字段名称
    FieldType: Char;                    //字段类型
    FieldOffset: Integer;
    Width: Byte;                        //字段宽度
    Scale: Byte;                        //字段精度
    Reserved: array[0..13] of Char;
  end;

  //DBF结构汇总
  //1.字段描述数组项(Field Descriptor Array Header)
  FDA = record
    sName: array[0..10] of AnsiChar;  //字段名称[ascii field name, 0x00 termin]
    cType: AnsiChar;                  //字段数据类型，见常量定义[ascii field type]
    ulOffset: LongWord;               //从记录开始的偏移量[offset from record begin]
    btLength: Byte;                   //字段长度[field length, bin]
    btDecimalCount: Byte;             //小数位数[decimal count, bin]
    _Reserved: array[0..FDARSVLEN - 1] of Byte; //保留字节，填0[reserved]
  end;
  FDAPTR = ^FDA;

  //2.长度固定的记录结构(Fix Each Dbf Record)
  FEDR = record
    btDeleted: Byte;    //删除标记[deleted flag "*" or not deleted " "]
    sData: AnsiString;  //数据记录，记录长度为几个FDA中fLength的长度之和(视字段数而定)
  end;
  EDR = FEDR;
  EDRPTR = ^EDR;

  //3.文件头结构(Header)，在文件头中没有包括FDA数组，因为这将使结构大小不可知
  DBFHDR = record
    _btType: BYTE;                      //DBF类型，填0x03
    btUpdateDate: array[0..2] of BYTE;  //修改日期，二进制，为yymmdd格式
    ulRecordCount: LongWord;            //记录计数
    usHeaderSize: Word;                 //文件头长度，包括文件头结束标志
    usRecordSize: Word;                 //单个记录长度，是各字段长度之和(包括数据和删除标记长度)
    _Reserved: array[0..HDRRSVLEN - 1] of Byte; //保留字节，全0
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
    function GetAsStringX: string;    //包括尾部空格
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
    raise Exception.Create(FTableName + '加锁失败:尝试加锁次数:' + inttostr(i) + '尝试加锁时间:' + inttostr(FLockTime));
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
        Move(FRecBuf^, (FRecBuf + FHead.RecSize)^, FHead.RecSize); //做备份用？
        for i := 0 to TRY_READ_TIMES do
        begin
          Seek(FHead.DataOffset + FHead.RecSize * (RecordNo - 1), soFromBeginning);
          iLen := Read(FRecBuf^, FHead.RecSize);
          if iLen <> FHead.RecSize then
          begin
            //重试超次数,报错
            if (i >= TRY_READ_TIMES) then
            begin
              //读取失败, 还原Buffer值
              if iLen > 0 then
              begin
                Move((FRecBuf + FHead.RecSize)^, FRecBuf^, FHead.RecSize);
              end;

              raise Exception.Create(FTableName + '读取记录失败(记录号:' + IntToStr(RecordNo)
                + ',记录长度:' + IntToStr(FHead.RecSize) + ',读取长度:' + IntToStr(iLen) + ')');
            end;
          end
          else
          begin
            //读取成功,退出循环
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
    raise Exception.Create('文件尚未打开');
  end;

  if (not Flag) and FActive then
  begin
    raise Exception.Create('文件已经打开');
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
        //读入DBF头结构
        if not ReadHead then
        begin
          raise Exception.Create(FTableName + '不是有效的DBF文件');
        end;

        //计算共有几个字段
        FFieldCount := (FHead.DataOffset - SizeOf(TDBFHead)) div SizeOf(TDBFField);
        if (FFieldCount < 1) or (FFieldCount > 254) then
        begin
          raise Exception.Create(FTableName + '的字段个数无效');
        end;

        if Read(FDBFFields, FFieldCount * SizeOf(TDBFField)) <> FFieldCount * SizeOf(TDBFField) then
        begin
          raise Exception.Create(FTableName + '的字段个数错误');
        end;

        //因某些DBF可能不规范，重置偏移量
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
        FErrorMsg := E.Message; //记录错误信息
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
          raise Exception.Create(FTableName + '读取文件头失败，或不是有效的DBF文件！');
        end;
        Seek(FHead.DataOffset + FHead.RecCount * FHead.RecSize, soFromBeginning);
        (FRecBuf + FHead.RecSize)^ := Chr($1A);
        if Write(FRecBuf^, FHead.RecSize + 1) <> (FHead.RecSize + 1) then
        begin
          raise Exception.Create(FTableName + '写文件失败！');
        end;
        Inc(FHead.RecCount);
        Seek(0, soFromBeginning);
        if Write(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + '写文件头失败');
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
            raise Exception.Create(FTableName + '写文件失败！');
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
          raise Exception.Create(FTableName + '读取文件头失败，或不是有效的DBF文件！');
        end;
        Seek(FHead.DataOffset + FHead.RecCount * FHead.RecSize, soFromBeginning);
        (FRecBuf + FHead.RecSize)^ := Chr($1A);
        if Write(FRecBuf^, FHead.RecSize + 1) <> (FHead.RecSize + 1) then
        begin
          raise Exception.Create(FTableName + '写文件失败！');
        end;
        Inc(FHead.RecCount);
        Seek(0, soFromBeginning);
        if Write(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + '写文件头失败');
        end;
        FRecNo := FHead.RecCount;
      finally
        Unlock(0);
      end;
    end;
  end;
end;

//将DBF中的所有记录彻底清除
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
          raise Exception.Create(FTableName + '读取文件头失败，或不是有效的DBF文件！');
        end;
        DecodeDate(Date, wYear, wMonth, wDay);
        FHead.Year := wYear - (wYear div 100) * 100;
        FHead.Month := Byte(wMonth);
        FHead.Day := Byte(wDay);
        FHead.RecCount := 0;
        Seek(0, soFromBeginning);
        if Write(FHead, SizeOf(TDBFHead)) <> SizeOf(TDBFHead) then
        begin
          raise Exception.Create(FTableName + '写文件头失败');
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
    raise Exception.Create(FTableName + '找不到字段' + FieldName);
  end;
end;

//sfields 为字符串数组，每个项目代表一个字段定义，定义格式为 '字段名|字段类型|宽度|精度'
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
        RecSize := iRecsize + 1; //1删除标记
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

