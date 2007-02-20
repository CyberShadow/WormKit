object MainForm: TMainForm
  Left = 329
  Top = 173
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'WormNAT configuration'
  ClientHeight = 277
  ClientWidth = 425
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  ShowHint = True
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 46
    Width = 72
    Height = 13
    Hint = 'port for loopback connections (any free port).'
    Caption = 'Loopback port:'
  end
  object Label2: TLabel
    Left = 213
    Top = 46
    Width = 69
    Height = 13
    Hint = 'your hosting back-end'
    Caption = 'Hosting mode:'
  end
  object AntiKeybHook: TCheckBox
    Left = 8
    Top = 8
    Width = 409
    Height = 17
    Hint = 'stop Worms from disabling Alt+Tab / Win+... key combos'
    Caption = 'Don'#39't allow Worms to block Alt-Tab / Win+... / ... keys'
    TabOrder = 0
    Enabled = False
  end
  object LoopbackPort: TWerSpinEdit
    Left = 86
    Top = 43
    Width = 51
    Height = 21
    Hint = 'port for loopback connections (any free port).'
    TabOrder = 2
    Text = '0'
    IntValue = -1
  end
  object Server: TCheckBox
    Left = 8
    Top = 24
    Width = 409
    Height = 17
    Hint = 
      'act as a WormNAT server - disable if you don'#39't have NAT problems' +
      ' and only want to play with people hosting with WormNAT'
    Caption = 'Enable WormNAT hosting (uncheck if you don'#39't have NAT problems)'
    TabOrder = 1
  end
  object Mode: TComboBox
    Left = 296
    Top = 43
    Width = 121
    Height = 21
    Hint = 'your hosting back-end'
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 3
    OnChange = ModeChange
    Items.Strings = (
      'IRC'
      'SOCKS')
  end
  object ModePages: TPageControl
    Left = 8
    Top = 70
    Width = 409
    Height = 171
    ActivePage = IRC
    TabOrder = 4
    object IRC: TTabSheet
      Caption = 'IRC'
      object Label3: TLabel
        Left = 12
        Top = 22
        Width = 36
        Height = 13
        Hint = 'the server where you'#39'll host games'
        Caption = 'Server:'
      end
      object Label4: TLabel
        Left = 201
        Top = 22
        Width = 24
        Height = 13
        Hint = 'server port - usually 6667'
        Caption = 'Port:'
      end
      object Label5: TLabel
        Left = 12
        Top = 46
        Width = 50
        Height = 13
        Hint = 
          'the IRC server password, if the server requires one. use *auto* ' +
          'for WormNET.'
        Caption = 'Password:'
      end
      object Label6: TLabel
        Left = 12
        Top = 78
        Width = 100
        Height = 13
        Hint = 
          'how much chars per line can the IRC server support in notices. L' +
          'eave about 5% overhead.'
        Caption = 'Maximum line length:'
      end
      object Label7: TLabel
        Left = 201
        Top = 78
        Width = 31
        Height = 13
        Hint = 
          'max delay between lines. Lower = less lag, but too little values' +
          ' will get you kicked for flood!'
        Caption = 'Delay:'
      end
      object Label8: TLabel
        Left = 12
        Top = 106
        Width = 102
        Height = 13
        Hint = 'maximum number of characters allowed in nicknames'
        Caption = 'Maximum nick length:'
      end
      object Label9: TLabel
        Left = 201
        Top = 106
        Width = 53
        Height = 13
        Hint = 
          'suffix to append to nicknames for WormNAT connections (last char' +
          'acters of your nickname could overlap)'
        Caption = 'Nick suffix:'
      end
      object IRCServer: TEdit
        Left = 66
        Top = 19
        Width = 118
        Height = 21
        Hint = 'the server where you'#39'll host games'
        TabOrder = 0
      end
      object IRCPort: TWerSpinEdit
        Left = 259
        Top = 19
        Width = 51
        Height = 21
        Hint = 'server port - usually 6667'
        TabOrder = 1
        Text = '0'
        IntValue = -1
      end
      object IRCPassword: TEdit
        Left = 66
        Top = 43
        Width = 118
        Height = 21
        Hint = 
          'the IRC server password, if the server requires one. use *auto* ' +
          'for WormNET.'
        TabOrder = 2
      end
      object IRCLineLength: TWerSpinEdit
        Left = 118
        Top = 76
        Width = 51
        Height = 21
        Hint = 
          'how much chars per line can the IRC server support in notices. L' +
          'eave about 5% overhead.'
        TabOrder = 3
        Text = '0'
        UpDown = IRCLineLengthUpDown
        IntValue = 0
      end
      object IRCLineLengthUpDown: TUpDown
        Left = 169
        Top = 76
        Width = 15
        Height = 21
        Hint = 
          'how much chars per line can the IRC server support in notices. L' +
          'eave about 5% overhead.'
        Associate = IRCLineLength
        Max = 32767
        TabOrder = 4
      end
      object IRCDelay: TWerSpinEdit
        Left = 259
        Top = 75
        Width = 51
        Height = 21
        Hint = 
          'max delay between lines. Lower = less lag, but too little values' +
          ' will get you kicked for flood!'
        TabOrder = 5
        Text = '0'
        UpDown = IRCDelayUpDown
        IntValue = 0
      end
      object IRCDelayUpDown: TUpDown
        Left = 310
        Top = 75
        Width = 15
        Height = 21
        Hint = 
          'max delay between lines. Lower = less lag, but too little values' +
          ' will get you kicked for flood!'
        Associate = IRCDelay
        Max = 32767
        TabOrder = 6
      end
      object IRCNickLength: TWerSpinEdit
        Left = 118
        Top = 103
        Width = 51
        Height = 21
        Hint = 'maximum number of characters allowed in nicknames'
        TabOrder = 7
        Text = '0'
        UpDown = IRCNickLengthUpDown
        IntValue = 0
      end
      object IRCNickLengthUpDown: TUpDown
        Left = 169
        Top = 103
        Width = 15
        Height = 21
        Hint = 'maximum number of characters allowed in nicknames'
        Associate = IRCNickLength
        TabOrder = 8
      end
      object IRCSuffix: TEdit
        Left = 259
        Top = 103
        Width = 122
        Height = 21
        Hint = 
          'suffix to append to nicknames for WormNAT connections (last char' +
          'acters of your nickname could overlap)'
        TabOrder = 9
      end
    end
    object SOCKS: TTabSheet
      Caption = 'SOCKS'
      ImageIndex = 1
      object Label10: TLabel
        Left = 201
        Top = 13
        Width = 14
        Height = 13
        Caption = 'IP:'
      end
      object Label11: TLabel
        Left = 201
        Top = 36
        Width = 24
        Height = 13
        Caption = 'Port:'
      end
      object SOCKSServer: TEdit
        Left = 259
        Top = 6
        Width = 134
        Height = 21
        TabOrder = 1
      end
      object SOCKSPort: TWerSpinEdit
        Left = 259
        Top = 33
        Width = 51
        Height = 21
        TabOrder = 2
        Text = '0'
        IntValue = -1
      end
      object AutoConfigBtn: TButton
        Left = 8
        Top = 10
        Width = 177
        Height = 44
        Hint = 'Find a public SOCKS server with BIND support'
        Caption = '&Automatic configuration'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        OnClick = AutoConfigBtnClick
      end
      object SocksLog: TMemo
        Left = 8
        Top = 60
        Width = 385
        Height = 77
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 4
        Visible = False
      end
      object CheckProxyBtn: TButton
        Left = 324
        Top = 33
        Width = 69
        Height = 21
        Caption = 'Check'
        TabOrder = 3
        OnClick = CheckProxyBtnClick
      end
    end
  end
  object OkBtn: TBitBtn
    Left = 264
    Top = 248
    Width = 73
    Height = 25
    Caption = 'OK'
    Default = True
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ModalResult = 1
    ParentFont = False
    TabOrder = 5
    OnClick = OkBtnClick
    Glyph.Data = {
      36030000424D3603000000000000360000002800000010000000100000000100
      1800000000000003000000000000000000000000000000000000FFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF507B58608066FF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFF84A78B025014054815A7B1A8FFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB1C6B4066D1D025F1702521428
      6035FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFF1B9136037D1F157B2D026519025815608968FFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF48A85D1F983A10912DABCCB153A16402
      6D1B025E1795AC98FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF58B26C
      45A95C3FA75766B577FFFFFFFFFFFF158C3003741C126D27BEC6BEFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF68B97B5AB36EFFFFFFFFFFFFFFFFFFA7
      D2AF038A2203791E267B38C4C9C3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFB0D8B7FFFFFFFFFFFFFFFFFFFFFFFF69B779078D25037C1E318343FFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFF4BAA600B8F29037F1F4B935AFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF32A04B0D902B0382
      20409051FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFBCDBC22B9D4510912D038521178330FFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8DC7992B9D
      4512922F56AA68FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFF68B87A289C42C0DAC4FFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FF59B26DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
    Spacing = 8
  end
  object CancelBtn: TBitBtn
    Left = 344
    Top = 248
    Width = 73
    Height = 25
    Caption = 'Cancel'
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ModalResult = 2
    ParentFont = False
    TabOrder = 6
    OnClick = CancelBtnClick
    Glyph.Data = {
      36030000424D3603000000000000360000002800000010000000100000000100
      1800000000000003000000000000000000000000000000000000FFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFF9D9CD45555C93A39BF3F3FB76665B4B2B1C7FFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFAFAEDC3232BB0A0AAB0808A007
      079608088C07078212127E61609EFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      8B8ADC0D0CC10909B92E2EB77372C18887C58987C15656A80E0D810505742E2D
      81B2B1C0FFFFFFFFFFFFFFFFFFAEADE41515C90F0EC78584CFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFF4D4DA20404780505722D2C7EFFFFFFFFFFFFFFFFFF4646D2
      1F1FCD9392D3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F7EC00A0A882424A02D2C
      9B0808727271A3FFFFFFA5A4E43333D15E5ED3FFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFF9D9CD20C0C9A1B1B96AEADC9A8A6C60A0A7623237FFFFFFF7C7CDD4040D3
      A8A7D9FFFFFFFFFFFFFFFFFFFFFFFFB9B8E01414B10F0EA39A99C5FFFFFFFFFF
      FF4140990B0B79B2B1C76D6DDB4C4CD6FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF24
      24C60A0AB77E7DC4FFFFFFFFFFFFFFFFFF6867AF0A0A7E9897BC7676DD5857D8
      FFFFFFFFFFFFFFFFFFFFFFFF4B4BD30C0CC85F5ECAFFFFFFFFFFFFFFFFFFFFFF
      FF6867B20A0A868F8EBA8E8DE36262DCBFBDDDFFFFFFFFFFFF7170D52928CD50
      4FCFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF4342A90B0B8EA7A5C4B8B7E96A6ADE
      9291DFFFFFFF8F8FD64343D44E4ED0C4C2D7FFFFFFFFFFFFFFFFFFFFFFFFA2A0
      D20E0D9C2323BBFFFFFFFFFFFF7979E06A6ADE9695DD5858D85555D5B5B4D1FF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFF4645B907079F6E6DCCFFFFFFFFFFFFBEBDEA
      706FDF6565DC5E5EDAAEADD7FFFFFFFFFFFFFFFFFFFFFFFFB8B7DC5050C50808
      AE2625AEFFFFFFFFFFFFFFFFFFFFFFFFACABE76D6DDE5F5FDB7A79DA9D9CD9B4
      B3D7A4A3D57271D42020E90808BF2020B9B2B1D4FFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFF7F7FDF5A5AD94B4BD53D3DD32D2DCF1C1CCB0F0FC95353CDFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC3C2E9A3A2E484
      83DE7A79DB8E8DDCFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
    Spacing = 8
  end
  object XPManifest1: TXPManifest
    Left = 440
    Top = 8
  end
  object WorkTimer: TTimer
    Interval = 50
    OnTimer = WorkTimerTimer
    Left = 384
    Top = 8
  end
end
