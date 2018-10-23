unit Main;

interface
uses
  Windows, XMLDoc, XMLIntf, SysUtils, StrUtils;

const
  const_XmlDocument = '<?xml version="1.0" encoding="utf-8"?><Document></Document>';

function Init(): Integer; stdcall; export;
function Call(FuncNo: string; InPara: PChar): PChar; stdcall; export;
function Release(): Integer; stdcall; export;

function CallPos(InPara: PChar): PChar;

implementation

function Init(): Integer; 
begin
  //������ӱȽϼ򵥣���ʼ������ʲô������Ҫ��
  Result := 0;
end;

function Call(FuncNo: string; InPara: PChar): PChar; 
begin
  if 'CallPos' = FuncNo then
  begin
    Result := CallPos(InPara);
  end
  else
  begin
    //...
  end;
end;

function Release(): Integer;
begin
  //������ӱȽϼ򵥣��ͷ���Դ����ʲô������Ҫ��
  Result := 0;
end;

function CallPos(InPara: PChar): PChar;
var
  ComInstrXML: IXMLDocument;
  mainNode, bodyNode: IXMLNode;

  subStr, Str: string;
  position: Integer;

  posNode: IXMLNode;
begin
//��������XML
  ComInstrXML := LoadXMLData(InPara);
  mainNode := ComInstrXML.DocumentElement;
  bodyNode := mainNode.ChildNodes['Body'];

  subStr := bodyNode.ChildNodes['substr'].NodeValue;
  Str := bodyNode.ChildNodes['str'].NodeValue;

//����Pos����
  position := Pos(subStr, Str);

//���������
  ComInstrXML := LoadXMLData(const_XmlDocument);
  mainNode := ComInstrXML.DocumentElement;
  BodyNode := mainNode.AddChild('Body');
  posNode := BodyNode.AddChild('pos');
  posNode.Text := IntToStr(position);

  Result := PChar(ComInstrXML.XML.Text);
end;

end.
