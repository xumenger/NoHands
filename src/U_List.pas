unit U_List;

interface

uses Windows, Math, Classes, Contnrs, SysUtils;

type
  POrderListNode = ^TOrderListNode;
  TOrderListNode = record
    Left: POrderListNode;   //左结点
    Right: POrderListNode;  //右结点
    Key: Int64;     //键值
    Data: Pointer;  //数据
  end;
  
  TOrderList = class
  private
    FLock: TRTLCriticalSection;
    FList: TList;
    function GetCount: Integer;
    function GetItems(index: Integer): POrderListNode;
    procedure SetItems(index: Integer; Node: POrderListNode);
    function Search(var Key: Int64; var Node: POrderListNode; iLeft, iRight: Integer): Boolean; overload;
  public
    constructor Create;
    destructor Destroy; override;
    property Count: Integer read GetCount;
    property Items[index: Integer]: POrderListNode read GetItems write SetItems;
    procedure Lock;
    procedure UnLock;
    function Search(Key: Int64; var Node: POrderListNode): Boolean; overload;
    function FindPos(Key: Int64; var Node: POrderListNode): Int64;
    function Insert(Key: Int64; Data: Pointer): Boolean;
    function Delete(Key: Int64): Boolean; overload;
    function Delete(Key: Int64; Delete: Boolean): Boolean; overload;
    function Delete2(Key: Int64): Pointer;
    function ClearWithFreeData: Integer;
    procedure Clear;
  end;

  PStrOrderListNode = ^TStrOrderListNode;
  TStrOrderListNode = record
    Left: PStrOrderListNode;  //左结点
    Right: PStrOrderListNode; //右结点
    Key: string;    //键值
    Data: Pointer;  //数据
  end;

  TStrOrderList = class
  private
    FLock: TRTLCriticalSection;
    FList: TList;
    function GetCount: Integer;
    function GetItems(index: Integer): PStrOrderListNode;
    procedure SetItems(index: Integer; Node: PStrOrderListNode);
    function Search(Key: string; var iPos: Int64; var Node: PStrOrderListNode; iLeft, iRight: Integer): Boolean; overload;
  public
    constructor Create;
    destructor Destroy; override;
    property Count: Integer read GetCount;
    property Items[index: Integer]: PStrOrderListNode read GetItems write SetItems;
    procedure Lock;
    procedure UnLock;
    function FindPos(Key: string; var Node: PStrOrderListNode): Int64;
    function Search(Key: string; var Node: PStrOrderListNode): Boolean; overload;

    function Insert(Key: string; Data: Pointer): Boolean;
    function Delete(Key: string): Boolean; overload;
    function Delete(Key: string; Delete: Boolean): Boolean; overload;
    function ClearWithFreeData: Integer;
    procedure Clear;
  end;
  
implementation

{TOrderList}

constructor TOrderList.Create;
begin
  InitializeCriticalSection(FLock);
  FList := TList.Create;
end;

destructor TOrderList.Destroy;
begin
  while FList.Count > 0 do
  begin
    Dispose(POrderListNode(FList.Items[0])^.Data);
    Dispose(FList.Items[0]);
    FList.Delete(0);
  end;
  DeleteCriticalSection(FLock);
  inherited;
end;

function TOrderList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TOrderList.GetItems(index: Integer): POrderListNode;
begin
  Result := FList.Items[index];
end;

procedure TOrderList.SetItems(index: Integer; Node: POrderListNode);
begin
  FList.Items[index] := Node;
end;

procedure TOrderList.Lock;
begin
  EnterCriticalSection(FLock);
end;

procedure TOrderList.UnLock;
begin
  LeaveCriticalSection(FLock);
end;

function TOrderList.Search(var Key: Int64; var Node: POrderListNode; iLeft, iRight: Integer): Boolean;
var
  iMid: Integer;
