unit ThreadsListUnit;

interface

uses
  OptionsUnit, Windows, SysUtils, Classes;

type
  TThreadsList = class(TObject)
  private
    fThreads: TThreadList;
    fThreadCount: Integer;
    fEvent: THandle;
  public
    constructor Create;
    destructor Destroy; override;
    function Reserve: Integer;
    procedure Release(Number: Integer);

  end;

var
  ThreadsList: TThreadsList;

implementation

{ TThreadsList }

constructor TThreadsList.Create;
var
  i: Integer;
begin
  fThreads := TThreadList.Create;
  fThreads.Duplicates := dupAccept;

  fThreadCount := Options['Main', 'MaxThreadCount'];
  for i := 0 to fThreadCount - 1 do
    fThreads.Add(Pointer(1));

  fEvent := CreateEvent(nil, False, False, nil);
end;

destructor TThreadsList.Destroy;
begin
  fThreads.Free;
  inherited;
end;

procedure TThreadsList.Release(Number: Integer);
var
  i: Integer;
  c: Char;
begin
  with fThreads.LockList do
  begin
    Items[Number] := Pointer(1);
    Write(#13);
    for i := 0 to fThreadCount - 1 do
    begin
      if Items[i] = Pointer(1) then
        c := '_'//#176
      else
        c := #177;
      Write(#32, c);
    end;
  end;
  fThreads.UnlockList;
  SetEvent(fEvent); //We have at least one place for new threads
end;

function TThreadsList.Reserve: Integer;
var
  i: Integer;
begin
  Result := -1;
  while True do
  begin
    with fThreads.LockList do
      for i := 0 to fThreadCount - 1 do
        if Items[i] = Pointer(1) then
        begin
          Result := i;
          Break;
        end;
    fThreads.UnlockList;
    if Result = -1 then //It seems all places are busy :(
    begin
      if WaitForSingleObject(fEvent, INFINITE) = WAIT_TIMEOUT then
        raise Exception.Create('Deadlocked'); //We must wait for a free place
    end
    else
      Break;
  end;
  with fThreads.LockList do
    Items[Result] := Pointer(2); //Mark the place BUSY
  fThreads.UnlockList;
end;

end.
