unit uGridFilters;

interface

uses
  Vcl.Controls, JvDBUltimGrid, System.Classes, JvSecretPanel, Vcl.ExtCtrls,JvDBGrid
  ,Spring.Collections,Vcl.StdCtrls,Data.DB,Vcl.Graphics,Vcl.Menus
  , Vcl.ActnList;

const
  clrActiveEdit=$00CDFFFF;
  clrPasiveEdit=$00E7FFE4;

type
  IFullMenuService=interface(IInterface)
    ['{89B188B6-AB57-404C-818D-1E53D9262D0F}']
    procedure AddMenuItem(const pCaption: string; const pOnClick: TNotifyEvent);
        overload;
    procedure AddMenuItem(const pAction: TAction); overload;
    procedure Show(const pX, pY: Integer);
  end;

  TFullMenuService=class(TInterfacedObject,IFullMenuService)

  private
    FMenu: TPopupMenu;
    property Menu: TPopupMenu read FMenu write FMenu;
  public
    constructor Create(const AOwner: TComponent);
    procedure AddMenuItem(const pCaption: string; const pOnClick: TNotifyEvent);overload;
    procedure AddMenuItem(const pAction: TAction); overload;
    procedure Show(const pX, pY: Integer);
  end;

  TFilterMode=(fmNone,fmFull,fmDetail);

  TBaseGridFilters = class(TCustomControl)
  private
    FColorActive: TColor;
    FColorPasive: TColor;
    FDetailButton: TPanel;
    FEditHeight: Integer;
    FEdits: IList<TEdit>;
    FFields: IDictionary<integer,string>;
    FDetailPanel: TPanel;
    FFilterMode: TFilterMode;
    FFullButton: TPanel;
    FFullEdit: TEdit;
    FFullMenu: IFullMenuService;
    FFullPanel: TPanel;
    FGlobalKeyUp: TKeyEvent;
    FSavedFilters: IDictionary<string,string>;
    procedure FullClick(Sender: TObject);
    procedure ClearDetail; virtual;
    procedure ClearSavedFilters;
    procedure DetailClick(Sender: TObject);
    procedure DoKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditsGlobalKeyUp(const Value: TKeyEvent);
    procedure SetDetailButtonHint(const Value: string);
    procedure SetFullButtonHint(const Value: string);
    procedure SetGlobalKeyUp(const Value: TKeyEvent);
    property DetailButton: TPanel read FDetailButton write FDetailButton;
    property EditHeight: Integer read FEditHeight write FEditHeight;
    property Edits: IList<TEdit> read FEdits write FEdits;
    property Fields: IDictionary<integer,string> read FFields write FFields;
    property FullButton: TPanel read FFullButton write FFullButton;
    property FullEdit: TEdit read FFullEdit write FFullEdit;
    property SavedFilters: IDictionary<string,string> read FSavedFilters write
        FSavedFilters;
  protected
    FOldOnFilterRecord:TFilterRecordEvent;
    procedure EditFullEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditDetailEnter(Sender: TObject);
    function GetFieldName(const pEdit: TEdit): string; virtual; abstract;
    procedure SaveFilters; virtual; abstract;
    property DetailPanel: TPanel read FDetailPanel write FDetailPanel;
    property FullPanel: TPanel read FFullPanel write FFullPanel;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearFull; virtual;
    procedure EditsMove(Sender: TObject; const pForward: Boolean = True);
    procedure SwitchFilterMode;
    property FilterMode: TFilterMode read FFilterMode write FFilterMode default
        fmNone;
    property FullMenu: IFullMenuService read FFullMenu write FFullMenu;
  published
    property ColorActive: TColor read FColorActive write FColorActive default
        clrActiveEdit;
    property ColorPasive: TColor read FColorPasive write FColorPasive default
        clrPasiveEdit;
    property DetailButtonHint: string write SetDetailButtonHint;
    property FullButtonHint: string write SetFullButtonHint;
    property GlobalKeyUp: TKeyEvent read FGlobalKeyUp write SetGlobalKeyUp;
  end;

  TJvDBUltimGridFilters = class(TBaseGridFilters)
  private
    FColLineWidth: Integer;
    FFiltersVisible: Boolean;
    FFirstLeftOffset: Integer;
    FGrid: TJvDBUltimGrid;
    FInfoLabel: Tlabel;
    FInfoPanel: TJvSecretPanel;
    FLink: TJvDBGridLayoutChangeLink;
    procedure ChangeLayout;
    procedure ChangeSize;
    procedure ClearDetail; override;
    function ColsWidth: Integer;
    procedure DrawFilters;
    function GridWidth: integer;
    procedure SaveFilters; override;
    procedure SetGrid(const Value: TJvDBUltimGrid);
    procedure ShowFilters(const pVisible: Boolean);
    property ColLineWidth: Integer read FColLineWidth write FColLineWidth;
    property FiltersVisible: Boolean read FFiltersVisible write FFiltersVisible;
    property FirstLeftOffset: Integer read FFirstLeftOffset write FFirstLeftOffset;
    property Grid: TJvDBUltimGrid read FGrid write SetGrid;
    property InfoLabel: Tlabel read FInfoLabel write FInfoLabel;
    property InfoPanel: TJvSecretPanel read FInfoPanel write FInfoPanel;
  protected
    procedure AdjustWidth;
    procedure DoDetailChange(Sender: TObject);
    procedure FilterRecordDetail(DataSet: TDataSet; var Accept: Boolean);
    procedure DoFullChange(Sender: TObject);
    procedure FilterRecordFull(DataSet: TDataSet; var Accept: Boolean);
    function GetFieldName(const pEdit: TEdit): string; override;
    procedure ReindexEdits;
    procedure Resize; override;
    property Link: TJvDBGridLayoutChangeLink read FLink write FLink;
  public
    constructor Create(AOwner: TComponent; const pGrid: TJvDBUltimGrid);
    destructor Destroy; override;
    procedure ClearFull; override;
    procedure LayoutChanged(Grid: TJvDBGrid; Kind: TJvDBGridLayoutChangeKind);
    procedure ResizeFilters;
    procedure SetFocus; override;
  end;

