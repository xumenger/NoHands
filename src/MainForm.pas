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

  //获取Plugins下面的所有DLL
  pluginPath := ExtractFilePath(Application.ExeName) + 'Plugins\';
  isFound := FindFirst(pluginPath + '*.dll', faAnyFile, SearchRec);
  while isFound = 0 do
  begin
    try
      if (SearchRec.Attr <> faDirectory) then
      begin
        try
          TestName := SearchRec.Name;
          TestName := Copy(TestName, 1, Length(TestName)-4);  //去掉DLL的后缀，只保留DLL名
          FileDescription := GetFileDescription(pluginPath + SearchRec.Name);
          autoTest :=  TAutoTest.Create(TestName, FileDescription);

          AutoTestList.Insert(TestName, autoTest);
        except
          on E: Exception do
          begin
            AddMessage(mtError, '初始化[%s]对应的自动化测试出错：%s', [TestName, E.Message]);
            aLog.AddLog(0, '初始化[%s]对应的自动化测试出错：%s', [TestName, E.Message], LogError);
          end;
        end;
      end;
    finally
      isFound := FindNext(SearchRec);
    end;
  end;
  FindClose(SearchRec);

  //将所有的自动化测试展示到窗体界面上
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

      aLog.AddLog(0, '任务[%s]开始运行', [autoTest.TestDesc]);
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

      aLog.AddLog(0, '任务[%s]结束运行', [autoTest.TestDesc]);
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
      MsgType := '[提示]';
    end
    else if mtWarning = aMsg.MsgType then
    begin
      redtMessage.SelAttributes.Color := clPurple;
      MsgType := '[警告]';
    end
    else if mtError = aMsg.MsgType then
    begin
      redtMessage.SelAttributes.Color := clRed;
      MsgType := '[错误]';    
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
如何将这个简单的窗体、布局使用各种控件画出来？
* Panel
  * 首先使用Panel，以及调整其Align属性为alClient或AlButtom或alTop或alRight来将整个窗体划分不同模块
  * pnlCover（alClient），占据整个窗体
  * pnlControl（pnlCover；alTop），上面是添加功能按钮的区域
  * pnlAutoTest（pnlCover；alLeft），左下是添加任务列表的区域
  * pnlMonitor（pnlCover；alClient），占据剩下的右下部分，用于显示相关提示信息、错误信息
  * pnlMessage（pnlCover2；alBottom），放在在pnlCover2上，整个窗体的右下：自动化测试运行情况的信息输出区域 
* ListView
  * 用于分条展示所有的自动化测试插件的信息
  * 放在左下的Panel上，并将其Align属性设置为alClient将整个左下区域占满
  * ReadOnly数学置为True；RowSelect属性置为True即允许鼠标选中一行
  * 双击Cloumns属性，添加列信息：任务名称、测试进度。将每个Columns的AutoSize置为FALSE，将宽度置为100
  * ViewStyle属性设置为vsReport，这样就可以将列名展示出来
* RichEdit
  * 用于输出必要的提示信息
  * 放在右下的Panel上，并将其Align属性设置为alClient将整个右下区域占满
  * 双击其Lines属性，将其中的值置为''，这样在编译时就不会有碍眼的信息了
  * Font属性-->Size属性设置为10，否则显示的提示信息太小
* SpeedButton
  * 相关的按钮放到上面的Panel上，通过Glyph属性设置按钮对应的图片
  * 第一个按钮：在选中ListView的某个条目后，再点击该按钮，然后该条自动化测试即开始运行
  * 第二个按钮：在选中ListView的某个条目后，再点击该按钮，然后该条自动化测试即停止运行
--------------------------------------------------------------------------------}
