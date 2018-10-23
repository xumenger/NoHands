unit U_AutoTest;

interface
uses
  Windows, SysUtils, StrUtils, Classes, Forms, ActiveX, XMLDoc, XMLIntf, U_DBF, U_Log, U_BaseDefine;

type
  TRunState = (stStop, stRunning, stDone);
  
  TAutoTest = class;

  TTestThread = class(TThread)
  private
    FAutoTest: TAutoTest;
    CanExit: Boolean;
  public
    constructor Create(CreateSuspended: Boolean; AutoTest: TAutoTest);
    destructor Destroy; override;
  protected
    procedure Execute; override;
  private
    procedure GetInputFromDBF(var FuncNo: string; var InPara: string);
    function SaveOutputToDBF(OutPara: string; var TestResult: string): Integer;
  end;

  TAutoTest = class
  public
    constructor Create(TestName: string; TestDesc: string);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  private
    FTestThread: TTestThread;    //测试线程
    FDBF: TDBF;                  //DBF对象
    FLog: TLog;                  //日志对象，目前用于统计测试执行情况
    FDLLModule: THandle;         //DLL模块句柄

    FTestName: string;
    FTestDesc: string;           //自动化测试插件名
    FDLLName: string;            //对应的DLL名

    FDBFName: string;            //对应DBF名（要求DBF名和dll名一致）
    FTotalAmount: Integer;       //测试用例总数
    FTestedAmount: Integer;      //当前测试条数
    FSuccessAmount: Integer;     //测试成功数量
    FFailAmount: Integer;        //测试失败数量

    InitFunc: TIniFunc;          //初始化方法
    CallFunc: TCallFunc;         //输入/输出接口
    FreeFunc: TFreeFunc;         //释放资源函数
  public
    RunState: TRunState;
    property TestDesc: string read FTestDesc;
    property TotalAmount: Integer read FTotalAmount;
    property TestedAmount: Integer read FTestedAmount;
  end;

implementation

//初步设计在自动化测试对象创建时即创建线程、DBF对象
constructor TAutoTest.Create(TestName: string; TestDesc: string);
var
  DLLPath: string;
  DBFPath: string;
  LogPath: string;
begin
  try
    inherited Create;
    FDLLModule := 0;
    FDBF := nil;
    FLog := nil;
    FTestThread := nil;

    RunState := stStop;
    
    FTestName := TestName;
    FTestDesc := TestDesc;
    FDLLName := FTestName + '.dll';
    FDBFName := FTestName + '.dbf';

    //加载DLL，获取DLL名
    try
      DLLPath := ExtractFilePath(Application.ExeName) + 'Plugins\' + FDLLName;
      FDLLModule := LoadLibrary(PChar(DLLPath));
      InitFunc := GetProcAddress(FDLLModule, PChar(const_InitFuncName));  //初始化方法
      CallFunc := GetProcAddress(FDLLModule, PChar(const_CallFuncName));  //调用（IO）方法
      FreeFunc := GetProcAddress(FDLLModule, PChar(const_FreeFuncName));  //释放资源方法
    except
      on E: Exception do
      begin
        raise Exception.CreateFmt('加载DLL时出现异常：%s', [E.Message]);
      end;
    end;

    //打开DBF获取必要信息
    DBFPath := ExtractFilePath(Application.ExeName) + 'TestCases\' + FDBFName;
    if FileExists(DBFPath) then
    begin
      FDBF := TDBF.Create;
      FDBF.TableName := DBFPath;
      FDBF.ReadNoLock := True;
      FDBF.Open;
      FDBF.First;
      FTotalAmount := FDBF.RecordCount;
    end
    else
    begin
      raise Exception.CreateFmt('测试[%s]对应的DBF文件不存在', [FTestName]);
    end;
    FTestedAmount := 0;
    FSuccessAmount := 0;
    FFailAmount := 0;

    //日志
    LogPath := ExtractFilePath(Application.ExeName) + 'TestCases\';
    FLog := TLog.Create(FTestName, True, 'html', LogPath);

    //测试线程
    FTestThread := TTestThread.Create(True, Self);
  except
    on E: Exception do
    begin
      raise Exception.CreateFmt('初始化自动化测试出现异常：%s', [E.Message]);
    end;
  end;
