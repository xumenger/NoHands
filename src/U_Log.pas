{֧��ָ������ļ���׺����Ĭ����.log
 ֧��ָ��д��־��ʽ��ͬ�������첽(�½��߳�)��Ĭ����ͬ����ʽ}
unit U_Log;

interface

uses SysUtils, Classes, IniFiles, U_List, U_Queue, Windows, StrUtils;

type
  //��־��Ϣ
  PLogMessage = ^TLogMessage;
  TLogMessage = record
    isDetail: Boolean;          //�Ƿ��������ʱ�䡢�̺߳ŵȵ���ϸ��Ϣ
    MsgType: string;            //��Ϣ����
    Msg: string;                //��Ϣ����
    LogLevel: Integer;          //��־����
    LogTime: TDateTime;         //�����־ʱ��
    CurrentThreadID: string;    //��¼��־���̺߳�
  end;

  //��־�ļ�
  PLogFile = ^TLogFile;
  TLogFile = record
    FileName: string;           //��־�ļ���
    MaxSize: Double;            //��־�ļ����Size
    Sequence: Integer;
    LastCheckTime: Cardinal;
    FileHandle: Cardinal;       //�ļ����
    SFileDate: string;
  end;

  TLog = class;
  
  //д��־�߳�
  TWriteLogThread = class(TThread)
  public
    writelogObj: TLog;
    CanExit: Boolean;
  protected
    procedure Execute; override;
  end;

  //д��־��
  TLog = class(TObject)
  private
    FLogFilePath: string;   //��־�ļ�·��
    FFileNameHead: string;  //��־�ļ�����ͷ��
    FLogLevel: Integer;     //��ǰ��־����
    FIsSync: Boolean;       //�Ƿ�ͬ��д��־��ͬ�������½��̡߳��첽���½��̣߳�
    FSuffix: string;        //����ļ���׺
    FWriteLogThread: TWriteLogThread; //д��־�߳�
    FLogFileMaxSize: Double;          //����ļ���С����λM
    FLogFileList: TStrOrderList;
  public
    LogQueue: TLockQueue;   //��־���ݶ���
    constructor Create(const FileNameHead: string; const IsSync: Boolean = True; const Suffix: string = 'log'; const Path: string = ''; const iMaxSize: Double = 100.0);
    destructor Destroy; override;
    procedure AddLog(sMsg: string; MsgType: string = ''; LogLevel: Integer = 0; isDetail: Boolean = True); overload;
    procedure AddLog(LogLevel: Integer; StrFormat: string; const Args: array of const; MsgType: string = ''; isDetail: Boolean = True); overload;
    procedure WriteLog(msg: PLogMessage);
    function SetLogLevel(taskLabel: string; iDefault: Integer): Integer;
  end;

implementation
uses
  Forms;

{ THsWriteLog }

//���Ҫд����־��Ϣ����־���ͣ���־�ļ����ĵڶ����֣�����־��Ϣ����־�����Ƿ������ϸ��Ϣ
procedure TLog.AddLog(sMsg: string; MsgType: string = ''; LogLevel: Integer = 0; isDetail: Boolean = True);
var
  msg: PLogMessage;
begin
  if LogLevel > FLogLevel then
  begin
    Exit;
  end;
  New(msg);
  msg.MsgType := Trim(MsgType);
  msg.Msg := Trim(sMsg);
  msg.LogLevel := LogLevel;
  msg.LogTime := Now;
  msg.CurrentThreadID := IntToStr(GetCurrentThreadId);
  msg.isDetail := isDetail;

  if FIsSync then
  begin
    try
      WriteLog(msg);
      Dispose(msg);
    except

    end;
  end
  else
  begin
    LogQueue.Push(msg);
  end;
end;

procedure TLog.AddLog(LogLevel: Integer; StrFormat: string; const Args: array of const; MsgType: string; isDetail: Boolean);
var
  msg: PLogMessage;
begin
  if LogLevel > FLogLevel then
  begin
    Exit;
  end;
  New(msg);
  msg.MsgType := Trim(MsgType);
  try
    msg.Msg := Format(StrFormat, Args);
  except
    on E: Exception do
    begin
      msg.Msg := 'д��־ʱFormat����,StrFormat=[' + StrFormat + ']';
    end;
  end;
  msg.LogLevel := LogLevel;
  msg.LogTime := Now; 
  msg.CurrentThreadID := IntToStr(GetCurrentThreadId);
  msg.isDetail := isDetail;

  if FIsSync then
  begin
    try
      WriteLog(msg);
      Dispose(msg);
    except

    end;
  end
  else
  begin
    LogQueue.Push(msg);
  end;
