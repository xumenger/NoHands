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
    FTestThread: TTestThread;    //�����߳�
    FDBF: TDBF;                  //DBF����
    FLog: TLog;                  //��־����Ŀǰ����ͳ�Ʋ���ִ�����
    FDLLModule: THandle;         //DLLģ����

    FTestName: string;
    FTestDesc: string;           //�Զ������Բ����
    FDLLName: string;            //��Ӧ��DLL��

    FDBFName: string;            //��ӦDBF����Ҫ��DBF����dll��һ�£�
    FTotalAmount: Integer;       //������������
    FTestedAmount: Integer;      //��ǰ��������
    FSuccessAmount: Integer;     //���Գɹ�����
    FFailAmount: Integer;        //����ʧ������

    InitFunc: TIniFunc;          //��ʼ������
    CallFunc: TCallFunc;         //����/����ӿ�
    FreeFunc: TFreeFunc;         //�ͷ���Դ����
  public
    RunState: TRunState;
    property TestDesc: string read FTestDesc;
    property TotalAmount: Integer read FTotalAmount;
    property TestedAmount: Integer read FTestedAmount;
  end;

implementation

//����������Զ������Զ��󴴽�ʱ�������̡߳�DBF����
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

    //����DLL����ȡDLL��
    try
      DLLPath := ExtractFilePath(Application.ExeName) + 'Plugins\' + FDLLName;
      FDLLModule := LoadLibrary(PChar(DLLPath));
      InitFunc := GetProcAddress(FDLLModule, PChar(const_InitFuncName));  //��ʼ������
      CallFunc := GetProcAddress(FDLLModule, PChar(const_CallFuncName));  //���ã�IO������
      FreeFunc := GetProcAddress(FDLLModule, PChar(const_FreeFuncName));  //�ͷ���Դ����
    except
      on E: Exception do
      begin
        raise Exception.CreateFmt('����DLLʱ�����쳣��%s', [E.Message]);
      end;
    end;

    //��DBF��ȡ��Ҫ��Ϣ
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
      raise Exception.CreateFmt('����[%s]��Ӧ��DBF�ļ�������', [FTestName]);
    end;
    FTestedAmount := 0;
    FSuccessAmount := 0;
    FFailAmount := 0;

    //��־
    LogPath := ExtractFilePath(Application.ExeName) + 'TestCases\';
    FLog := TLog.Create(FTestName, True, 'html', LogPath);

    //�����߳�
    FTestThread := TTestThread.Create(True, Self);
  except
    on E: Exception do
    begin
      raise Exception.CreateFmt('��ʼ���Զ������Գ����쳣��%s', [E.Message]);
    end;
  end;
end;

//�Բ�ʱ����Delphi���������ڵ�һ�����ɣ������Create�г����쳣����ô���Զ�����Free��Destroy��
//��ΪCreate�г����쳣�����Կ������е�ĳЩ�������δ����
//������Ҫ��Destroy���ͷ���Դǰ�ж���Դ�Ƿ���Create�б����������������ж�nil <> FTestThread��
//���������Destroy���ͷ�Createδ�������Դ���ڴ桢DLL�������������Destroy�г����쳣
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
      raise Exception.CreateFmt('�ͷ��Զ������Գ����쳣��%s', [E.Message]);
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
    FAutoTest.FLog.AddLog('<head><title>���Խ��</title></head>', '', 0, False);
    FAutoTest.FLog.AddLog('<body>', '', 0, False);
    FAutoTest.FLog.AddLog('<table border="1"><tr><th>�������</th><th>���Խ��</th><th>��ϸ��Ϣ</th></tr>', '', 0, False);

    //�ȵ��ó�ʼ������
    if 0 = FAutoTest.InitFunc() then
    begin
      isIniSucess := True;
      AddMessage(mtHint, '�Զ�������[%s]��ʼ��ʱ�ɹ�', [FAutoTest.FTestDesc]);
    end
    else
    begin
      AddMessage(mtError, '�Զ�������[%s]��ʼ��ʱ�����쳣', [FAutoTest.FTestDesc]);
    end;

    //��ʼ���ɹ��󣬿�ʼ������в�������
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
              FAutoTest.FLog.AddLog(0, '���в�������ʱ����%s', [E.Message], LogError, False);
              AddMessage(mtError, '[%s]���в�������ʱ����%s', [FAutoTest.FTestDesc, E.Message]);
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
    AddMessage(mtHint, '�Զ�������[%s]������ɣ��ɹ�������%d�� ʧ��������%d',
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
      FieldName := Copy(FieldName, 4, Length(FieldName)-3);   //��������'in_'ȥ��
      tmpNode := BodyNode.AddChild(FieldName);
      tmpNode.Text := FAutoTest.FDBF.FieldByName('in_' + FieldName).AsString
    end;
  end;

  InPara := ComInstrXML.XML.Text;
end;

//����ֵ��0-���Գɹ���1-����ʧ�ܣ�2-��������
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
      
      //���XML�е�tagת����'out_tag'�ҵ�DBF��Ӧ���У�д���Ӧ��ֵ
      FAutoTest.FDBF.FieldByName('out_' + tag).AsString := outValue;
      //��ȡ������ά����Ԥ�ڽ��
      wantValue := FAutoTest.FDBF.FieldByName('want_' + tag).AsString;
      //��ʵ�������Ԥ�ڽ��жԱ�
      if (outValue <> wantValue) then
      begin
        isSuccess := False;
        TestResult := TestNo + '<th>ʧ��</th><th>' + tag + '��Ԥ������ǣ�' + wantValue + '��ʵ������ǣ�' + outValue + '</th></tr>';
        Result := 1;
      end;
    end;
    FAutoTest.FDBF.Post;

    if isSuccess then
    begin
      TestResult := TestNo + '<th>�ɹ�</th><th></th></tr>';
      Result := 0;
    end;
  except
    on E: Exception do
    begin
      TestResult := TestNo + '<th>ʧ��</th><th>' + E.Message + '</th></tr>';
      Result := 2;
    end;
  end;
end;   

end.
