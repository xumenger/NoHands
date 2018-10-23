unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ExtCtrls, ToolWin, StdCtrls, Menus, ImgList, Buttons,
  U_List, U_Queue, U_Log, U_AutoTest, U_BaseDefine;

type
  TTestForm = class(TForm)
    pnlCover: TPanel;
    pnlControl: TPanel;
    pnlAutoTest: TPanel;
    pnlMonitor: TPanel;
    lvAutoTest: TListView;
    btnStart: TSpeedButton;
    btnEnd: TSpeedButton;
    tmrMointor: TTimer;
    redtMessage: TRichEdit;
    tmrMessage: TTimer;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnStartClick(Sender: TObject);
    procedure btnEndClick(Sender: TObject);
    procedure tmrMointorTimer(Sender: TObject);
    procedure tmrMessageTimer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  TestForm: TTestForm;
  AutoTestList: TStrOrderList;
  aLog: TLog;

implementation

{$R *.dfm}

procedure TTestForm.FormShow(Sender: TObject);
var
  autoTest: TAutoTest;
  pluginPath: string;

  isFound: Integer;
  SearchRec: TSearchRec;
  TestName: string;
  FileDescription: string;
  listItem: TListItem;

  i: Integer;
begin
  autoTestList := TStrOrderList.Create;
  MsgQueue := TLockQueue.Create;
  aLog := TLog.Create('AutoTest', False);

  //��ȡPlugins���������DLL
  pluginPath := ExtractFilePath(Application.ExeName) + 'Plugins\';
  isFound := FindFirst(pluginPath + '*.dll', faAnyFile, SearchRec);
  while isFound = 0 do
  begin
    try
      if (SearchRec.Attr <> faDirectory) then
      begin
        try
          TestName := SearchRec.Name;
          TestName := Copy(TestName, 1, Length(TestName)-4);  //ȥ��DLL�ĺ�׺��ֻ����DLL��
          FileDescription := GetFileDescription(pluginPath + SearchRec.Name);
          autoTest :=  TAutoTest.Create(TestName, FileDescription);

          AutoTestList.Insert(TestName, autoTest);
        except
          on E: Exception do
          begin
            AddMessage(mtError, '��ʼ��[%s]��Ӧ���Զ������Գ���%s', [TestName, E.Message]);
            aLog.AddLog(0, '��ʼ��[%s]��Ӧ���Զ������Գ���%s', [TestName, E.Message], LogError);
          end;
        end;
      end;
    finally
      isFound := FindNext(SearchRec);
    end;
  end;
  FindClose(SearchRec);

  //�����е��Զ�������չʾ�����������
  for i:=0 to AutoTestList.Count-1 do
  begin
    autoTest := AutoTestList.Items[i].Data;
    listItem := lvAutoTest.Items.Add;
    listItem.Caption := autoTest.TestDesc;
    listItem.SubItems.Add('0/' + IntToStr(autoTest.TotalAmount));
  end;
end;

procedure TTestForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
  i: Integer;
  autoTest: TAutoTest;
begin
  for i:=0 to AutoTestList.Count-1 do
  begin
    autoTest := autoTestList.Items[i].Data;
    autoTest.Free;
  end;

  AutoTestList.Clear;
  AutoTestList.Free;
  MsgQueue.Free;
  aLog.Free;
end;

procedure TTestForm.btnStartClick(Sender: TObject);
var                   
  index: Integer;
  autoTest: TAutoTest;
begin
  if nil <> lvAutoTest.ItemFocused then
  begin
    index := lvAutoTest.ItemFocused.Index;
    autoTest := AutoTestList.Items[index].Data;
    if stDone <> autoTest.RunState then
    begin
      autoTest.Start;

      aLog.AddLog(0, '����[%s]��ʼ����', [autoTest.TestDesc]);
    end;
  end;
end;

procedure TTestForm.btnEndClick(Sender: TObject);
var
  index: Integer;
  autoTest: TAutoTest;