end;

//自测时发现Delphi类生命周期的一个规律：如果在Create中出现异常，那么会自动调用Free（Destroy）
//因为Create中出现异常，所以可能其中的某些类变量还未创建
//所以需要在Destroy中释放资源前判断资源是否在Create中被创建，比如下面判断nil <> FTestThread等
//否则可能在Destroy中释放Create未申请的资源（内存、DLL句柄）而导致在Destroy中出现异常
destructor TAutoTest.Destroy;
var
  iTime: Cardinal;
begin
  try
    if nil <> FTestThread then
    begin
      FTestThread.Terminate;
      iTime := GetTickCount;
      while GetTickCount - iTime < 500 do
      begin
        Sleep(1);
        if FTestThread.CanExit then
        begin
          Break;
        end;
      end;
      FTestThread.Free; 
    end;    
    if nil <> FLog then
    begin
      FLog.Free;
    end;
    if nil <> FDBF then
    begin
      FDBF.Free;
    end;
    if 0 <> FDLLModule then
    begin
      FreeLibrary(FDLLModule);
    end;
    inherited;
  except
    on E: Exception do
    begin
      raise Exception.CreateFmt('释放自动化测试出现异常：%s', [E.Message]);
    end;
  end;
end;

procedure TAutoTest.Start;
begin
  RunState := stRunning;
  FTestThread.Resume;
end;

procedure TAutoTest.Stop;
begin
  RunState := stStop;
  FTestThread.Terminate;
end;

{TTestThread}

constructor TTestThread.Create(CreateSuspended: Boolean; AutoTest: TAutoTest);
begin
  inherited Create(CreateSuspended);
  FAutoTest := AutoTest;
end;

destructor TTestThread.Destroy;
begin
  inherited;
end;

procedure TTestThread.Execute;
var
  isIniSucess: Boolean;
  FuncNo, InPara, OutPara, testResult: string;
  DBFRow: Integer;
begin
  inherited;
  CoInitialize(nil);
  CanExit := False; 
  try
    isIniSucess := False;
    DBFRow := 1;
    FAutoTest.FLog.AddLog('<html>', '', 0, False);
    FAutoTest.FLog.AddLog('<head><title>测试结果</title></head>', '', 0, False);
    FAutoTest.FLog.AddLog('<body>', '', 0, False);
    FAutoTest.FLog.AddLog('<table border="1"><tr><th>用例序号</th><th>测试结果</th><th>详细信息</th></tr>', '', 0, False);

    //先调用初始化方法
    if 0 = FAutoTest.InitFunc() then
    begin
      isIniSucess := True;
      AddMessage(mtHint, '自动化测试[%s]初始化时成功', [FAutoTest.FTestDesc]);
    end
    else
    begin
      AddMessage(mtError, '自动化测试[%s]初始化时出现异常', [FAutoTest.FTestDesc]);
    end;

    //初始化成功后，开始逐个运行测试用例
    if isIniSucess then
    begin
      while not FAutoTest.FDBF.Eof do
      begin
        try
          try
            GetInputFromDBF(FuncNo, InPara);
            OutPara := FAutoTest.CallFunc(PChar(FuncNo), PChar(InPara));
            if 0 = SaveOutputToDBF(OutPara, testResult) then
            begin
              Inc(FAutoTest.FSuccessAmount);
            end
            else
            begin
              Inc(FAutoTest.FFailAmount);
            end;
            FAutoTest.FLog.AddLog(testResult, '', 0, False);

            Sleep(10); 
            if Terminated then
            begin
              Break;
            end;
          except
            on E: Exception do
            begin
              FAutoTest.FLog.AddLog(0, '运行测试用例时出错：%s', [E.Message], LogError, False);
              AddMessage(mtError, '[%s]运行测试用例时出错：%s', [FAutoTest.FTestDesc, E.Message]);
            end;
          end;
        finally
          Inc(FAutoTest.FTestedAmount);
          FAutoTest.FDBF.Next;
        end;
      end;

      FAutoTest.FLog.AddLog('</table>', '', 0, False);
      FAutoTest.FLog.AddLog('</body>', '', 0, False);
      FAutoTest.FLog.AddLog('</html>', '', 0, False);
      FAutoTest.FreeFunc;
    end;
    FAutoTest.FDBF.Close;
    FAutoTest.RunState := stDone;
    AddMessage(mtHint, '自动化测试[%s]运行完成，成功数量：%d， 失败数量：%d',
               [FAutoTest.FTestDesc, FAutoTest.FSuccessAmount, FAutoTest.FFailAmount]);
  finally
    CanExit := True;
    CoUninitialize;
  end;
