unit uAppTypes;

{$mode objfpc}{$H+}

interface

uses
  LcaTheme;

type
  TNavigationItem = (niHome, niProjects, niSessions, niBots, niTools, niTasks, niToolErrors,
    niMultiAgent, niExecutionPlans, niKnowledgeBase, niTheBrain);
  TWorkspaceMode = (wmAsk, wmPlan, wmAgent);
  TPanelId = (piNavigation, piChat, piReserved, piUtility, piTerminal);
  TThemeKind = LcaTheme.TThemeKind;

const
  tkDark = LcaTheme.tkDark;
  tkLight = LcaTheme.tkLight;

function NavigationCaption(AItem: TNavigationItem): string;
function NavigationHint(AItem: TNavigationItem): string;
function NavigationIconSymbol(AItem: TNavigationItem): string;
function NavigationIsFutureFeature(AItem: TNavigationItem): Boolean;
function NavigationFutureFeatureFirst: TNavigationItem;
function NavigationFutureFeatureTitle(AItem: TNavigationItem): string;
function WorkspaceModeCaption(AMode: TWorkspaceMode): string;
function WorkspaceModeDesc(AMode: TWorkspaceMode): string;
function PanelCaption(AId: TPanelId): string;
function PanelIconSymbol(AId: TPanelId): string;

implementation

function NavigationCaption(AItem: TNavigationItem): string;
begin
  case AItem of
    niHome: Result := 'Workspace';
    niProjects: Result := 'Projects';
    niSessions: Result := 'Agents';
    niBots: Result := 'Bots';
    niTools: Result := 'Tools & Logs';
    niTasks: Result := 'Tasks & Plans';
    niToolErrors: Result := 'Tool Errors';
    niMultiAgent: Result := 'Multi-Agent Workspace';
    niExecutionPlans: Result := 'Execution Plans';
    niKnowledgeBase: Result := 'Workspace Knowledge Base';
    niTheBrain: Result := 'The Brain';
  end;
end;

function NavigationHint(AItem: TNavigationItem): string;
begin
  case AItem of
    niHome: Result := 'Workspace - Open and switch projects';
    niProjects: Result := 'Projects - Workspace files & tree';
    niSessions: Result := 'Agents - Chat sessions and coding agents';
    niBots: Result := 'Bots - Custom assistants & prompts';
    niTools: Result := 'Tools - Local tool execution & logs';
    niTasks: Result := 'Tasks - Active plan & task checklists';
    niToolErrors: Result := 'Tool Errors - Failed tools & on-disk error log';
    niMultiAgent: Result := 'Multi-Agent Workspace - Configure from Workspace menu (coming soon)';
    niExecutionPlans: Result := 'Execution Plans - Configure from Workspace menu (coming soon)';
    niKnowledgeBase: Result := 'Workspace Knowledge Base - Configure from Workspace menu (coming soon)';
    niTheBrain: Result := 'The Brain - Configure from Workspace menu (coming soon)';
  end;
end;

function NavigationIconSymbol(AItem: TNavigationItem): string;
begin
  case AItem of
    niHome: Result := '⌂';
    niProjects: Result := '◫';
    niSessions: Result := '✉';
    niBots: Result := '✦';
    niTools: Result := '◈';
    niTasks: Result := '☰';
    niToolErrors: Result := '⚠';
    niMultiAgent: Result := '⬡';
    niExecutionPlans: Result := '☑';
    niKnowledgeBase: Result := '📖';
    niTheBrain: Result := '◉';
  end;
end;

function NavigationIsFutureFeature(AItem: TNavigationItem): Boolean;
begin
  Result := AItem in [niMultiAgent, niExecutionPlans, niKnowledgeBase, niTheBrain];
end;

function NavigationFutureFeatureFirst: TNavigationItem;
begin
  Result := niMultiAgent;
end;

function NavigationFutureFeatureTitle(AItem: TNavigationItem): string;
begin
  case AItem of
    niMultiAgent: Result := 'Multi-Agent Workspace';
    niExecutionPlans: Result := 'Execution Plans & Progress Tracking';
    niKnowledgeBase: Result := 'Workspace Knowledge Base (RAG)';
    niTheBrain: Result := 'The Brain — Adaptive Learning & Memory';
  else
    Result := NavigationCaption(AItem);
  end;
end;

function WorkspaceModeCaption(AMode: TWorkspaceMode): string;
begin
  case AMode of
    wmAsk: Result := 'Ask';
    wmPlan: Result := 'Plan';
    wmAgent: Result := 'Agent';
  end;
end;

function WorkspaceModeDesc(AMode: TWorkspaceMode): string;
begin
  case AMode of
    wmAsk: Result := 'Ask questions without editing code';
    wmPlan: Result := 'Generate architectural plans & checklists';
    wmAgent: Result := 'Autonomous coding agent with full workspace access';
  end;
end;

function PanelCaption(AId: TPanelId): string;
begin
  case AId of
    piNavigation: Result := 'Navigation & Workspace Host';
    piChat: Result := 'Chat / AI Agent Workspace';
    piReserved: Result := 'Instructions & Context';
    piUtility: Result := 'Utility Panel';
    piTerminal: Result := 'Terminal';
  end;
end;

function PanelIconSymbol(AId: TPanelId): string;
begin
  case AId of
    piNavigation: Result := '◫';
    piChat: Result := '💬';
    piReserved: Result := '📋';
    piUtility: Result := '⚙';
    piTerminal: Result := '▸';
  end;
end;

end.
