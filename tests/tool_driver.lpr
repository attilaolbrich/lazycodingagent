program tool_driver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, fpjson, jsonparser,
  uAppTypes, uAgentTypes, uAgentToolBase, uAgentTools, uBuildTargetResolver, uDiagnosticParse,
  uChatContextManager, uWebSearchConfig, uWebSearchTypes, uWebSearchSecrets;

function ParseMode(const S: string): TWorkspaceMode;
begin
  if SameText(S, 'Ask') then Exit(wmAsk);
  if SameText(S, 'Plan') then Exit(wmPlan);
  Result := wmAgent;
end;

function ToolDefToDeclaration(const Def: TToolDef): TJSONObject;
var
  FnObj, Params: TJSONObject;
  ParamData: TJSONData;
begin
  Result := TJSONObject.Create;
  Result.Add('type', 'function');
  FnObj := TJSONObject.Create;
  FnObj.Add('name', Def.Name);
  FnObj.Add('description', Def.Description);
  ParamData := GetJSON(ToolDefToParametersJson(Def));
  if ParamData is TJSONObject then
    FnObj.Add('parameters', TJSONObject(ParamData))
  else begin
    ParamData.Free;
    Params := TJSONObject.Create;
    Params.Add('type', 'object');
    Params.Add('properties', TJSONObject.Create);
    Params.Add('required', TJSONArray.Create);
    FnObj.Add('parameters', Params);
  end;
  Result.Add('function', FnObj);
end;

function ExtractJsonFence(const Text: string): string;
var
  Marker: string;
  StartI, EndI: Integer;