end;

procedure TTestThread.GetInputFromDBF(var FuncNo: string; var InPara: string);
var
  ComInstrXML: IXMLDocument;
  mainNode, BodyNode, tmpNode: IXMLNode;

  i: Integer;
  FieldName: string;
begin
  FuncNo := FAutoTest.FDBF.FieldByName('FuncNo').AsString;

  ComInstrXML := LoadXMLData(const_XmlDocument);
  mainNode := ComInstrXML.DocumentElement;
  BodyNode := mainNode.AddChild('Body');

  for i:=0 to FAutoTest.FDBF.FieldCount-1 do
  begin
    FieldName := FAutoTest.FDBF.Fields[i].FieldName;
    if 1 = Pos('in_', FieldName) then
    begin
      FieldName := Copy(FieldName, 4, Length(FieldName)-3);   //将域名的'in_'去掉
      tmpNode := BodyNode.AddChild(FieldName);
      tmpNode.Text := FAutoTest.FDBF.FieldByName('in_' + FieldName).AsString
    end;
  end;

  InPara := ComInstrXML.XML.Text;
end;

//返回值：0-测试成功；1-测试失败；2-其他错误
function TTestThread.SaveOutputToDBF(OutPara: string; var TestResult: string): Integer;
var
  ComInstrXML: IXMLDocument;
  mainNode, BodyNode: IXMLNode;
  i: Integer;
  TestNo: string;
  tag, outValue, wantValue: string;
  isSuccess: Boolean;
begin
  try
    isSuccess := True;
    TestNo := '<tr><th>' + IntToStr(FAutoTest.FDBF.RecNo) + '</th>';
    ComInstrXML := LoadXMLData(OutPara);
    mainNode := ComInstrXML.DocumentElement;
    BodyNode := mainNode.ChildNodes['Body'];

    FAutoTest.FDBF.Edit;
    for i:=0 to BodyNode.ChildNodes.Count-1 do
    begin
      tag := BodyNode.ChildNodes[i].NodeName;
      outValue := BodyNode.ChildNodes[i].NodeValue;
      
      //输出XML中的tag转换成'out_tag'找到DBF对应的列，写入对应的值
      FAutoTest.FDBF.FieldByName('out_' + tag).AsString := outValue;
      //获取该用例维护的预期结果
      wantValue := FAutoTest.FDBF.FieldByName('want_' + tag).AsString;
      //用实际输出和预期进行对比
      if (outValue <> wantValue) then
      begin
        isSuccess := False;
        TestResult := TestNo + '<th>失败</th><th>' + tag + '的预期输出是：' + wantValue + '；实际输出是：' + outValue + '</th></tr>';
        Result := 1;
      end;
    end;
    FAutoTest.FDBF.Post;

    if isSuccess then
    begin
      TestResult := TestNo + '<th>成功</th><th></th></tr>';
      Result := 0;
    end;
  except
    on E: Exception do
    begin
      TestResult := TestNo + '<th>失败</th><th>' + E.Message + '</th></tr>';
      Result := 2;
    end;
  end;
end;   

end.
