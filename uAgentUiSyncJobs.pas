unit uAgentUiSyncJobs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAgentTypes, uAgentToolBase, uAgentEngine;

type
  TAgentUiLogJobKind = (ljExecLog, ljToolError);

  TAgentUiSyncJobs = class
  public
    class procedure QueueToolCall(AEngine: TAgentEngine; const AName, AArgs: string);
    class procedure QueueToolResult(AEngine: TAgentEngine; const AName, AArgs: string;
      const AResult: TToolExecutionResult);
    class procedure QueueExecutionLog(AEngine: TAgentEngine; AIndex: Integer);
    class procedure QueueToolError(AEngine: TAgentEngine; AIndex: Integer);
  end;

implementation

type
  TAgentUiBaseJob = class
  protected
    FEngine: TAgentEngine;
    procedure RunSync; virtual; abstract;
  public
    constructor Create(AEngine: TAgentEngine);
    procedure InvokeOnMainThread;
  end;

  TAgentUiToolCallJob = class(TAgentUiBaseJob)
  private
    FName: string;
    FArgs: string;
  protected
    procedure RunSync; override;
  public
    constructor Create(AEngine: TAgentEngine; const AName, AArgs: string);
  end;

  TAgentUiToolResultJob = class(TAgentUiBaseJob)
  private
    FName: string;
    FArgs: string;
    FResult: TToolExecutionResult;
  protected
    procedure RunSync; override;
  public
    constructor Create(AEngine: TAgentEngine; const AName, AArgs: string;
      const AResult: TToolExecutionResult);
  end;

  TAgentUiLogIndexJob = class(TAgentUiBaseJob)
  private
    FIndex: Integer;
    FKind: TAgentUiLogJobKind;
  protected
    procedure RunSync; override;
  public
    constructor Create(AEngine: TAgentEngine; AIndex: Integer; AKind: TAgentUiLogJobKind);
  end;

procedure QueueUiJob(AJob: TAgentUiBaseJob);
begin
  TThread.Queue(nil, @AJob.InvokeOnMainThread);
end;

{ TAgentUiBaseJob }

constructor TAgentUiBaseJob.Create(AEngine: TAgentEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TAgentUiBaseJob.InvokeOnMainThread;
begin
  try
    RunSync;
  finally
    Free;
  end;
end;

{ TAgentUiToolCallJob }

constructor TAgentUiToolCallJob.Create(AEngine: TAgentEngine; const AName, AArgs: string);
begin
  inherited Create(AEngine);
  FName := AName;
  FArgs := AArgs;
end;

procedure TAgentUiToolCallJob.RunSync;
begin
  if Assigned(FEngine) then
    FEngine.DeliverToolCallToUI(FName, FArgs);
end;

{ TAgentUiToolResultJob }

constructor TAgentUiToolResultJob.Create(AEngine: TAgentEngine; const AName, AArgs: string;
  const AResult: TToolExecutionResult);
begin
  inherited Create(AEngine);
  FName := AName;
  FArgs := AArgs;
  FResult := AResult;
end;

procedure TAgentUiToolResultJob.RunSync;
begin
  if Assigned(FEngine) then
    FEngine.DeliverToolResultToUI(FName, FArgs, FResult);
end;

{ TAgentUiLogIndexJob }

constructor TAgentUiLogIndexJob.Create(AEngine: TAgentEngine; AIndex: Integer;
  AKind: TAgentUiLogJobKind);
begin
  inherited Create(AEngine);
  FIndex := AIndex;
  FKind := AKind;
end;

procedure TAgentUiLogIndexJob.RunSync;
begin
  if not Assigned(FEngine) then Exit;
  if FKind = ljExecLog then
    FEngine.DeliverExecutionLogToUI(FIndex)
  else
    FEngine.DeliverToolErrorToUI(FIndex);
end;

{ TAgentUiSyncJobs }

class procedure TAgentUiSyncJobs.QueueToolCall(AEngine: TAgentEngine; const AName, AArgs: string);
var
  Job: TAgentUiToolCallJob;
begin
  Job := TAgentUiToolCallJob.Create(AEngine, AName, AArgs);
  QueueUiJob(Job);
end;

class procedure TAgentUiSyncJobs.QueueToolResult(AEngine: TAgentEngine; const AName, AArgs: string;
  const AResult: TToolExecutionResult);
var
  Job: TAgentUiToolResultJob;
begin
  Job := TAgentUiToolResultJob.Create(AEngine, AName, AArgs, AResult);
  QueueUiJob(Job);
end;

class procedure TAgentUiSyncJobs.QueueExecutionLog(AEngine: TAgentEngine; AIndex: Integer);
var
  Job: TAgentUiLogIndexJob;
begin
  Job := TAgentUiLogIndexJob.Create(AEngine, AIndex, ljExecLog);
  QueueUiJob(Job);
end;

class procedure TAgentUiSyncJobs.QueueToolError(AEngine: TAgentEngine; AIndex: Integer);
var
  Job: TAgentUiLogIndexJob;
begin
  Job := TAgentUiLogIndexJob.Create(AEngine, AIndex, ljToolError);
  QueueUiJob(Job);
end;

end.