begin
  if iRight < iLeft then
  begin
    Node := nil;
    Key := -1;
    Result := False;
  end
  else if Key = POrderListNode(FList.Items[iLeft])^.Key then
  begin
    Node := FList.Items[iLeft];
    Key := iLeft;
    Result := True;
  end
  else if Key = POrderListNode(FList.Items[iRight])^.Key then
  begin
    Node := FList.Items[iRight];
    Key := iRight;
    Result := True;
  end
  else if Key < POrderListNode(FList.Items[iLeft])^.Key then
  begin
    Node := POrderListNode(FList.Items[iLeft])^.Left;
    Key := iLeft - 1;
    Result := False;
  end
  else if Key > POrderListNode(FList.Items[iRight])^.Key then
  begin
    Node := FList.Items[iRight];
    Key := iRight;
    Result := False;
  end
  else if iLeft >= iRight - 1 then
  begin
    Node := FList.Items[iLeft];
    Key := iLeft;
    Result := False;
  end
  else
  begin
    iMid := (iLeft + iRight) div 2;
    if Key < POrderListNode(FList.Items[iMid])^.Key then
    begin
      Result := Search(Key, Node, iLeft, iMid - 1)
    end
    else if Key > POrderListNode(FList.Items[iMid])^.Key then
    begin
      Result := Search(Key, Node, iMid, iRight)
    end
    else
    begin
      Node := FList.Items[iMid];
      Key := iMid;
      Result := True;
    end;
  end;
end;

function TOrderList.Search(Key: Int64; var Node: POrderListNode): Boolean;
begin
  Node := nil;
  if FList.Count = 0 then
  begin
    Result := False
  end
  else
  begin
    Result := Search(Key, Node, 0, FList.Count - 1);
  end;
end;

function TOrderList.Insert(Key: Int64; Data: Pointer): Boolean;
var
  pTmpNode: POrderListNode;
  pNode: POrderListNode;
  iTmp: Int64;