implementation

uses
  JvJVCLUtils,Vcl.DBGrids,Vcl.Grids,WinApi.Windows,SysUtils
  ,VCL.Forms,System.Generics.Collections,System.Types
  ,uLogging,Spring.Data.ObjectDataset,uInterfaces,Spring.Container
  ;

constructor TJvDBUltimGridFilters.Create(AOwner: TComponent; const pGrid:
    TJvDBUltimGrid);
begin
  inherited Create(AOwner);
  FLink:=TJvDBGridLayoutChangeLink.Create;
  FLink.OnChange := LayoutChanged;

  FGrid:=pGrid;
  FGrid.RegisterLayoutChangeLink(FLink);

  FullEdit.OnChange:=DoFullChange;
  Name:=Format('%sFilters',[Grid.Name]);
  ColLineWidth:=Ord(dgColLines in Grid.Options) * TDrawGrid(Grid).GridLineWidth;
  FInfoPanel:=TJvSecretPanel.Create(AOwner);
  with FInfoPanel do
  begin
    Parent:=TWinControl(AOwner);
    Align:=alClient;
    Visible:=False;
  end;
  FInfoLabel:=TLabel.Create(FInfoPanel);
  with FInfoLabel do
  begin
    Caption:='Nejsou data';
    Parent:=TWinControl(AOwner);
    Left:=6;
    Top:=Trunc((FInfoPanel.Height / 2) - (Height / 2));
  end;

  FirstLeftOffset:=0;
  if dgIndicator in Grid.Options then
  begin
    FirstLeftOffset:=IndicatorWidth+1;
  end;
  ShowFilters(False);
  FiltersVisible:=False;
end;

destructor TJvDBUltimGridFilters.Destroy;
begin
  Link.Free;
  inherited;
end;

procedure TJvDBUltimGridFilters.AdjustWidth;
var
  lWidth: integer;
begin
  Width:=GridWidth;
  FFullPanel.Width:=Width;
  FDetailPanel.Width:=Width;
  FInfoPanel.Width:=Width;
  FFullEdit.Width:=Width;
end;

procedure TJvDBUltimGridFilters.ChangeLayout;
begin
  if not FiltersVisible then ShowFilters(True);
  DrawFilters;
end;

procedure TJvDBUltimGridFilters.ChangeSize;
begin
  AdjustWidth;
  ResizeFilters;
end;

procedure TJvDBUltimGridFilters.ClearDetail;
begin
  Edits.ForEach(
    procedure(const pEdit:TEdit)
    begin
      pEdit.Text:='';
    end
  );
  Grid.Datasource.DataSet.Filter:='';
  Grid.Datasource.DataSet.Filtered:=False;
end;

