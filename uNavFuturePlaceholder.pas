unit uNavFuturePlaceholder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes;

procedure PopulateFutureFeatureNavList(AItem: TNavigationItem; AList: TStrings);

implementation

procedure AddBullets(AList: TStrings; const ABullets: array of string);
var
  I: Integer;
begin
  for I := Low(ABullets) to High(ABullets) do
    AList.Add('• ' + ABullets[I]);
end;

procedure PopulateFutureFeatureNavList(AItem: TNavigationItem; AList: TStrings);
begin
  if not Assigned(AList) then Exit;
  AList.Clear;

  case AItem of
    niMultiAgent:
      begin
        AList.Add('Create and configure specialised AI agents that collaborate to plan, implement, review, and deliver software features.');
        AList.Add('');
        AList.Add('Planned capabilities:');
        AddBullets(AList, [
          'Custom agent creation and configuration',
          'Planning Agent',
          'Coding Agent',
          'Red-Pen Review Agent',
          'Code Review Agent',
          'Security Review Agent',
          'Business Review Agent',
          'Custom user-defined agent roles',
          'Agent workflow orchestration',
          'Human approval checkpoints',
          'Agent-to-agent handoffs',
          'Configurable execution order and review cycles'
        ]);
      end;
    niExecutionPlans:
      begin
        AList.Add('Break complex development projects into structured, numbered execution plans, track progress, and coordinate delivery across agents.');
        AList.Add('');
        AList.Add('Planned capabilities:');
        AddBullets(AList, [
          'Project-level plans',
          'Numbered execution plans (001, 002, 003...)',
          'Detailed implementation steps',
          'Central checkbox-based task tracker',
          'Task dependencies',
          'Task status and progress tracking',
          'Agent task assignment',
          'Human approval checkpoints',
          'Execution history linked to tasks',
          'Resume interrupted execution plans',
          'Plan revisions and progress reporting'
        ]);
      end;
    niKnowledgeBase:
      begin
        AList.Add('Build a searchable knowledge base for each workspace, allowing AI agents to retrieve relevant project documentation and external knowledge.');
        AList.Add('');
        AList.Add('Planned knowledge sources:');
        AddBullets(AList, [
          'Website URLs',
          'Free-text knowledge entries',
          'PDF documents',
          'Markdown files',
          'Plain-text files',
          'Confluence spaces and pages',
          'Recursive Confluence page hierarchy indexing'
        ]);
        AList.Add('');
        AList.Add('Planned capabilities:');
        AddBullets(AList, [
          'Document ingestion',
          'Content extraction and chunking',
          'Embedding model integration',
          'Vector database indexing',
          'Semantic and hybrid search',
          'Source management and reindexing',
          'Knowledge retrieval by AI agents',
          'Source references and traceability'
        ]);
      end;
    niTheBrain:
      begin
        AList.Add('An optional learning agent that learns from conversations, user corrections, project decisions, and execution outcomes to adapt AI assistance to the user''s working style.');
        AList.Add('');
        AList.Add('Planned capabilities:');
        AddBullets(AList, [
          'Optional learning, enabled by the user',
          'Learning from conversations',
          'Learning from user corrections and feedback',
          'User coding preferences',
          'Project-specific memories',
          'Lessons learned from previous executions',
          'Long-term contextual memory',
          'Memory review and management',
          'Relevant memory retrieval for other agents',
          'User-level and workspace-level memory',
          'Adaptive agent behaviour'
        ]);
      end;
  else
    AList.Add('This feature is not available yet.');
  end;
end;

end.