begin
  Result := False;
  iTmp := Key;
  if not Search(iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if (pTmpNode = nil) then
    begin
      new(pNode);
      pNode^.Data := Data;
      pNode^.Key := Key;
      pNode^.Left := nil;
      if FList.Count > 0 then
      begin
        pNode^.Right := FList.Items[0];
        POrderListNode(FList.Items[0])^.Left := pNode;
      end
      else
      begin
        pNode^.Right := nil;
      end;
      FList.Insert(0, pNode);
    end
    else
    begin
      new(pNode);
      pNode^.Data := Data;
      pNode^.Key := Key;
      pNode^.Left := pTmpNode;
      pNode^.Right := pTmpNode^.Right;
      pTmpNode^.Right := pNode;
      if pNode^.Right <> nil then
      begin
        pNode^.Right^.Left := pNode;
      end;
      FList.Insert(iTmp + 1, pNode);
    end;
    Result := True;
  end;
end;

function TOrderList.Delete(Key: Int64): Boolean;
var
  pTmpNode: POrderListNode;
  iTmp: Int64;
begin
  Result := False;
  iTmp := Key;
  if Search(iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if pTmpNode^.Right <> nil then
    begin
      pTmpNode^.Right^.Left := pTmpNode^.Left;
    end;
    if pTmpNode^.Left <> nil then
    begin
      pTmpNode^.Left^.Right := pTmpNode^.Right;
    end;
    Dispose(pTmpNode.Data);
    Dispose(pTmpNode);
    FList.Delete(iTmp);
    Result := True;
  end;
end;

function TOrderList.Delete2(Key: Int64): Pointer;
var
  pTmpNode: POrderListNode;
  iTmp: Int64;
begin
  Result := nil;
  iTmp := Key;
  if Search(iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if pTmpNode^.Right <> nil then
    begin
      pTmpNode^.Right^.Left := pTmpNode^.Left;
    end;
    if pTmpNode^.Left <> nil then
    begin
      pTmpNode^.Left^.Right := pTmpNode^.Right;
    end;
    Result := pTmpNode.Data;
    Dispose(pTmpNode);
    FList.Delete(iTmp);
  end;
end;    

function TOrderList.ClearWithFreeData: Integer;
var
  i: Integer;
begin
  i := 0;
  while FList.Count > 0 do
  begin
    Dispose(POrderListNode(FList.Items[0])^.Data);
    Dispose(FList.Items[0]);
    FList.Delete(0);
    Inc(i);
  end;
  Result := i;
end;

{TStrOrderList}

constructor TStrOrderList.Create;
begin
  InitializeCriticalSection(FLock);
  FList := TList.Create;
end;

destructor TStrOrderList.Destroy;
begin
  while FList.Count > 0 do
  begin
    Dispose(PStrOrderListNode(FList.Items[0])^.Data);
    Dispose(FList.Items[0]);
    FList.Delete(0);
  end;
  DeleteCriticalSection(FLock);
  inherited;
end;

function TStrOrderList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TStrOrderList.GetItems(index: Integer): PStrOrderListNode;
begin
  Result := FList.Items[index];
end;

procedure TStrOrderList.SetItems(index: Integer; Node: PStrOrderListNode);
begin
  FList.Items[index] := Node;
end;

procedure TStrOrderList.Lock;
begin
  EnterCriticalSection(FLock);
end;

procedure TStrOrderList.UnLock;
begin
  LeaveCriticalSection(FLock);
end;

function TStrOrderList.Search(Key: string; var iPos: Int64; var Node: PStrOrderListNode; iLeft, iRight: Integer): Boolean;
var
  iMid: Integer;
begin
  if iRight < iLeft then
  begin
    Node := nil;
    iPos := -1;
    Result := False;
  end
  else if Key = PStrOrderListNode(FList.Items[iLeft])^.Key then
  begin
    Node := FList.Items[iLeft];
    iPos := iLeft;
    Result := True;
  end
  else if Key = PStrOrderListNode(FList.Items[iRight])^.Key then
  begin
    Node := FList.Items[iRight];
    iPos := iRight;
    Result := True;
  end
  else if Key < PStrOrderListNode(FList.Items[iLeft])^.Key then
  begin
    Node := PStrOrderListNode(FList.Items[iLeft])^.Left;
    iPos := iLeft - 1;
    Result := False;
  end
  else if Key > PStrOrderListNode(FList.Items[iRight])^.Key then
  begin
    Node := FList.Items[iRight];
    iPos := iRight;
    Result := False;
  end
  else if iLeft >= iRight - 1 then
  begin
    Node := FList.Items[iLeft];
    iPos := iLeft;
    Result := False;
  end
  else
  begin
    iMid := (iLeft + iRight) div 2;
    if Key < PStrOrderListNode(FList.Items[iMid])^.Key then
    begin
      Result := Search(Key, iPos, Node, iLeft, iMid - 1)
    end
    else if Key > PStrOrderListNode(FList.Items[iMid])^.Key then
    begin
      Result := Search(Key, iPos, Node, iMid, iRight)
    end
    else
    begin
      Node := FList.Items[iMid];
      iPos := iMid;
      Result := True;
    end;
  end;
end;

function TStrOrderList.Search(Key: string; var Node: PStrOrderListNode): Boolean;
var
  iTmp: Int64;
begin
  iTmp := 0;
  Node := nil;
  if FList.Count = 0 then
  begin
    Result := False
  end
  else
  begin
    Result := Search(Key, iTmp, Node, 0, FList.Count - 1);
  end;
end;

function TStrOrderList.FindPos(Key: string; var Node: PStrOrderListNode): Int64;
var
  iTmp: Int64;
begin
  Node := nil;
  if FList.Count = 0 then
  begin
    Result := -1
  end
  else
  begin
    if Search(Key, iTmp, Node, 0, FList.Count - 1) then
    begin
      Result := iTmp
    end
    else
    begin
      Result := -1;
    end;
  end;
end;

function TStrOrderList.Insert(Key: string; Data: Pointer): Boolean;
var
  pTmpNode: PStrOrderListNode;
  pNode: PStrOrderListNode;
  iTmp: Int64;
begin
  Result := False; //没有找到的情况下，才能插入，否则应该报错。（不支持重复主健）
  iTmp := -1;
  if not Search(Key, iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if (pTmpNode = nil) then
    begin
      new(pNode);
      pNode^.Data := Data;
      pNode^.Key := Key;
      pNode^.Left := nil;
      if FList.Count > 0 then
      begin
        pNode^.Right := FList.Items[0];
        PStrOrderListNode(FList.Items[0])^.Left := pNode;
      end
      else
      begin
        pNode^.Right := nil;
      end;
      FList.Insert(0, pNode);
    end
    else
    begin
      new(pNode);
      pNode^.Data := Data;
      pNode^.Key := Key;
      pNode^.Left := pTmpNode;
      pNode^.Right := pTmpNode^.Right;
      pTmpNode^.Right := pNode;
      if pNode^.Right <> nil then
      begin
        pNode^.Right^.Left := pNode;
      end;
      FList.Insert(iTmp + 1, pNode);
    end;
    Result := True;
  end;
end;

function TStrOrderList.Delete(Key: string): Boolean;
var
  pTmpNode: PStrOrderListNode;
  iTmp: Int64;
begin
  Result := False;
  iTmp := -1;
  if Search(Key, iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if pTmpNode^.Right <> nil then
    begin
      pTmpNode^.Right^.Left := pTmpNode^.Left;
    end;
    if pTmpNode^.Left <> nil then
    begin
      pTmpNode^.Left^.Right := pTmpNode^.Right;
    end;
    Dispose(pTmpNode.Data);
    Dispose(pTmpNode);
    FList.Delete(iTmp);
    Result := True;
  end;
end;

function TStrOrderList.ClearWithFreeData: Integer;
var
  i: Integer;
begin
  i := 0;
  while FList.Count > 0 do
  begin
    Dispose(PStrOrderListNode(FList.Items[0])^.Data);
    Dispose(FList.Items[0]);
    FList.Delete(0);
    Inc(i);
  end;
  Result := i;
end;

function TOrderList.FindPos(Key: Int64; var Node: POrderListNode): Int64;
var
  iTmp: Int64;
begin
  Node := nil;
  iTmp := Key;
  if FList.Count = 0 then
  begin
    Result := -1
  end
  else
  begin
    if Search(iTmp, Node, 0, FList.Count - 1) then
    begin
      Result := iTmp
    end
    else
    begin
      Result := -1;
    end;
  end;
end;

function TStrOrderList.Delete(Key: string; Delete: Boolean): Boolean;
var
  pTmpNode: PStrOrderListNode;
  iTmp: Int64;
begin
  Result := False;
  iTmp := -1;
  if Search(Key, iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if pTmpNode^.Right <> nil then
    begin
      pTmpNode^.Right^.Left := pTmpNode^.Left;
    end;
    if pTmpNode^.Left <> nil then
    begin
      pTmpNode^.Left^.Right := pTmpNode^.Right;
    end;
    if Delete then
    begin
      Dispose(pTmpNode.Data);
    end;
    Dispose(pTmpNode);
    FList.Delete(iTmp);
    Result := True;
  end;
end;

function TOrderList.Delete(Key: Int64; Delete: Boolean): Boolean;
var
  pTmpNode: POrderListNode;
  iTmp: Int64;
begin
  Result := False;
  iTmp := Key;
  if Search(iTmp, pTmpNode, 0, FList.Count - 1) then
  begin
    if pTmpNode^.Right <> nil then
    begin
      pTmpNode^.Right^.Left := pTmpNode^.Left;
    end;
    if pTmpNode^.Left <> nil then
    begin
      pTmpNode^.Left^.Right := pTmpNode^.Right;
    end;
    if Delete then
    begin
      Dispose(pTmpNode.Data);
    end;
    Dispose(pTmpNode);
    FList.Delete(iTmp);
    Result := True;
  end;
end;

//清除队列，但不释放队列中的数据
procedure TOrderList.Clear;
begin
  while FList.Count > 0 do
  begin
    Dispose(FList.Items[FList.Count-1]);
    FList.Delete(FList.Count-1);
  end;
end;

procedure TStrOrderList.Clear;
begin
  while FList.Count > 0 do
  begin
    Dispose(PStrOrderListNode(FList.Items[FList.Count-1]));
    FList.Delete(FList.Count-1);
  end;
end;

end.

