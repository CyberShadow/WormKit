unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, XPMan, StdCtrls, ComCtrls, WerControl, Buttons, ExtCtrls;

type
  TMainForm = class(TForm)
    XPManifest1: TXPManifest;
    AntiKeybHook: TCheckBox;
    Label1: TLabel;
    LoopbackPort: TWerSpinEdit;
    Server: TCheckBox;
    Label2: TLabel;
    Mode: TComboBox;
    ModePages: TPageControl;
    IRC: TTabSheet;
    SOCKS: TTabSheet;
    IRCServer: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    IRCPort: TWerSpinEdit;
    Label5: TLabel;
    IRCPassword: TEdit;
    Label6: TLabel;
    IRCLineLength: TWerSpinEdit;
    IRCLineLengthUpDown: TUpDown;
    Label7: TLabel;
    IRCDelay: TWerSpinEdit;
    IRCDelayUpDown: TUpDown;
    Label8: TLabel;
    IRCNickLength: TWerSpinEdit;
    IRCNickLengthUpDown: TUpDown;
    IRCSuffix: TEdit;
    Label9: TLabel;
    Label10: TLabel;
    SOCKSServer: TEdit;
    Label11: TLabel;
    SOCKSPort: TWerSpinEdit;
    AutoConfigBtn: TButton;
    SocksLog: TMemo;
    OkBtn: TBitBtn;
    CancelBtn: TBitBtn;
    CheckProxyBtn: TButton;
    WorkTimer: TTimer;
    procedure AutoConfigBtnClick(Sender: TObject);
    procedure WorkTimerTimer(Sender: TObject);
    procedure CheckProxyBtnClick(Sender: TObject);
    procedure ModeChange(Sender: TObject);
    procedure OkBtnClick(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure InitConfig;
    procedure LoadConfig;
    procedure SaveConfig;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation
uses
  IniFiles, Threads, WinSock;

{$R *.dfm}

var
  Config: TMemIniFile;

{
  AntiKeybHook: Boolean;
  LoopbackPort: Word;
  Server: Boolean;
  Mode: string;
  NickOverride: string;

  IRCServer: string;
  IRCPort: Integer;
  IRCPassword: string;
  IRCLineLength: Integer;
  IRCDelay: Integer;
  IRCNickLength: Integer;
  IRCSuffix: string;

  SOCKSServer: string;
  SOCKSPort: Integer;
}

procedure TMainForm.InitConfig;
begin
  Config := TMemIniFile.Create(ExtractFilePath(ParamStr(0))+'WormNAT.ini');
end;

procedure TMainForm.LoadConfig;
var
  ModeS: string;
  I: Integer;
begin
  AntiKeybHook.Checked  :=Config.ReadBool   ('WormNAT','AntiKeybHook',  True);   // stop Worms from disabling Alt+Tab / Win+... key combos
  LoopbackPort.IntValue :=Config.ReadInteger('WormNAT','LoopbackPort', 17017);   // port for loopback connections (any free port).
  Server.Checked        :=Config.ReadBool   ('WormNAT','Server',        True);   // act as a WormNAT server - disable if you don't have NAT problems and only want to play with people hosting with WormNAT

  ModeS                 :=Config.ReadString ('WormNAT','Mode',        'IRC');   // your hosting back-end
  for I := 0 to Mode.Items.Count - 1 do
    if Mode.Items[I]=ModeS then
      begin
      Mode.ItemIndex:=I;
      ModePages.ActivePageIndex:=I;
      end;
  if Mode.ItemIndex=-1 then
    begin
    ShowMessage('Invalid "Mode" setting in configuration file.');
    Halt;
    end;

  IRCLineLength.IntValue:=Config.ReadInteger('IRC',    'LineLength',     425);   // how much chars per line can the IRC server support in notices. Leave about 5% overhead.
  IRCDelay.IntValue     :=Config.ReadInteger('IRC',    'Delay',         1250);   // max delay between lines. Too little values will get you kicked for flood!
  IRCServer.Text        :=Config.ReadString ('IRC',    'Server',        'wormnet1.team17.com');   // the server where you'll host games
  IRCPort.IntValue      :=Config.ReadInteger('IRC',    'Port',          6667);   // server port
  IRCPassword.Text      :=Config.ReadString ('IRC',    'Password',      '*auto*');   // server password - *auto* will use WormNet's password
  IRCNickLength.IntValue:=Config.ReadInteger('IRC',    'NickLength',      15);   // maximum number of characters allowed in nicknames
  IRCSuffix.Text        :=Config.ReadString ('IRC',    'Suffix',       '-WormNAT');   // suffix to append to nicknames for WormNAT connections (last characters of your nickname could overlap)

  SOCKSServer.Text      :=Config.ReadString ('SOCKS',    'Server',        '');
  SOCKSPort.IntValue    :=Config.ReadInteger('SOCKS',    'Port',          0);
end;

procedure TMainForm.ModeChange(Sender: TObject);
begin
  ModePages.ActivePageIndex:=Mode.ItemIndex;
end;

// INI file read->write RegExp replace formula:
// Search  : (\S*)(\s*):=Config\.Read(.*)\(('.*',\s*'.*',\s*).*\);.*
// Replace : Config.Write$3($4$1$2);

procedure TMainForm.SaveConfig;
begin
  Config.WriteBool   ('WormNAT','AntiKeybHook',  AntiKeybHook.Checked  );
  Config.WriteInteger('WormNAT','LoopbackPort', LoopbackPort.IntValue );
  Config.WriteBool   ('WormNAT','Server',        Server.Checked        );

  Config.WriteString ('WormNAT','Mode',        Mode.Text             );

  Config.WriteInteger('IRC',    'LineLength',     IRCLineLength.IntValue);
  Config.WriteInteger('IRC',    'Delay',         IRCDelay.IntValue     );
  Config.WriteString ('IRC',    'Server',        IRCServer.Text        );
  Config.WriteInteger('IRC',    'Port',          IRCPort.IntValue      );
  Config.WriteString ('IRC',    'Password',      IRCPassword.Text      );
  Config.WriteInteger('IRC',    'NickLength',      IRCNickLength.IntValue);
  Config.WriteString ('IRC',    'Suffix',       IRCSuffix.Text        );

  Config.WriteString ('SOCKS',    'Server',        SOCKSServer.Text      );
  Config.WriteInteger('SOCKS',    'Port',          SOCKSPort.IntValue    );
end;

var
  MessageQueue: string;

procedure TMainForm.WorkTimerTimer(Sender: TObject);
begin
  while MessageQueue<>'' do
    begin
    MainForm.SocksLog.Visible:=True;
    MainForm.SocksLog.Lines.Add(Copy(MessageQueue, 1, Pos(#13#10, MessageQueue)-1));
    Delete(MessageQueue, 1, Pos(#13#10, MessageQueue)+1)
    end;
  if Done then
    begin
    Done:=False;
    case Job of
      1:if CheckResult then
          MessageBox(Handle, 'Proxy passed all tests.', PChar(Caption), MB_ICONINFORMATION)
        else
          MessageBox(Handle, 'The specified proxy failed the check (see log).', PChar(Caption), MB_ICONWARNING);
      2:if FindResult=nil then
          MessageBox(Handle, 'Failed to find a useable proxy - please check your Internet connection.', PChar(MainForm.Caption), MB_ICONERROR)
        else
          begin
          SOCKSServer.Text:=Copy(FindResult, 1, Pos(':', FindResult)-1);
          SOCKSPort.Text  :=Copy(FindResult, Pos(':', FindResult)+1, 10);
          MessageBox(Handle, 'Autoconfiguration successful.', PChar(MainForm.Caption), MB_ICONINFORMATION)
          end;
    end;
    CheckProxyBtn.Enabled:=True;
    AutoConfigBtn.Enabled:=True;
    end;
end;

procedure TMainForm.OkBtnClick(Sender: TObject);
begin
  SaveConfig;
  Config.UpdateFile;
  Config.Free;
  Close;
end;

type
  TLogger = procedure (S: PChar); stdcall;

procedure MyLogger(P: PChar); stdcall;
begin
  MessageQueue:=MessageQueue+P+#13#10;
end;

procedure SetLogger(ALogger: TLogger); stdcall; external 'SocksFinder.dll';

procedure TMainForm.FormCreate(Sender: TObject);
var
  WSA: TWSAData;
begin
  WSAStartUp(2, WSA);

  ClientHeight:=284;
  InitConfig;
  LoadConfig;
  SetLogger(MyLogger);
end;

procedure TMainForm.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.CheckProxyBtnClick(Sender: TObject);
begin
  SocksLog.Lines.Clear;
  CheckProxyBtn.Enabled:=False;
  AutoConfigBtn.Enabled:=False;
  Job:=1;
  TWorker.Create(False);
end;

procedure TMainForm.AutoConfigBtnClick(Sender: TObject);
begin
  SocksLog.Lines.Clear;
  CheckProxyBtn.Enabled:=False;
  AutoConfigBtn.Enabled:=False;
  Job:=2;
  TWorker.Create(False);
end;

end.