end;

constructor TLog.Create(const FileNameHead: string; const IsSync: Boolean = True; const Suffix: string = 'log'; const Path: string = ''; const iMaxSize: Double = 100.0);
var
  iniFile: TIniFile;
  sFile: string;
begin
  FIsSync := IsSync;
  FSuffix := Suffix;
  sfile := ExtractFilePath(ParamStr(0)) + 'LogConfig.ini';
  iniFile := TIniFile.Create(sfile);
  try
    FLogLevel := iniFile.ReadInteger('WriteLog', 'LogLevel', 0);
  finally
    iniFile.Free;
  end;
  FLogFilePath := Trim(Path);
  if FLogFilePath = '' then
  begin
    FLogFilePath := ExtractFilePath(ParamStr(0)) + 'Logs\';
  end;
  if not DirectoryExists(FLogFilePath) then
  begin
    ForceDirectories(FLogFilePath);
  end;
  if FLogFilePath[StrLen(pChar(FLogFilePath))] <> '\' then
  begin
    FLogFilePath := FLogFilePath + '\';
  end;
  FLogFileList := TStrOrderList.Create;
  FLogFileMaxSize := iMaxSize;
  FFileNameHead := Trim(FileNameHead);
  if FFileNameHead = '' then
  begin
    FFileNameHead := 'WriteLog';
  end;

  if not FIsSync then
  begin
    LogQueue := TLockQueue.Create;
    FWriteLogThread := TWriteLogThread.Create(True);
    FWriteLogThread.writelogObj := Self;
    FWriteLogThread.Resume;
  end;
end;

destructor TLog.Destroy;
var
  itime: Cardinal;
  i: Integer;
  aLogFile: PLogFile;
begin
  if not FIsSync then
  begin
    FWriteLogThread.Terminate;
    itime := GetTickCount;
    while GetTickCount - itime < 500 do
    begin
      Sleep(1);
      if FWriteLogThread.CanExit then
      begin
        Break;
      end;
    end;
    FWriteLogThread.Free;
    LogQueue.Free;
  end;
  
  for i := 0 to FLogFileList.Count - 1 do
  begin
    aLogFile := PLogFile(FLogFileList.Items[i].Data);
    FileClose(aLogFile.FileHandle);
    Dispose(aLogFile);
  end;
  FLogFileList.Clear;
  FLogFileList.Free;
  inherited;
end;

function TLog.SetLogLevel(taskLabel: string; iDefault: Integer): Integer;
var
  iniFile: TIniFile;
  sfile: string;
begin
  sfile := ExtractFilePath(ParamStr(0)) + 'LogConfig.ini';
  iniFile := TIniFile.Create(sfile);
  try
    FLogLevel := iniFile.ReadInteger('WriteLog', taskLabel, iDefault);
  finally
    iniFile.Free;
  end;
  Result := FLogLevel;
end;

procedure TLog.WriteLog(msg: PLogMessage);
var
  FileName, s: string;
  aNode: PStrOrderListNode;
  aLogFile: PLogFile;
  iFileSize: Integer;
