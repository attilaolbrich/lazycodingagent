#!/usr/bin/env python3
"""Legacy scaffold for mainunit.lfm (nav rail list + menu tail only).

IMPORTANT — designer-owned layout:
  Edit [mainunit.lfm] in the Lazarus Form Designer for dock panels, Align-based
  chrome (title alLeft / tabs alClient / actions alRight), chat header/footer rows,
  and spacer panels. Do NOT run this script to overwrite mainunit.lfm unless you
  have updated the generator body below to match the current LCA layout.

  Safe use today: copy nav_rail / menu_tail patterns when adding rail items, then
  merge manually in the IDE. Full regeneration requires syncing chat, chrome hosts,
  and footer row structure with the live .lfm.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
menu_tail = (ROOT / "mainunit.lfm").read_text().split("  object lcaMainMenu: TLcaThemedMainMenu", 1)[1]
menu_tail = "  object lcaMainMenu: TLcaThemedMainMenu" + menu_tail

nav_items = [
    ("sbtnNavBrain", 10, "◉"), ("sbtnNavKnowledge", 9, "📖"), ("sbtnNavExecPlans", 8, "☑"),
    ("sbtnNavMultiAgent", 7, "⬡"), ("sbtnNavToolErrors", 6, "⚠"), ("sbtnNavTasks", 5, "☰"),
    ("sbtnNavTools", 4, "◈"), ("sbtnNavBots", 3, "✦"), ("sbtnNavSessions", 2, "✉"),
    ("sbtnNavProjects", 1, "◫"), ("sbtnNavHome", 0, "⌂"),
]
nav_rail = ""
for name, tag, cap in nav_items:
    top_spacing = 16 if name == "sbtnNavMultiAgent" else 8
    nav_rail += f"""      object {name}: TLcaNavRailButton
        Tag = {tag}
        Left = 6
        Height = 40
        Top = 0
        Width = 100
        Align = alTop
        Caption = '{cap}'
        Flat = True
        GroupIndex = 1
        BorderSpacing.Top = {top_spacing}
        Font.Size = 12
        OnClick = NavRailBtnClick
      end