procedure TJvDBUltimGridFilters.ClearFull;
begin
  FullEdit.Text:='';
  Grid.Datasource.DataSet.Filter:='';
  Grid.Datasource.DataSet.Filtered:=False;
end;

function TJvDBUltimGridFilters.ColsWidth: Integer;
var
  i:Integer;
begin
  Result:=0;
  for i := 0 to Grid.Columns.Count-1 do
  begin
    Result:=Result+Grid.Columns[i].Width;
  end;
  if dgColLines in Grid.Options then
    Result := Result + ColLineWidth*Grid.Columns.Count;
end;

procedure TJvDBUltimGridFilters.DoFullChange(Sender: TObject);
begin
  Grid.Datasource.DataSet.Filtered:=False;
  if FilterMode<>fmFull then
  begin
    ClearDetail;
    Grid.Datasource.DataSet.OnFilterRecord:=FilterRecordFull;
    FilterMode:=fmFull;
  end;
  Grid.Datasource.DataSet.Filtered:=True;
end;

procedure TJvDBUltimGridFilters.DoDetailChange(Sender: TObject);
begin
  Grid.Datasource.DataSet.Filtered:=False;
  if FilterMode<>fmDetail then
  begin
    ClearFull;
    Grid.Datasource.DataSet.OnFilterRecord:=FilterRecordDetail;
    FilterMode:=fmDetail;
  end;
  Grid.Datasource.DataSet.Filtered:=True;
end;

procedure TJvDBUltimGridFilters.DrawFilters;
var
  i: Integer;
  lEdit: TEdit;
  lLeft: Integer;
  lVisible: integer;
begin
  Edits.Clear;
  Fields.Clear;
  lLeft:=FirstLeftOffset+1;

  FullEdit.Left:=lLeft;
  FullEdit.Width:=Width-lLeft;

  for i := 0 to Grid.Columns.Count-1 do
  begin
    if Grid.Columns[i].Visible then
    begin
      lEdit:=TEdit.Create(DetailPanel);
      lEdit.Parent:=DetailPanel;
      lEdit.Tag:=i;
      lEdit.Top:=0;
      lEdit.Left:=lLeft;
      lEdit.Width:=Grid.Columns[i].Width+ColLineWidth;
      lLeft:=lLeft+Grid.Columns[i].Width+ColLineWidth;
      lEdit.OnChange:=DoDetailChange;
      {$IFDEF DEBUG}
      lEdit.Hint:=Format('%d-%s',[i,Grid.Columns[i].FieldName]);
      lEdit.ShowHint:=True;
      {$ENDIF}
      lEdit.Ctl3D:=False;
      lEdit.OnEnter:=EditDetailEnter;
      lEdit.OnExit:=EditExit;
      lEdit.TabOrder:=FullEdit.TabOrder+i+1;
      lEdit.TabStop:=True;
      lEdit.Color:=clrPasiveEdit;
      Edits.Add(lEdit);
      Fields.Add(i,Grid.Columns[i].FieldName);
    end;
  end;
  ReindexEdits;
  EditsGlobalKeyUp(GlobalKeyUp);
end;

procedure TJvDBUltimGridFilters.FilterRecordDetail(DataSet: TDataSet; var
    Accept: Boolean);
var
  lStr: string;
  tmpField: TField;
  FilledEdits:IEnumerable<TEdit>;
  lEdit: TEdit;

  function IsOK(const pAccept:Boolean;const pValue:Boolean):Boolean;
  begin
    if pAccept=False then
      Result:=False
    else
      Result:=pValue;
  end;
begin
  Accept:=True;
  FilledEdits:=Edits.Where(
  function(const pEdit:TEdit):Boolean
    begin
      Result:=pEdit.Text<>'';
    end
  );

  for lEdit in FilledEdits do
  begin
    if Fields.TryGetValue(lEdit.Tag,lStr) then
      begin
        tmpField:=Grid.DataSource.DataSet.FieldByName(lStr);
        if tmpField.FieldKind<>fkInternalCalc then
        begin
          if tmpField.Visible then
          begin
            Accept:=IsOK(Accept,(Pos(AnsiUpperCase(lEdit.Text),AnsiUpperCase(tmpField.DisplayText))<>0));
          end;
        end;
      end;
  end;

end;

procedure TJvDBUltimGridFilters.FilterRecordFull(DataSet: TDataSet; var Accept:
    Boolean);
var
  tSearchStr:string;
  tmpField:TField;
