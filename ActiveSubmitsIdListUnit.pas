unit ActiveSubmitsIdListUnit;

interface

uses
  Classes, SysUtils, Windows;

type
  TActiveSubmitsIdList = class(TThreadList)
  public
    constructor Create;
    procedure Add(Id: Integer); reintroduce;
    procedure Remove(Id: Integer); reintroduce;
    function MakeString: string;
  end;

var
  ActiveSubmitsIdList: TActiveSubmitsIdList;

implementation

{ TActiveSubmitsIdList }

procedure TActiveSubmitsIdList.Add(Id: Integer);
begin
  try
    inherited Add(Pointer(Id));
  except
    on e: Exception do
    begin
      raise Exception.Create(e.Message + ' List content: ' + Self.MakeString());
    end;
  end;
end;

constructor TActiveSubmitsIdList.Create;
begin
  inherited;
  Self.Duplicates := dupError;
end;

procedure TActiveSubmitsIdList.Remove(Id: Integer);
var
  i: Integer;
begin
  inherited Remove(Pointer(Id));
{  with Self.LockList do
  begin
    Write(#13);
    for I := 0 to Count - 1 do
    begin
      Write(Integer(Items[i]), ',');
    end;
    Write('                                          ');
  end;
  Self.UnlockList;}
end;

function TActiveSubmitsIdList.MakeString: string;
var
  i: Integer;
begin
  result := '';
  with Self.LockList do
    for i := 0 to Count - 1 do
      result := result + ',' + IntToStr(Integer(Items[i]));
  result := '0' + result;
  Self.UnlockList;
end;

end.
