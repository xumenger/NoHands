{支持指定输出文件后缀名，默认是.log
 支持指定写日志方式：同步还是异步(新建线程)，默认是同步方式}
unit U_Log;

interface

uses SysUtils, Classes, IniFiles, U_List, U_Queue, Windows, StrUtils;

type
  //日志信息
  PLogMessage = ^TLogMessage;
  TLogMessage = record
    isDetail: Boolean;          //是否输出包含时间、线程号等的详细信息
    MsgType: string;            //消息类型
    Msg: string;                //消息内容
    LogLevel: Integer;          //日志级别
    LogTime: TDateTime;         //添加日志时间
    CurrentThreadID: string;    //记录日志的线程号
  end;

  //日志文件
  PLogFile = ^TLogFile;
  TLogFile = record
    FileName: string;           //日志文件名
    MaxSize: Double;            //日志文件最大Size
    Sequence: Integer;
    LastCheckTime: Cardinal;
    FileHandle: Cardinal;       //文件句柄
    SFileDate: string;
  end;

  TLog = class;
  
  //写日志线程
  TWriteLogThread = class(TThread)
  public
    writelogObj: TLog;
    CanExit: Boolean;
  protected
    procedure Execute; override;
  end;

  //写日志类
  TLog = class(TObject)
  private
    FLogFilePath: string;   //日志文件路径
    FFileNameHead: string;  //日志文件名的头部
    FLogLevel: Integer;     //当前日志级别
    FIsSync: Boolean;       //是否同步写日志（同步：不新建线程、异步：新建线程）
    FSuffix: string;        //输出文件后缀
    FWriteLogThread: TWriteLogThread; //写日志线程
    FLogFileMaxSize: Double;          //最大文件大小，单位M
    FLogFileList: TStrOrderList;
  public
    LogQueue: TLockQueue;   //日志数据队列
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

//添加要写的日志信息，日志类型（日志文件名的第二部分），日志信息，日志级别，是否输出详细信息
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
      msg.Msg := '写日志时Format出错,StrFormat=[' + StrFormat + ']';
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
    aLogFile.LastCheckTime := 0; //刚刚打开的文件也需要判断是否超过文件最大值
    aLogFile.SFileDate := FormatDateTime('YYYY-MM-DD', Now);
    aLogFile.FileName := FileName + '_' + aLogFile.SFileDate + '.' + FSuffix;
    if not FileExists(aLogFile.FileName) then //如果不存在则创建
    begin
      aLogFile.FileHandle := FileCreate(aLogFile.FileName); //直接创建的文件不能设置共享模式，关闭再用打开的模式
      FileClose(aLogFile.FileHandle);
    end;
    aLogFile.FileHandle := FileOpen(aLogFile.FileName, fmOpenWrite or fmShareDenyNone); //打开文件
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
  //判断日志文件大小是否超过最大值
  if GetTickCount - aLogFile.LastCheckTime > 60000 then
  begin
    //FindFirst不能获取正在使用文件的大小
    //FindFirst(aLogFile.FileName, faAnyFile, aSearchRec);
    iFileSize := GetFileSize(aLogFile.FileHandle, nil);
    if iFileSize > aLogFile.MaxSize * 1048576 then //100M大小
    begin
      FileClose(aLogFile.FileHandle);
      while True do //判断重命名目标文件是否已经存在，若存在，日志文件序号加1
      begin
        if not FileExists(FileName + '_' + aLogFile.SFileDate + '_' + inttostr(aLogFile.Sequence) + '.' + FSuffix) then
        begin
          Break;
        end;
        Inc(aLogFile.Sequence);
      end;
      RenameFile(aLogFile.FileName, FileName + '_' + aLogFile.SFileDate + '_' + inttostr(aLogFile.Sequence) + '.' + FSuffix); //重命名
      Inc(aLogFile.Sequence);
      if not FileExists(aLogFile.FileName) then //如果不存在则创建
      begin
        aLogFile.FileHandle := FileCreate(aLogFile.FileName);
        FileClose(aLogFile.FileHandle);
      end;
      aLogFile.FileHandle := FileOpen(aLogFile.FileName, fmOpenWrite or fmShareDenyNone); //打开文件
      if (-1 = aLogFile.FileHandle) then
      begin
        RaiseLastOSError;
      end;
    end;
    aLogFile.LastCheckTime := GetTickCount;
  end;
  //判断日期是否改变
  if aLogFile.SFileDate <> FormatDateTime('YYYY-MM-DD', Now) then
  begin
    FileClose(aLogFile.FileHandle); //关闭文件
    aLogFile.Sequence := 1;         //日志文件序号置1
    aLogFile.SFileDate := FormatDateTime('YYYY-MM-DD', Now);
    aLogFile.FileName := FileName + '_' + aLogFile.SFileDate + '.' + FSuffix;
    
    //如果不存在则创建
    if not FileExists(aLogFile.FileName) then
    begin
      aLogFile.FileHandle := FileCreate(aLogFile.FileName);
      FileClose(aLogFile.FileHandle);
    end;
    aLogFile.FileHandle := FileOpen(aLogFile.FileName, fmOpenWrite or fmShareDenyNone); //打开文件
    if (-1 = aLogFile.FileHandle) then
    begin
      RaiseLastOSError;
    end;
  end;
  //开始写
  if msg.isDetail then
  begin
    s := FormatDateTime('hhmmss.zzz', msg.LogTime) + '[' + IntToStr(msg.LogLevel) + '][' + msg.CurrentThreadID + ']: ' + msg.Msg + #13#10;
  end
  else
  begin
    s := msg.Msg + #13#10;
  end;
  FileSeek(aLogFile.FileHandle, 0, 2);              //定位到文件末尾
  FileWrite(aLogFile.FileHandle, s[1], Length(s));  //追加数据
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
          writelogObj.AddLog('WriteLog失败:' + E.Message, 'WriteLogError');
        end;
      end;
      Sleep(100);
    end;
  finally
    CanExit := True;
  end;
end;

end.