begin
  Accept:=False;
  if FullEdit.Text='' then
  begin
    Accept:=True;
  end
  else
  begin
    tSearchStr:='';
    for tmpField in Grid.DataSource.DataSet.Fields do
    begin
      if tmpField.FieldKind<>fkInternalCalc then
      begin
        case tmpField.DataType of
          ftUnknown: ;
          ftBoolean: ;
          else
          begin
            if tmpField.Visible then
            begin
              tSearchStr:=tSearchStr+tmpField.DisplayText+'^^';
            end;
          end;
        end;
      end;
    end;
    Accept:=(Pos(AnsiUpperCase(FullEdit.Text),AnsiUpperCase(tSearchStr))>0);
  end;
end;

function TJvDBUltimGridFilters.GetFieldName(const pEdit: TEdit): string;
begin
  Result:=Grid.Columns[pEdit.Tag].FieldName
end;

function TJvDBUltimGridFilters.GridWidth: integer;
begin
  Result:=Grid.Width-ColLineWidth*2;
  if (GetWindowlong(Grid.Handle, GWL_STYLE) and WS_VSCROLL) <> 0 then
    Result:=Result-GetSystemMetrics(SM_CYVSCROLL);
end;

procedure TJvDBUltimGridFilters.LayoutChanged(Grid: TJvDBGrid; Kind:
    TJvDBGridLayoutChangeKind);
begin
  if Grid<>nil then
  begin
    if Grid.DataSource<>nil then
    begin
      if Grid.DataSource.DataSet<>nil then
      begin
        if Grid.DataSource.DataSet.Active then
        begin
          case Kind of
            lcLayoutChanged: ChangeLayout;
            lcSizeChanged: ChangeSize;
          end;
        end;
      end;
    end;
  end;
end;

procedure TJvDBUltimGridFilters.ReindexEdits;
var
  i: Integer;
  lEdit: TEdit;
  lEditIndex: Integer;
begin
  //Mely by se precislovat tagy,protoze se mohli presunout sloupce
  Fields.Clear;
  lEditIndex:=0;
  for i := 0 to Grid.Columns.Count-1 do
  begin
    if Grid.Columns[i].Visible then
    begin
      lEdit:=Edits.Items[lEditIndex];
      lEdit.Tag:=i;
      Fields.Add(i,Grid.Columns[i].FieldName);
      lEditIndex:=lEditIndex+1;
    end;
  end;
end;

procedure TJvDBUltimGridFilters.Resize;
begin
  if Grid<>nil then
  begin
    if Grid.DataSource<>nil then
    begin
      if Grid.DataSource.DataSet<>nil then
      begin
        if Grid.Datasource.DataSet.Active then
        begin
          AdjustWidth;
          Left:=Grid.Left;
          Top:=Grid.Top-Height;
          FullPanel.Left:=0;
          //FullPanel.Width:=Width;
          FullPanel.Top:=0;
          DetailPanel.Left:=0;
          //DetailPanel.Width:=Width;
          DetailPanel.Top:=EditHeight;
        end;
      end;
    end;
  end;
end;

procedure TJvDBUltimGridFilters.ResizeFilters;
var
  i,j: Integer;
  lColsVisible: Integer;
  lEdit: TEdit;
  lGridWidth: integer;
  lLeft: Integer;
begin
  if Grid<>nil then
  begin
    if Grid.DataSource<>nil then
    begin
      if Grid.DataSource.DataSet<>nil then
      begin
        if Grid.DataSource.DataSet.Active then
        begin
          if not FiltersVisible then ShowFilters(True);
          AdjustWidth;
          j:=0; //pomocny index pro edity.Pocet nemusi souhlasit s poctem vsech sloupcu
          lLeft:=FirstLeftOffset+1;
          FullEdit.Left:=lLeft;
          FullEdit.Width:=Width-lLeft;
          for i := 0 to Grid.Columns.Count-1 do
          begin
            if Grid.Columns[i].Visible then
            begin
              lEdit:=Edits.Items[j];
              lEdit.Left:=lLeft;
              lEdit.Width:=Grid.Columns[i].Width+ColLineWidth;
              lLeft:=lLeft+Grid.Columns[i].Width+ColLineWidth;
              j:=j+1;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TJvDBUltimGridFilters.SaveFilters;
var
  lFieldName:string;