begin
  Marker := '```json';
  StartI := Pos(Marker, Text);
  if StartI = 0 then Exit('');
  StartI := StartI + Length(Marker);
  if (StartI <= Length(Text)) and (Text[StartI] in [#10, #13]) then
  begin
    if (Text[StartI] = #13) and (StartI < Length(Text)) and (Text[StartI + 1] = #10) then
      StartI := StartI + 2
    else
      Inc(StartI);
  end;
  EndI := Pos('```', Copy(Text, StartI, MaxInt));
  if EndI = 0 then Exit('');
  Result := Trim(Copy(Text, StartI, EndI - 1));
end;

var
  Line, Name, Args, ModeStr, TargetPath, FenceText, CallName, CallArgs: string;
  CallObj: TJSONObject;
  A, OutObj: TJSONObject;
  Context: TAgentToolContext;
  Registry: TAgentToolRegistry;
  D: TJSONArray;
  I: Integer;
  Mode: TWorkspaceMode;
  Res: TToolExecutionResult;
  Inv: TBuildInvocation;
  Messages: TJSONArray;
  Cfg: TWebSearchGlobalConfig;
begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: tool_driver <project_root>');
    Halt(2);
  end;

  Context := TAgentToolContext.Create(ParamStr(1));
  Context.SetCancelFlag(nil);
  Registry := TAgentToolRegistry.Create(Context);
  try
    while not EOF(Input) do
    begin
      ReadLn(Line);
      if Trim(Line) = '' then Continue;
      try
        A := TJSONObject(GetJSON(Line));
        try
          ModeStr := A.Get('mode', 'Agent');
          Mode := ParseMode(ModeStr);
          Name := A.Get('tool', '');
          Context.AllowModifyOutsideWorkspace := A.Get('allow_modify_outside', False);
          Context.SetCancelDeadline(0);
          if A.Get('cancel_after_ms', 0) > 0 then
            Context.SetCancelDeadline(GetTickCount64 + QWord(A.Get('cancel_after_ms', 0)));

          if Name = '_clear' then
          begin
            Context.ClearSession;
            WriteLn('{}');
          end
          else if Name = '_resolve_build' then
          begin
            TargetPath := A.Get('target', '');
            FillChar(Inv, SizeOf(Inv), 0);
            try
              if not ResolveBuildInvocation(ParamStr(1), TargetPath, Inv) then
                WriteLn('{"error":"resolve failed"}')
              else
              begin
                OutObj := TJSONObject.Create;
                try
                  OutObj.Add('runner', Inv.RunnerLabel);
                  OutObj.Add('executable', Inv.Executable);
                  OutObj.Add('target', Inv.ResolvedTarget);
                  OutObj.Add('use_shell', Inv.UseShell);
                  if Inv.UseShell then
                    OutObj.Add('shell_command', Inv.ShellCommand)
                  else
                    OutObj.Add('args', Inv.Args.CommaText);
                  WriteLn(OutObj.AsJSON);
                finally
                  OutObj.Free;
                end;
              end;
            finally
              FreeBuildInvocation(Inv);
            end;
          end
          else if Name = '_parse_diagnostics' then
          begin
            Messages := TJSONArray.Create;
            try
              ParseCompilerOutput(A.Get('text', ''), Messages);
              WriteLn(Messages.AsJSON);
            finally
              Messages.Free;
            end;
          end
          else if Name = '_fallback' then
          begin
            FenceText := ExtractJsonFence(A.Get('text', ''));
            if FenceText = '' then
              WriteLn(ToolError('No JSON tool call found in text'))
            else
            begin
              CallObj := TJSONObject(GetJSON(FenceText));
              try
                CallName := CallObj.Get('name', '');
                if CallObj.Find('arguments') <> nil then
                  CallArgs := CallObj.Find('arguments').AsJSON
                else
                  CallArgs := '{}';
                Res := Registry.ExecuteTool(CallName, CallArgs, Mode);
                WriteLn(Res.Output);
              finally
                CallObj.Free;
              end;
            end;
          end
          else if Name = '_context_is_limit_error' then
          begin
            OutObj := TJSONObject.Create;
            try
              OutObj.Add('match', IsContextLengthError(A.Get('text', '')));
              WriteLn(OutObj.AsJSON);
            finally
              OutObj.Free;
            end;
          end
          else if Name = '_context_finish_truncated' then
          begin
            OutObj := TJSONObject.Create;
            try
              OutObj.Add('truncated', FinishReasonIndicatesTruncation(A.Get('reason', '')));
              WriteLn(OutObj.AsJSON);
            finally
              OutObj.Free;
            end;
          end
          else if Name = '_json_wellformed' then
          begin
            if A.Find('args') = nil then Args := '{}'
            else if A.Types['args'] = jtString then Args := A.Get('args', '{}')
            else Args := A.Find('args').AsJSON;
            OutObj := TJSONObject.Create;
            try
              OutObj.Add('wellformed', JsonToolArgumentsWellFormed(Args));
              WriteLn(OutObj.AsJSON);
            finally
              OutObj.Free;
            end;
          end
          else if Name = '_web_search_test_setup' then
          begin
            Cfg := DefaultWebSearchGlobalConfig;
            Cfg.Enabled := A.Get('enabled', False);
            if A.Find('connections') <> nil then
            begin
              { minimal: single brave connection with fake id if enabled flag set }
              SetLength(Cfg.Connections, 1);
              Cfg.Connections[0].Id := 'test-brave-conn';
              Cfg.Connections[0].Name := 'Test Brave';
              Cfg.Connections[0].Kind := wspkBrave;
              Cfg.Connections[0].Enabled := True;
              Cfg.Connections[0].Priority := 1;
              Cfg.Connections[0].TimeoutMs := 5000;
              SetWebSearchApiKey('test-brave-conn', 'test-key');
            end;
            SetWebSearchConfigOverrideForTests(Cfg);
            WriteLn('{}');
          end
          else if Name = '_web_search_test_teardown' then
          begin
            ClearWebSearchConfigOverrideForTests;
            ClearWebSearchApiKey('test-brave-conn');
            WriteLn('{}');
          end
          else if Name = '_declarations' then
          begin
            D := TJSONArray.Create;
            try
              for I := 0 to Registry.ToolCount - 1 do
              begin
                if not Registry.GetTool(I).IsAdvertised(Mode) then Continue;
                if not Registry.GetTool(I).ToolAllowedInMode(Mode) then Continue;
                D.Add(ToolDefToDeclaration(Registry.GetTool(I).GetDefinition));
              end;
              WriteLn(D.AsJSON);
            finally
              D.Free;
            end;
          end
          else
          begin
            if A.Find('args') = nil then Args := '{}'
            else if A.Types['args'] = jtString then Args := A.Get('args', '{}')
            else Args := A.Find('args').AsJSON;
            Res := Registry.ExecuteTool(Name, Args, Mode);
            WriteLn(Res.Output);
          end;
        finally
          A.Free;
        end;
      except
        on E: Exception do
          WriteLn(ToolError(E.Message));
      end;
      Flush(Output);
    end;
  finally
    Registry.Free;
    Context.Free;
  end;
end.
