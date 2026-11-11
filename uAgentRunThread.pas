unit uAgentRunThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes, uAgentTypes, uAgentEngine;

type
  TAgentRunThread = class(TThread)
  private
    FEngine: TAgentEngine;
    FUserPrompt: string;
    FAttachments: TChatAttachmentArray;
    FMode: TWorkspaceMode;
    FModel: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AEngine: TAgentEngine; const AUserPrompt: string;
      const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
      const AModel: string);
  end;

implementation

constructor TAgentRunThread.Create(AEngine: TAgentEngine; const AUserPrompt: string;
  const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
  const AModel: string);
var
  I: Integer;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FEngine := AEngine;
  FUserPrompt := AUserPrompt;
  SetLength(FAttachments, Length(AAttachments));
  for I := 0 to High(AAttachments) do
    FAttachments[I] := AAttachments[I];
  FMode := AMode;
  FModel := AModel;
end;

procedure TAgentRunThread.Execute;
begin
  try
    try
      FEngine.ExecuteRun(FUserPrompt, FAttachments, FMode, FModel);
    except
      on E: Exception do
        FEngine.ReportRunException(E);
    end;
  finally
    FEngine.RunThreadFinished;
  end;
end;

end.