begin
  ClearSavedFilters;
  case FilterMode of
    fmFull: if FullEdit.Text<>'' then SavedFilters.AddOrSetValue('',FullEdit.Text);
    fmDetail:
    begin
      Edits.ForEach(
        procedure(const pEdit:TEdit)
        begin
          if pEdit.Text<>'' then
          begin
            if Fields.TryGetValue(pEdit.Tag,lFieldName) then
              SavedFilters.AddOrSetValue(lFieldName,pEdit.Text);
          end;
        end
        );
    end;
  end;
end;

procedure TJvDBUltimGridFilters.SetFocus;
begin
  inherited;
  FullEdit.SetFocus;
end;

procedure TJvDBUltimGridFilters.SetGrid(const Value: TJvDBUltimGrid);
begin
  if FGrid <> Value then
  begin
    if FGrid <> nil then
      FGrid.UnregisterLayoutChangeLink(FLink);
    ReplaceComponentReference(Self, Value, TComponent(FGrid));
    if FGrid <> nil then
    begin
      FGrid.RegisterLayoutChangeLink(FLink);
    end;
    Name:=Format('%sFilters',[FGrid.Name]);
  end;
end;

procedure TJvDBUltimGridFilters.ShowFilters(const pVisible: Boolean);
var
  lVisible: Boolean;
begin
  //Schovame info a zobrazime filtry
  if FiltersVisible<>pVisible then
  begin
    lVisible:=pVisible;
    InfoPanel.Visible:=not lVisible;
    FullButton.Visible:=lVisible;
    FullPanel.Visible:=lVisible;
    DetailButton.Visible:=lVisible;
    DetailPanel.Visible:=lVisible;
    if dgIndicator in Grid.Options then
    begin
      FullButton.Visible:=True;
      DetailButton.Visible:=True;
    end
    else
    begin
      FullButton.Visible:=False;
      DetailButton.Visible:=False;
    end;
    FiltersVisible:=pVisible;
  end;
end;

constructor TBaseGridFilters.Create(AOwner: TComponent);
var
  lEdit: TEdit;
begin
  inherited Create(AOwner);
  ColorActive:=clrActiveEdit;
  ColorPasive:=clrPasiveEdit;
  FilterMode:=fmNone;
  lEdit:=TEdit.Create(self);
  try
    lEdit.Ctl3D:=False;
    EditHeight:=lEdit.Height;
  finally
    lEdit.Free;
  end;
  Height:=2*EditHeight;
  Parent:=AOwner as TWinControl;

  FullPanel:=TPanel.Create(Self);
  FullPanel.SetSubComponent(True);
  FullPanel.Parent:=Self;
  FullPanel.Left:=Left;
  FullPanel.Top:=0;
  FullPanel.Width:=Width;
  FullPanel.BevelInner:=bvNone;
  FullPanel.BevelOuter:=bvNone;
  FullPanel.TabOrder:=1;
  FullPanel.TabStop:=True;

  FullEdit:=TEdit.Create(FullPanel);
  with FullEdit do
  begin
    Parent:=FullPanel;
    Top:=0;
    Ctl3D:=False;
    OnEnter:=EditFullEnter;
    OnExit:=EditExit;
    TabOrder:=1;
    TabStop:=True;
    OnKeyUp:=GlobalKeyUp;
    Color:=clrPasiveEdit;
  end;

  DetailPanel:=TPanel.Create(Self);
  DetailPanel.SetSubComponent(True);
  DetailPanel.Parent:=Self;
  DetailPanel.Left:=Left;
  DetailPanel.Top:=EditHeight;
  DetailPanel.Width:=Width;
  DetailPanel.BevelInner:=bvNone;
  DetailPanel.BevelOuter:=bvNone;
  DetailPanel.TabOrder:=2;
  DetailPanel.TabStop:=True;

  FullButton:=TPanel.Create(FullPanel);
  with FullButton do
  begin
    Parent:=FullPanel;
    Left:=1;
    Top:=0;
    Height:=EditHeight;
    Width:=IndicatorWidth+1;
    Visible:=False;
    BevelInner:=bvRaised;
    BevelOuter:=bvNone;
    OnClick:=FullClick;
  end;

  DetailButton:=TPanel.Create(DetailPanel);
  with DetailButton do
  begin
    Parent:=DetailPanel;
    Left:=1;
    Top:=0;
    Height:=EditHeight;
    Width:=IndicatorWidth+1;
    Visible:=False;
    BevelInner:=bvRaised;
    BevelOuter:=bvNone;
    OnClick:=DetailClick;
    Caption:='X';
  end;

  Edits:=TCollections.CreateList<TEdit>(True);
  Fields:=TCollections.CreateDictionary<integer,string>;
  SavedFilters:=TCollections.CreateDictionary<string,string>;
  FullMenu:=TFullMenuService.Create(self);