"""

body = f"""object LazyCodingAgentForm: TLazyCodingAgentForm
  Left = 0
  Height = 1606
  Top = 0
  Width = 2598
  Caption = 'LazyCodingAgent — AI Workspace'
  ClientHeight = 1606
  ClientWidth = 2598
  Constraints.MinHeight = 600
  Constraints.MinWidth = 901
  DesignTimePPI = 192
  Position = poScreenCenter
  LCLVersion = '4.8.0.0'
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  BorderStyle = bsNone
  object lcaTitleBar: TLcaThemedTitleBar
    Left = 0
    Height = 32
    Top = 0
    Width = 2880
    Align = alTop
    MainMenu = lcaMainMenu
    TabOrder = 0
  end
  object pnlMainContainer: TPanel
    Left = 0
    Height = 1312
    Top = 0
    Width = 2880
    Align = alClient
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    ParentColor = False
    TabOrder = 0
    object pnlNavRailHost: TPanel
      Left = 0
      Height = 1312
      Top = 0
      Width = 100
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
{nav_rail}    end
    object pnlNavHost: TPanel
      Left = 100
      Height = 1312
      Top = 0
      Width = 500
      Align = alLeft
      BevelOuter = bvNone
      Color = clBtnFace
      ParentBackground = False
      ParentColor = False
      TabOrder = 1
      object pnlNavChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 500
        Align = alTop
        BevelOuter = bvNone
        object lblNavTitle: TLabel
          Left = 16
          Height = 36
          Top = 18
          Width = 142
          Caption = 'Navigation'
        end
        object btnNavHide: TButton
          Tag = 0
          Left = 428
          Height = 50
          Top = 8
          Width = 64
          Caption = '✕'
          TabOrder = 0
          OnClick = PanelHideClick
        end
      end
      object pnlNavContent: TPanel
        Left = 0
        Height = 1244
        Top = 68
        Width = 500
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object lblNavViewTitle: TLabel
          Left = 12
          Height = 28
          Top = 12
          Width = 476
          Align = alTop
          Caption = 'Workspaces'
          Layout = tlCenter
        end
        object lblNavViewSub: TLabel
          Left = 12
          Height = 22
          Top = 40
          Width = 476
          Align = alTop
          Caption = 'Select a workspace'
          Layout = tlCenter
        end
        object lblNavComingSoon: TLabel
          Left = 12
          Height = 32
          Top = 62
          Width = 476
          Align = alTop
          BorderSpacing.Top = 4
          Caption = 'COMING SOON'
          Font.Height = -16
          Font.Style = [fsBold]
          Layout = tlCenter
          ParentFont = False
          Visible = False
        end
        object btnNavPrimary: TButton
          Left = 12
          Height = 40
          Top = 1192
          Width = 476
          Align = alBottom
          Caption = 'Action'
          TabOrder = 0
        end
        object btnNavSecondary: TButton
          Left = 12
          Height = 36
          Top = 1156
          Width = 476
          Align = alBottom
          Caption = 'Secondary'
          TabOrder = 1
          Visible = False
        end
        object lstNavFile: TListBox
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ItemHeight = 0
          TabOrder = 2
        end
        object tvNavProjects: TTreeView
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ReadOnly = True
          TabOrder = 3
          Visible = False
        end
        object lstNavLog: TListBox
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ItemHeight = 0
          TabOrder = 4
          Visible = False
        end
        object lstNavErrors: TListBox
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ItemHeight = 0
          TabOrder = 5
          Visible = False
        end
      end
    end
    object splNav: TSplitter
      Left = 612
      Height = 1312
      Top = 0
      Width = 10
      Align = alLeft
      MinSize = 160
      ResizeAnchor = akLeft
    end
    object pnlUtilityHost: TPanel
      Left = 2320
      Height = 1312
      Top = 0
      Width = 560
      Align = alRight
      BevelOuter = bvNone
      Color = clBtnFace
      ParentBackground = False
      ParentColor = False
      TabOrder = 2
      Visible = False
      object pnlUtilityChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 560
        Align = alTop
        BevelOuter = bvNone
        object pnlUtilityTabStripHost: TPanel
          Left = 0
          Height = 68
          Top = 0
          Width = 560
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          object lcaUtilityTabBar: TLcaThemedPageTabBar
            Left = 0
            Height = 68
            Top = 0
            Width = 560
            Align = alClient
            BevelOuter = bvNone
            PageControl = pgcUtility
            TabOrder = 0
          end
        end
        object btnUtilityDetach: TLcaThemedButton
          ButtonRole = tbrGhost
          Tag = 3
          Left = 416
          Height = 50
          Top = 8
          Width = 64
          Anchors = [akTop, akRight]
          Caption = '⧉'
          TabOrder = 1
          OnClick = PanelDetachClick
        end
        object btnUtilityHide: TLcaThemedButton
          ButtonRole = tbrGhost
          Tag = 3
          Left = 488
          Height = 50
          Top = 8
          Width = 64
          Anchors = [akTop, akRight]
          Caption = '✕'
          TabOrder = 2
          OnClick = PanelHideClick
        end
      end
      object pnlUtilityContent: TPanel
        Left = 0
        Height = 1244
        Top = 68
        Width = 560
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object pgcUtility: TPageControl
          Left = 0
          Height = 1244
          Top = 0
          Width = 560
          Align = alClient
          ShowTabs = False
          TabOrder = 0
          object tsUtilityExecDetail: TTabSheet
            Caption = 'Execution Detail'
            object memUtilityExecDetail: TMemo
              Left = 0
              Height = 1216
              Top = 0
              Width = 552
              Align = alClient
              ReadOnly = True
              ScrollBars = ssBoth
              TabOrder = 0
              WordWrap = False
            end
          end
          object tsUtilityPlan: TTabSheet
            Caption = 'Plan'
            object pnlPlanHeader: TPanel
              Left = 0
              Height = 80
              Top = 0
              Width = 552
              Align = alTop
              BevelOuter = bvNone
              TabOrder = 0
              object lblPlanPath: TLabel
                Left = 8
                Height = 15
                Top = 8
                Width = 536
                Align = alTop
                AutoSize = True
                BorderSpacing.Left = 8
                BorderSpacing.Right = 8
                BorderSpacing.Top = 8
                Caption = 'Plan file:'
                WordWrap = True
              end
              object pnlPlanToolbar: TPanel
                Left = 8
                Height = 40
                Top = 38
                Width = 536
                Align = alTop
                BevelOuter = bvNone
                BorderSpacing.Left = 8
                BorderSpacing.Right = 8
                BorderSpacing.Bottom = 8
                TabOrder = 0
                object btnPlanBuild: TLcaThemedButton
                  Left = 473
                  Height = 32
                  Top = 4
                  Width = 63
                  Align = alRight
                  BorderSpacing.Left = 8
                  Caption = 'Build'
                  TabOrder = 1
                  ButtonRole = tbrPrimary
                end
                object cboPlanModel: TLcaThemedComboBox
                  Left = 0
                  Height = 36
                  Top = 4
                  Width = 465
                  Align = alClient
                  BorderSpacing.Top = 4
                  BorderSpacing.Bottom = 4
                  Style = csDropDownList
                  TabOrder = 0
                end
              end
            end
            object lcaPlanBody: TLcaMarkdownView
              Left = 0
              Height = 1136
              Top = 80
              Width = 552
              Align = alClient
              BevelOuter = bvNone
              TabOrder = 1
            end
          end
        end
      end
    end
    object splUtility: TSplitter
      Left = 2310
      Height = 1312
      Top = 0
      Width = 10
      Align = alRight
      MinSize = 160
      ResizeAnchor = akRight
      Visible = False
    end
    object pnlReservedHost: TPanel
      Left = 1740
      Height = 1312
      Top = 0
      Width = 570
      Align = alRight
      BevelOuter = bvNone
      Color = clBtnFace
      ParentBackground = False
      ParentColor = False
      TabOrder = 3
      Visible = False
      object pnlReservedChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 570
        Align = alTop
        BevelOuter = bvNone
        object lblReservedTitle: TLabel
          Left = 16
          Height = 36
          Top = 18
          Width = 137
          Caption = 'Guidelines'
        end
        object btnReservedHide: TButton
          Tag = 2
          Left = 498
          Height = 50
          Top = 8
          Width = 64
          Caption = '✕'
          TabOrder = 0
          OnClick = PanelHideClick
        end
      end
      object pnlReservedContent: TPanel
        Left = 0
        Height = 1244
        Top = 68
        Width = 570
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object memReserved: TMemo
          Left = 0
          Height = 1244
          Top = 0
          Width = 570
          Align = alClient
          BorderStyle = bsNone
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
    object splReserved: TSplitter
      Left = 1730
      Height = 1312
      Top = 0
      Width = 10
      Align = alRight
      MinSize = 180
      ResizeAnchor = akRight
      Visible = False
    end
    object pnlChatHost: TPanel
      Left = 622
      Height = 1312
      Top = 0
      Width = 1108
      Align = alClient
      BevelOuter = bvNone
      Color = clBtnFace
      ParentBackground = False
      ParentColor = False
      TabOrder = 5
      object pnlChatChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 1108
        Align = alTop
        BevelOuter = bvNone
        object pnlCenterTabStripHost: TPanel
          Left = 0
          Height = 68
          Top = 0
          Width = 1108
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          object lcaCenterTabBar: TLcaThemedPageTabBar
            Left = 0
            Height = 68
            Top = 0
            Width = 1108
            Align = alClient
            BevelOuter = bvNone
            PageControl = pgcCenter
            TabOrder = 0
          end
        end
        object btnChatDetach: TLcaThemedButton
          ButtonRole = tbrGhost
          Tag = 1
          Left = 1020
          Height = 50
          Top = 8
          Width = 64
          Anchors = [akTop, akRight]
          Caption = '⧉'
          TabOrder = 1
          OnClick = PanelDetachClick
        end
      end
      object pgcCenter: TPageControl
        Left = 0
        Height = 1244
        Top = 68
        Width = 1108
        Align = alClient
        ShowTabs = False
        TabOrder = 1
        object tsChat: TTabSheet
          Caption = 'Chat'
          object pnlChatSessionTabStripHost: TPanel
            Left = 0
            Height = 68
            Top = 0
            Width = 1100
            Align = alTop
            BevelOuter = bvNone
            TabOrder = 0
            object lcaChatSessionTabBar: TLcaThemedPageTabBar
              Left = 0
              Height = 68
              Top = 0
              Width = 1100
              Align = alClient
              BevelOuter = bvNone
              AddTabCaption = '+'
              ShowAddTab = True
              TabOrder = 0
            end
          end
          object lblChatHeading: TLabel
            Left = 16
            Height = 32
            Top = 8
            Width = 400
            Caption = 'What should we build?'
          end
          object lblChatSession: TLabel
            Left = 16
            Height = 20
            Top = 44
            Width = 200
            Caption = 'Session:'
          end
          object lblChatSub: TLabel
            Left = 16
            Height = 20
            Top = 68
            Width = 500
            Caption = 'Autonomous AI agent workspace'
          end
          object pnlChatComposer: TPanel
            Left = 0
            Height = 200
            Top = 1044
            Width = 1100
            Align = alBottom
            BevelOuter = bvNone
            TabOrder = 0
            object lblChatWorkspaceTag: TLabel
              Left = 12
              Height = 16
              Top = 8
              Width = 200
              Caption = 'PROJECT'
            end
            object memChatPrompt: TMemo
              Left = 12
              Height = 100
              Top = 28
              Width = 1076
              Anchors = [akLeft, akTop, akRight]
              ScrollBars = ssVertical
              TabOrder = 0
            end
            object pnlChatFooter: TPanel
              Left = 0
              Height = 56
              Top = 144
              Width = 1100
              Align = alBottom
              BevelOuter = bvNone
              TabOrder = 1
              object cboChatMode: TComboBox
                Left = 12
                Height = 25
                Top = 14
                Width = 140
                ItemHeight = 22
                Style = csDropDownList
                TabOrder = 0
              end
              object cboChatModel: TComboBox
                Left = 164
                Height = 25
                Top = 14
                Width = 220
                ItemHeight = 22
                Style = csDropDownList
                TabOrder = 1
              end
              object btnChatStop: TButton
                Left = 900
                Height = 32
                Top = 12
                Width = 80
                Anchors = [akTop, akRight]
                Caption = 'Stop'
                TabOrder = 2
                Visible = False
              end
              object btnChatSend: TButton
                Left = 992
                Height = 32
                Top = 12
                Width = 96
                Anchors = [akTop, akRight]
                Caption = 'Run Agent'
                TabOrder = 3
              end
            end
          end
          object memChatHistory: TMemo
            Left = 0
            Height = 940
            Top = 96
            Width = 1100
            Align = alClient
            ReadOnly = True
            ScrollBars = ssVertical
            TabOrder = 1
          end
        end
        object tsEditor: TTabSheet
          Caption = 'Editor'
          object synEditor: TSynEdit
            Left = 0
            Height = 1216
            Top = 0
            Width = 1100
            Align = alClient
            Font.Height = -14
            Font.Name = 'DejaVu Sans Mono'
            Font.Pitch = fpFixed
            Font.Quality = fqNonAntialiased
            ParentColor = False
            ParentFont = False
            TabOrder = 0
          end
        end
        object tsMarkdown: TTabSheet
          Caption = 'Markdown'
          object memMarkdownPreview: TMemo
            Left = 0
            Height = 1216
            Top = 0
            Width = 1100
            Align = alClient
            ReadOnly = True
            ScrollBars = ssVertical
            TabOrder = 0
          end
        end
      end
    end
  end
  object splTerminal: TSplitter
    Cursor = crVSplit
    Left = 0
    Height = 10
    Top = 1312
    Width = 2880
    Align = alBottom
    MinSize = 120
    ResizeAnchor = akBottom
    Visible = False
    OnMoved = SplTerminalMoved
  end
  object pnlTerminalHost: TPanel
    Left = 0
    Height = 440
    Top = 1322
    Width = 2880
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    ParentColor = False
    TabOrder = 2
    Visible = False
    object pnlTerminalChrome: TPanel
      Left = 0
      Height = 68
      Top = 0
      Width = 2880
      Align = alTop
      BevelOuter = bvNone
      object lblTerminalTitle: TLabel
        Left = 16
        Height = 36
        Top = 18
        Width = 114
        Caption = 'Terminal'
      end
      object btnTerminalDetach: TButton
        Tag = 4
        Left = 2736
        Height = 50
        Top = 8
        Width = 64
        Anchors = [akTop, akRight]
        Caption = '⧉'
        TabOrder = 0
        OnClick = PanelDetachClick
      end
      object btnTerminalHide: TButton
        Tag = 4
        Left = 2808
        Height = 50
        Top = 8
        Width = 64
        Anchors = [akTop, akRight]
        Caption = '✕'
        TabOrder = 1
        OnClick = PanelHideClick
      end
    end
    object pnlTerminalContent: TPanel
      Left = 0
      Height = 372
      Top = 68
      Width = 2880
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object lblTerminalStatus: TLabel
        Left = 8
        Height = 15
        Top = 4
        Width = 4
        Align = alTop
        AutoSize = True
        WordWrap = True
      end
      object lcaTerminalPanel: TLcaTerminalPanel
        Left = 0
        Height = 351
        Top = 21
        Width = 2880
        Align = alClient
        BevelOuter = bvNone
        StatusLabel = lblTerminalStatus
        TabOrder = 0
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Height = 38
    Top = 1762
    Width = 2880
    Panels = <>
  end
{menu_tail}
end
"""

body = body.replace("{menu_tail}", menu_tail)
(ROOT / "mainunit.lfm").write_text(body)
print("Wrote", ROOT / "mainunit.lfm", "lines", len(body.splitlines()))