begin
  if msg.LogLevel > FLogLevel then
  begin
    Exit;
  end;
  
  if msg.MsgType <> '' then
  begin
    FileName := FLogFilePath + FFileNameHead + '_' + msg.MsgType
  end
  else
  begin
    FileName := FLogFilePath + FFileNameHead;
  end;
  
  if FLogFileList.Search(FileName, aNode) then
  begin
    aLogFile := aNode.Data;
  end
  else
  begin
    New(aLogFile);
    aLogFile.MaxSize := FLogFileMaxSize;
    aLogFile.Sequence := 1;
    aLogFile.LastCheckTime := 0; //�ոմ򿪵��ļ�Ҳ��Ҫ�ж��Ƿ񳬹��ļ����ֵ
    aLogFile.SFileDate := FormatDateTime('YYYY-MM-DD', Now);
    aLogFile.FileName := FileName + '_' + aLogFile.SFileDate + '.' + FSuffix;
    if not FileExists(aLogFile.FileName) then //����������򴴽�
    begin
      aLogFile.FileHandle := FileCreate(aLogFile.FileName); //ֱ�Ӵ������ļ��������ù���ģʽ���ر����ô򿪵�ģʽ
      FileClose(aLogFile.FileHandle);
    end;
    aLogFile.FileHandle := FileOpen(aLogFile.FileName, fmOpenWrite or fmShareDenyNone); //���ļ�
    if (-1 = aLogFile.FileHandle) then
    begin
      RaiseLastOSError;
    end;
    if not FLogFileList.Insert(FileName, aLogFile) then
    begin
      Dispose(aLogFile);
      Exit;
    end;
  end;
  //�ж���־�ļ���С�Ƿ񳬹����ֵ
  if GetTickCount - aLogFile.LastCheckTime > 60000 then
  begin
    //FindFirst���ܻ�ȡ����ʹ���ļ��Ĵ�С
    //FindFirst(aLogFile.FileName, faAnyFile, aSearchRec);
    iFileSize := GetFileSize(aLogFile.FileHandle, nil);
    if iFileSize > aLogFile.MaxSize * 1048576 then //100M��С
    begin
      FileClose(aLogFile.FileHandle);
      while True do //�ж�������Ŀ���ļ��Ƿ��Ѿ����ڣ������ڣ���־�ļ���ż�1
      begin
        if not FileExists(FileName + '_' + aLogFile.SFileDate + '_' + inttostr(aLogFile.Sequence) + '.' + FSuffix) then
        begin
          Break;
        end;
        Inc(aLogFile.Sequence);
      end;
      RenameFile(aLogFile.FileName, FileName + '_' + aLogFile.SFileDate + '_' + inttostr(aLogFile.Sequence) + '.' + FSuffix); //������
      Inc(aLogFile.Sequence);
      if not FileExists(aLogFile.FileName) then //����������򴴽�
      begin
        aLogFile.FileHandle := FileCreate(aLogFile.FileName);
        FileClose(aLogFile.FileHandle);
      end;
      aLogFile.FileHandle := FileOpen(aLogFile.FileName, fmOpenWrite or fmShareDenyNone); //���ļ�
      if (-1 = aLogFile.FileHandle) then
      begin
        RaiseLastOSError;
      end;
    end;
    aLogFile.LastCheckTime := GetTickCount;
  end;
  //�ж������Ƿ�ı�
  if aLogFile.SFileDate <> FormatDateTime('YYYY-MM-DD', Now) then
  begin
    FileClose(aLogFile.FileHandle); //�ر��ļ�
    aLogFile.Sequence := 1;         //��־�ļ������1
    aLogFile.SFileDate := FormatDateTime('YYYY-MM-DD', Now);
    aLogFile.FileName := FileName + '_' + aLogFile.SFileDate + '.' + FSuffix;
    
    //����������򴴽�
    if not FileExists(aLogFile.FileName) then
    begin
      aLogFile.FileHandle := FileCreate(aLogFile.FileName);
      FileClose(aLogFile.FileHandle);
    end;
    aLogFile.FileHandle := FileOpen(aLogFile.FileName, fmOpenWrite or fmShareDenyNone); //���ļ�
    if (-1 = aLogFile.FileHandle) then
    begin
      RaiseLastOSError;
    end;
  end;
  //��ʼд
  if msg.isDetail then
  begin
    s := FormatDateTime('hhmmss.zzz', msg.LogTime) + '[' + IntToStr(msg.LogLevel) + '][' + msg.CurrentThreadID + ']: ' + msg.Msg + #13#10;
  end
  else
  begin
    s := msg.Msg + #13#10;
  end;
  FileSeek(aLogFile.FileHandle, 0, 2);              //��λ���ļ�ĩβ
  FileWrite(aLogFile.FileHandle, s[1], Length(s));  //׷������
end;

{ TWriteLogThread }

procedure TWriteLogThread.Execute;
var
  msg: PLogMessage;
  WCount: Integer;
begin
  inherited;
  CanExit := False;
  try
    while not Terminated do
    begin
      try
        msg := writelogObj.LogQueue.Pop;
        WCount := 0;
        while msg <> nil do
        begin
          try
            writelogObj.WriteLog(msg);
          except
            on E: Exception do
            begin
              Inc(WCount);
              if WCount < 20 then
              begin
                writelogObj.LogQueue.Push(msg);
                Sleep(10);
                msg := writelogObj.LogQueue.Pop;
                Continue;
              end
              else
              begin
                Dispose(PLogMessage(msg));
                raise Exception.Create(E.Message);
              end;
            end;
          end;
          Dispose(PLogMessage(msg));
          msg := writelogObj.LogQueue.Pop;
        end;
      except
        on E: Exception do
        begin
          writelogObj.AddLog('WriteLogʧ��:' + E.Message, 'WriteLogError');
        end;
      end;
      Sleep(100);
    end;
  finally
    CanExit := True;
  end;
end;

end.