end;

destructor TBaseGridFilters.Destroy;
begin
  Edits.Clear;
  inherited;
end;

procedure TBaseGridFilters.FullClick(Sender: TObject);
begin
  with FullButton.ClientToScreen(Point(0,0)) do
    FullMenu.Show(X,Y);
end;

procedure TBaseGridFilters.ClearDetail;
begin
end;

procedure TBaseGridFilters.ClearFull;
begin
end;

procedure TBaseGridFilters.ClearSavedFilters;
begin
  SavedFilters.RemoveAll(
    function(const pPair:TPair<string,string>):Boolean
    begin
      Result:=True;
    end
    );
end;

procedure TBaseGridFilters.DetailClick(Sender: TObject);
begin
  ClearFull;
  ClearDetail;
end;

procedure TBaseGridFilters.EditFullEnter(Sender: TObject);
begin
  TEdit(Sender).Color:=ColorActive;
end;

procedure TBaseGridFilters.EditExit(Sender: TObject);
begin
  TEdit(Sender).Color:=ColorPasive;
end;

procedure TBaseGridFilters.SetDetailButtonHint(const Value: string);
begin
  DetailButton.Hint:=Value;
  DetailButton.ShowHint:=Value<>'';
end;

procedure TBaseGridFilters.SetFullButtonHint(const Value: string);
begin
  FullButton.Hint:=Value;
  FullButton.ShowHint:=Value<>'';
end;

procedure TBaseGridFilters.SetGlobalKeyUp(const Value: TKeyEvent);
begin
  FGlobalKeyUp := Value;
  FullEdit.OnKeyUp:=Value;
  EditsGlobalKeyUp(Value);
end;

procedure TBaseGridFilters.DoKeyUp(Sender: TObject; var Key: Word; Shift:
    TShiftState);
begin
  case Key of
    VK_LEFT:
    begin // Posunuti v gridu nahoru
      if FilterMode=fmDetail then
      begin
        Key:=0;
      end;
    end;
  end;
end;

procedure TBaseGridFilters.EditDetailEnter(Sender: TObject);
begin
  TEdit(Sender).Color:=ColorActive;
end;

procedure TBaseGridFilters.EditsGlobalKeyUp(const Value: TKeyEvent);
begin
  Edits.ForEach(
    procedure(const pEdit:TEdit)
    begin
      pEdit.OnKeyUp:=Value;
    end
  );
end;

procedure TBaseGridFilters.EditsMove(Sender: TObject; const pForward: Boolean =
    True);
var
  lInt: Integer;
begin
  if FilterMode=fmDetail then
  begin
    case pForward of
      False:
      begin
        lInt:=Edits.IndexOf(TEdit(Sender));
        if lInt=0 then
          Edits.Last.SetFocus
        else
          Edits.Items[lInt-1].SetFocus;
      end;
      True:
      begin
        lInt:=Edits.IndexOf(TEdit(Sender));
        if lInt=Edits.Count-1 then
          Edits.First.SetFocus
        else
          Edits.Items[lInt+1].SetFocus;
      end;
    end;
  end;
end;

procedure TBaseGridFilters.SwitchFilterMode;
begin
  case FilterMode of
    fmNone:
    begin
      FilterMode:=fmFull
    end;
    fmFull:
    begin
      FilterMode:=fmDetail
    end;
    fmDetail:
    begin
      FilterMode:=fmFull
    end;
  end;
end;

constructor TFullMenuService.Create(const AOwner: TComponent);
begin
  inherited Create;
  Menu:=TPopupMenu.Create(AOwner)
end;

procedure TFullMenuService.AddMenuItem(const pCaption: string; const pOnClick:
    TNotifyEvent);
var
  lItem:TMenuItem;
begin
  lItem:=TMenuItem.Create(Menu);
  lItem.Caption:=pCaption;
  lItem.OnClick:=pOnClick;
  Menu.Items.Add(lItem);
end;

procedure TFullMenuService.AddMenuItem(const pAction: TAction);
var
  lItem:TMenuItem;
begin
  lItem:=TMenuItem.Create(Menu);
  lItem.Action:=pAction;
  Menu.Items.Add(lItem);
end;

procedure TFullMenuService.Show(const pX, pY: Integer);
begin
  Menu.Popup(pX,pY);
end;

end.