begin
  if nil <> lvAutoTest.ItemFocused then
  begin
    index := lvAutoTest.ItemFocused.Index;
    autoTest := AutoTestList.Items[index].Data;

    if stRunning = autoTest.RunState then
    begin
      autoTest.Stop;

      aLog.AddLog(0, '����[%s]��������', [autoTest.TestDesc]);
    end;
  end;
end;

procedure TTestForm.tmrMointorTimer(Sender: TObject);
var
  autoTest: TAutoTest;
  i: Integer;
begin
  for i:=0 to AutoTestList.Count-1 do
  begin
    autoTest := AutoTestList.Items[i].Data;
    if stStop <> autoTest.RunState then
    begin
      lvAutoTest.Items[i].SubItems[0] := IntToStr(autoTest.TestedAmount) + '/' + IntToStr(autoTest.TotalAmount);
    end;
  end;
end;

procedure TTestForm.tmrMessageTimer(Sender: TObject);
var
  aMsg: PMessage;
  MsgType: string;
  MsgContent: string;
begin
  aMsg := MsgQueue.Pop;
  if nil <> aMsg then
  begin
    if mtHint = aMsg.MsgType then
    begin
      redtMessage.SelAttributes.Color := clGreen;
      MsgType := '[��ʾ]';
    end
    else if mtWarning = aMsg.MsgType then
    begin
      redtMessage.SelAttributes.Color := clPurple;
      MsgType := '[����]';
    end
    else if mtError = aMsg.MsgType then
    begin
      redtMessage.SelAttributes.Color := clRed;
      MsgType := '[����]';    
    end;

    MsgType := MsgType + FormatDateTime('hh:nn:ss', Now());
    MsgContent := MsgType + '--->' + aMsg.Content;
    redtMessage.Lines.Add(MsgContent);
    aLog.AddLog(0, '%s', [MsgContent]);
    
    Dispose(aMsg);
  end
  else
  begin
    Application.ProcessMessages;
  end;
end;

end.

{-------------------------------------------------------------------------------
��ν�����򵥵Ĵ��塢����ʹ�ø��ֿؼ���������
* Panel
  * ����ʹ��Panel���Լ�������Align����ΪalClient��AlButtom��alTop��alRight�����������廮�ֲ�ͬģ��
  * pnlCover��alClient����ռ����������
  * pnlControl��pnlCover��alTop������������ӹ��ܰ�ť������
  * pnlAutoTest��pnlCover��alLeft������������������б������
  * pnlMonitor��pnlCover��alClient����ռ��ʣ�µ����²��֣�������ʾ�����ʾ��Ϣ��������Ϣ
  * pnlMessage��pnlCover2��alBottom����������pnlCover2�ϣ�������������£��Զ������������������Ϣ������� 
* ListView
  * ���ڷ���չʾ���е��Զ������Բ������Ϣ
  * �������µ�Panel�ϣ�������Align��������ΪalClient��������������ռ��
  * ReadOnly��ѧ��ΪTrue��RowSelect������ΪTrue���������ѡ��һ��
  * ˫��Cloumns���ԣ��������Ϣ���������ơ����Խ��ȡ���ÿ��Columns��AutoSize��ΪFALSE���������Ϊ100
  * ViewStyle��������ΪvsReport�������Ϳ��Խ�����չʾ����
* RichEdit
  * ���������Ҫ����ʾ��Ϣ
  * �������µ�Panel�ϣ�������Align��������ΪalClient��������������ռ��
  * ˫����Lines���ԣ������е�ֵ��Ϊ''�������ڱ���ʱ�Ͳ����а��۵���Ϣ��
  * Font����-->Size��������Ϊ10��������ʾ����ʾ��Ϣ̫С
* SpeedButton
  * ��صİ�ť�ŵ������Panel�ϣ�ͨ��Glyph�������ð�ť��Ӧ��ͼƬ
  * ��һ����ť����ѡ��ListView��ĳ����Ŀ���ٵ���ð�ť��Ȼ������Զ������Լ���ʼ����
  * �ڶ�����ť����ѡ��ListView��ĳ����Ŀ���ٵ���ð�ť��Ȼ������Զ������Լ�ֹͣ����
--------------------------------------------------------------------------------}
