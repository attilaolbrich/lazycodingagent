"""Integration fixtures for native tools. Run through tests/run_tests.sh."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

IS_WINDOWS = os.name == 'nt'

ALLOWED_TOOL_PARAM_TYPES = frozenset(
    {'string', 'integer', 'boolean', 'array', 'object', 'number'}
)

BROWSER_AUTOMATION_TOOLS = frozenset({
    'browser_navigate', 'browser_inspect', 'browser_click', 'browser_fill',
    'browser_wait', 'browser_close', 'browser_screenshot', 'browser_console',
    'browser_network', 'browser_select', 'browser_set_viewport',
    'browser_resume_automation', 'browser_pause_automation',
})


def assert_no_cross_tool_recency_enum(declarations):
    ws = None
    for decl in declarations:
        if decl['function']['name'] == 'web_search':
            ws = decl['function']['parameters'].get('properties', {}).get('recency', {})
            break
    if not ws:
        return
    recency_enum = ws.get('enum')
    assert recency_enum, 'web_search recency should have enum when advertised'
    for decl in declarations:
        if decl['function']['name'] == 'web_search':
            continue
        for param_name, param_def in (decl['function']['parameters'].get('properties') or {}).items():
            if param_def.get('enum') == recency_enum:
                raise AssertionError(
                    f'{decl["function"]["name"]}.{param_name} shares web_search recency enum')
            if param_name in ('timeout_ms', 'value', 'selector') and 'enum' in param_def:
                raise AssertionError(
                    (decl['function']['name'], param_name, param_def.get('enum')))


def assert_tool_parameter_schemas(declarations):
    for decl in declarations:
        name = decl['function']['name']
        props = decl['function']['parameters'].get('properties') or {}
        for param_name, param_def in props.items():
            param_type = param_def.get('type')
            assert param_type in ALLOWED_TOOL_PARAM_TYPES, (name, param_name, param_def)
    assert_no_cross_tool_recency_enum(declarations)


def run(driver):
    count = 0
    with tempfile.TemporaryDirectory(prefix='coding-agent-fixtures-') as temporary:
        root = Path(temporary) / 'project'
        root.mkdir()
        process = subprocess.Popen([driver, str(root)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   text=True, encoding='utf-8')
        def call(tool, args=None, mode='Agent', **extra):
            nonlocal count
            process.stdin.write(json.dumps(dict(tool=tool, args=args or {}, mode=mode, **extra))+'\n')
            process.stdin.flush()
            line = process.stdout.readline()
            assert line, f'driver exited during {tool}'
            count += 1
            return json.loads(line)
        def ok(tool, args=None, **extra):
            result = call(tool, args, **extra)
            assert 'error' not in result, (tool, result)
            return result
        def error(tool, args=None, **extra):
            result = call(tool, args, **extra)
            assert isinstance(result.get('error'), str), (tool, result)
            return result
        def patch(text):
            return ok('apply_patch', {'patch':text})
        try:
            canonical = {
                'read_file', 'write_file', 'list_directory', 'glob', 'search_code',
                'apply_patch', 'edit_file', 'shell', 'diagnostics', 'git', 'todo',
                'create_plan_file', 'web_fetch', 'browser_read',
            } | BROWSER_AUTOMATION_TOOLS
            declarations = call('_declarations')
            assert {d['function']['name'] for d in declarations} == canonical
            assert_tool_parameter_schemas(declarations)
            nav_decl = next(d for d in declarations if d['function']['name'] == 'browser_navigate')
            nav_props = nav_decl['function']['parameters'].get('properties') or {}
            assert nav_props.get('visible', {}).get('type') == 'boolean', nav_props
            readonly = {
                'read_file', 'list_directory', 'glob', 'search_code', 'diagnostics',
                'git', 'todo', 'web_fetch', 'browser_read',
            } | BROWSER_AUTOMATION_TOOLS
            ask_declarations = call('_declarations', mode='Ask')
            assert {d['function']['name'] for d in ask_declarations} == readonly
            assert_tool_parameter_schemas(ask_declarations)
            plan_declarations = call('_declarations', mode='Plan')
            assert {d['function']['name'] for d in plan_declarations} == readonly | {'create_plan_file'}
            assert_tool_parameter_schemas(plan_declarations)
            for mode in ('Ask','Plan'):
                for tool,args in [('write_file',{'path':'denied','content':'bad'}), ('terminal',{'command':'touch denied'}), ('edit_file',{'path':'denied','old_text':'a','new_text':'b'}), ('apply_patch',{'patch':'bad'}), ('diagnostics',{'action':'build','target':'bad.pas'})]:
                    error(tool, args, mode=mode)
            assert not (root/'denied').exists()
            blocked = error('web_fetch', {'url': 'http://127.0.0.1/'})
            assert blocked.get('error_kind') == 'blocked_destination', blocked
            error('web_fetch', {})
            error('web_fetch', {'url': 'ftp://example.com/'})
            blocked_br = error('browser_read', {'url': 'http://127.0.0.1/'})
            assert blocked_br.get('error_code') == 'ACCESS_DENIED', blocked_br
            error('browser_read', {})
            error('read_file', '{bad')
            error('read_file', '[]')
            error('read_file', {'path':42})
            error('write_file', {'path':'missing-content'})
            assert not (root/'missing-content').exists()
            ok('write_file', {'path':'empty.txt','content':''})
            assert ok('read_file', {'path':'empty.txt'})['lines_returned'] == 0
            error('read_file', {'path':'empty.txt','offset':2})
            for offset,limit in [(0,1),(1,0),(1,-1),(1,2001)]:
                error('read_file', {'path':'empty.txt','offset':offset,'limit':limit})
            text = 'alpha\r\nbeta\r\n'
            ok('write_file', {'path':'src/main.pas','content':text})
            assert (root / 'src/main.pas').read_bytes() == text.encode()
            assert ok('read_file', {'path':'src/main.pas','offset':2,'limit':1})['content'].startswith('2|beta')
            quoted = 'quote"name.txt'
            error('read_file', {'path':quoted})
            (root/'binary').write_bytes(b'abc\x00def')
            error('read_file', {'path':'binary'})
            (root/'invalid-encoding').write_bytes(b'\xff')
            error('read_file', {'path':'invalid-encoding'})
            if not IS_WINDOWS:
                os.mkfifo(root/'pipe')
                error('read_file', {'path':'pipe'})
                error('write_file', {'path':'pipe','content':'x'})
                (root/'pipe').unlink()
            for path in ('../escape.txt',str(Path(temporary)/'escape.txt')):
                error('write_file', {'path':path,'content':'x'})
            outside = Path(temporary)/'outside'; outside.mkdir()
            (outside/'escape.txt').write_text('outside-read', encoding='utf-8')
            assert ok('read_file', {'path': str(outside/'escape.txt')})['content'].startswith('1|outside-read')
            ok('write_file', {'path': str(outside/'wrote.txt'), 'content': 'outside-write'},
               allow_modify_outside=True)
            assert (outside/'wrote.txt').read_text() == 'outside-write'
            can_symlink = True
            try:
                (root/'link').symlink_to(outside, target_is_directory=True)
            except (OSError, NotImplementedError):
                can_symlink = False
            else:
                error('write_file', {'path':'link/new','content':'x'})
                error('list_files', {'path':'link'})
            if can_symlink:
                try:
                    (root/'.plan').symlink_to(outside, target_is_directory=True)
                except (OSError, NotImplementedError):
                    can_symlink = False
                else:
                    error('create_plan_file', {'content':'# Plan'}, mode='Plan')
                    (root/'.plan').unlink()
            assert not list(outside.iterdir())
            if can_symlink:
                (root/'.plan').symlink_to(root/'src', target_is_directory=True)
                error('create_plan_file', {'content':'# Plan'}, mode='Plan')
                assert not list((root/'src').glob('plan-*.md'))
                (root/'.plan').unlink()
                (root/'.plan').symlink_to(root/'missing-plans', target_is_directory=True)
                error('create_plan_file', {'content':'# Plan'}, mode='Plan')
                assert not (root/'missing-plans').exists()
                (root/'.plan').unlink()
            plan = ok('create_plan_file', {'content':'# Plan'}, mode='Plan')
            assert Path(plan['path']).read_text() == '# Plan'
            assert Path(plan['path']).parent == root/'.plan'
            assert Path(plan['path']).suffix == '.md'
            second_plan = ok('create_plan_file', {'content':'# Second plan'}, mode='Plan')
            assert second_plan['path'] != plan['path']
            assert Path(second_plan['path']).parent == root/'.plan'
            assert Path(second_plan['path']).suffix == '.md'
            assert Path(plan['path']).read_text() == '# Plan'
            for path in ('outside-plan.md', '.plan/custom.md', '.plan/custom.pas'):
                error('write_file', {'path':path,'content':'denied'}, mode='Plan')
                assert not (root/path).exists()
            if can_symlink:
                (root/'inside').symlink_to(root/'src', target_is_directory=True)
                assert ok('read_file', {'path':'inside/main.pas'})['total_lines'] == 2
                (root/'link').unlink()
            entries = ok('list_directory')['entries']
            assert any(e['path']=='src' and e['type']=='directory' for e in entries)
            assert [e['path'] for e in entries] == sorted(e['path'] for e in entries)
            ok('write_file', {'path':'rel/nested/file.txt','content':'relative-write'})
            assert (root/'rel'/'nested'/'file.txt').read_text() == 'relative-write'
            ok('write_file', {'path':'src/nested/unit.pas','content':'CreateUser\nCreateUser\n'})
            ok('write_file', {'path':'root.pas','content':'createuser\n'})
            ok('write_file', {'path':'.hidden.pas','content':'CreateUser\n'})
            ok('write_file', {'path':'bin/generated.pas','content':'CreateUser\n'})
            found = [e['path'] for e in ok('glob',{'pattern':'**/*.pas'})['entries']]
            assert found == ['root.pas','src/main.pas','src/nested/unit.pas'], found
            assert [e['path'] for e in ok('glob',{'pattern':'src/?ain.pas'})['entries']] == ['src/main.pas']
            assert any(e['path']=='.hidden.pas' for e in ok('glob',{'pattern':'**/*.pas','include_hidden':True})['entries'])
            assert [e['path'] for e in ok('glob', {'pattern':'src/**/*.pas','path':'src'})['entries']] == ['src/main.pas','src/nested/unit.pas']
            result = ok('grep', {'query':'CreateUser'})
            assert len(result['matches']) == 2 and result['matches'][0]['column']==1
            assert len(ok('search_code', {'query':'createuser','case_sensitive':False})['matches']) == 3
            assert len(ok('search_code', {'query':'Create.*','regex':True,'glob':'src/**/*.pas'})['matches']) == 2
            ok('write_file', {'path':'src/multi.txt','content':'needle needle\n'})
            multi = ok('search_code', {'query':'needle','path':'src','glob':'src/multi.txt'})
            (root / 'pkg').mkdir()
            (root / 'pkg' / 'package.json').write_text(
                json.dumps({'scripts': {'build': 'pwd > build-cwd.txt'}}), encoding='utf-8')
            diag_pkg = ok('diagnostics', {'action': 'build', 'target': 'pkg/package.json'})
            assert diag_pkg['status'] == 'success', diag_pkg
            assert (root / 'pkg' / 'build-cwd.txt').read_text(encoding='utf-8').strip().endswith('/pkg')
            huge = root / 'src' / 'huge.txt'
            huge.write_bytes(b'x' * (16 * 1024 * 1024 + 1))
            assert ok('search_code', {'query': 'x', 'path': 'src/huge.txt'})['matches'] == []
            assert [(m['line'],m['column']) for m in multi['matches']] == [(1,1),(1,8)], multi
            assert ok('search_code', {'query':'needle','path':'src/multi.txt'})['matches'][0]['path'] == 'src/multi.txt'
            assert len(ok('search_code', {'query':'CreateUser','include_hidden':True,'case_sensitive':False})['matches']) == 4
            assert ok('search_code', {'query':'nothing'})['matches'] == []
            error('search_code', {'query':'[','regex':True})
            for index in range(510):
                (root/f'item-{index:03d}.txt').write_text('needle\n')
            result = ok('glob', {'pattern':'item-*'})
            assert len(result['entries']) == 500 and result['truncated']
            result = ok('search_code', {'query':'needle'})
            assert len(result['matches']) == 500 and result['truncated']
            patch('--- a/src/main.pas\n+++ b/src/main.pas\n@@ -1,2 +1,2 @@\n alpha\n-beta\n+gamma\n')
            assert (root/'src/main.pas').read_bytes() == 'alpha\r\ngamma\r\n'.encode()
            # A response wrapper and CRLF transport must not alter hunk text.
            patch('Here is the requested change:\r\n```diff\r\n--- a/src/main.pas\r\n+++ b/src/main.pas\r\n@@ -2 +2 @@\r\n-gamma\r\n+wrapped\r\n```\r\nThis is ready to apply.\r\n')
            assert (root/'src/main.pas').read_bytes() == 'alpha\r\nwrapped\r\n'.encode()
            ok('edit_file',{'path':'src/main.pas','old_text':'wrapped','new_text':'delta'})
            assert (root/'src/main.pas').read_bytes() == 'alpha\r\ndelta\r\n'.encode()
            error('edit_file',{'path':'src/nested/unit.pas','old_text':'CreateUser','new_text':'x'})
            original = (root/'src/main.pas').read_bytes()
            error('apply_patch',{'patch':'--- a/src/main.pas\n+++ b/src/main.pas\n@@ -1 +1 @@\n-alpha\n+new\n--- a/root.pas\n+++ b/root.pas\n@@ -1 +1 @@\n-mismatch\n+new\n'})
            assert (root/'src/main.pas').read_bytes() == original
            patch('--- /dev/null\n+++ b/patch-empty.txt\n@@ -0,0 +0,0 @@\n')
            assert (root/'patch-empty.txt').read_bytes() == b''
            patch('--- /dev/null\n+++ b/new.txt\n@@ -0,0 +1 @@\n+hello\n')
            assert (root/'new.txt').read_bytes()==b'hello\n'
            patch('The following is the change:\n--- /dev/null\n+++ b/prose-wrapped.txt\n@@ -0,0 +1 @@\n+hello\nApplied successfully.\n')
            assert (root/'prose-wrapped.txt').read_bytes()==b'hello\n'
            patch('--- a/new.txt\n+++ /dev/null\n@@ -1 +0,0 @@\n-hello\n')
            assert not (root/'new.txt').exists()
            (root/'nonewline').write_bytes(b'old')
            patch('--- a/nonewline\n+++ b/nonewline\n@@ -1 +1 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n')
            assert (root/'nonewline').read_bytes()==b'new'
            error('apply_patch',{'patch':'--- /dev/null\n+++ b/../escape.txt\n@@ -0,0 +1 @@\n+x\n'})
            stale = error('apply_patch',{'patch':'--- a/root.pas\n+++ b/root.pas\n@@ -1 +1 @@\n-wrongline\n+new\n'})
            assert 'context mismatch' in stale['error'].lower() and 'reread' in stale['error'].lower(), stale
            assert stale['error_kind'] == 'context_mismatch' and stale['path'].endswith('root.pas') and stale['line'] == 1, stale
            bad_format = error('apply_patch',{'patch':'*** Begin Patch\n*** Update File: root.pas\n'})
            assert 'unsupported patch format' in bad_format['error'].lower(), bad_format
            assert bad_format['error_kind'] == 'format', bad_format
            hunk_skew = error('apply_patch', {'patch': '--- a/root.pas\n+++ b/root.pas\n@@ -1,2 +1,1 @@\n createuser\n-old2\n+merged\n+extra\n'})
            assert hunk_skew['error_kind'] in ('hunk_count_mismatch', 'context_mismatch'), hunk_skew
            incomplete = error('apply_patch', {'patch': '--- a/root.pas\n+++ b/root.pas\n@@ -1,2 +1,1 @@\n createuser\n-onlynew\n'})
            assert incomplete['error_kind'] in ('incomplete_hunk', 'context_mismatch'), incomplete
            assert 'hint' in incomplete, incomplete
            index_html = '\n'.join([
                'pad1', 'pad2', 'pad3', 'pad4', 'pad5',
                '<meta name="description" content="Maya Chen">',
                'pad7',
                '<title>Maya Chen</title>',
                'pad9',
                '<header>Maya Chen</header>',
                'pad11',
                '<section>Hi Maya</section>',
            ]) + '\n'
            ok('write_file', {'path': 'index.html', 'content': index_html})
            wrong_count = patch(
                '--- a/index.html\n+++ b/index.html\n'
                '@@ -6,3 +6,3 @@\n'
                '-<meta name="description" content="Maya Chen">\n'
                '+<meta name="description" content="Attila Olbrich">\n'
                '@@ -8,1 +8,1 @@\n'
                '-<title>Maya Chen</title>\n'
                '+<title>Attila Olbrich</title>\n'
                '@@ -10,1 +10,1 @@\n'
                '-<header>Maya Chen</header>\n'
                '+<header>Attila Olbrich</header>\n'
                '@@ -12,1 +12,1 @@\n'
                '-<section>Hi Maya</section>\n'
                '+<section>Hi Attila</section>\n'
            )
            assert wrong_count.get('status') == 'success', wrong_count
            assert any('adjusted @@ counts' in w for w in wrong_count.get('warnings', [])), wrong_count
            updated = (root / 'index.html').read_text()
            assert 'Attila Olbrich' in updated and 'Maya Chen' not in updated
            stale_hint = error('apply_patch', {'patch': '--- a/index.html\n+++ b/index.html\n@@ -6,1 +6,1 @@\n-wrong\n+new\n'})
            assert stale_hint['error_kind'] == 'context_mismatch', stale_hint
            assert stale_hint.get('hint'), stale_hint
            # Detect changes without Git, including hidden files and deletion.
            (root/'pre-existing').write_text('already changed')
            (root/'remove-me').write_text('old')
            (root/'modify-me').write_text('old')
            if IS_WINDOWS:
                setup_command = 'echo new>modify-me & del /q remove-me & echo config>.config & mkdir .plan bin & type nul > .plan\\ignored & type nul > bin\\ignored & echo created>created'
                true_command = 'ver > nul'
                terminal_command = 'echo out & echo err 1>&2 & exit /b 7'
                output_command = 'python -c "import os; os.write(1,b\'x\'*1100000); os.write(2,b\'y\'*1100000)"'
                invalid_output_command = 'python -c "import os; os.write(1,bytes([255,195]))"'
                timeout_command = 'ping 127.0.0.1 -n 11 > nul'
                before_cancel_command = 'type nul > before-cancel & ' + timeout_command
            else:
                setup_command = "printf new > modify-me; rm remove-me; printf config > .config; mkdir -p .plan bin; touch .plan/ignored bin/ignored; printf created > created"
                true_command = 'true'
                terminal_command = 'printf out; printf err >&2; exit 7'
                output_command = 'python3 -c "import os; os.write(1,b\'x\'*1100000); os.write(2,b\'y\'*1100000)"'
                invalid_output_command = "python3 -c \"import os; os.write(1,bytes([255,195]))\""
                timeout_command = 'sleep 10 & echo $! > child.pid; wait'
                before_cancel_command = 'touch before-cancel; sleep 10'
            result = ok('shell', {'command': setup_command})
            assert set(result['changed_paths']) == {str(root/p) for p in ('modify-me','remove-me','.config','created')}, result
            result = ok('shell', {'command':true_command})
            assert result['changed_paths']==[], result
            # Unsupported entries cause an explicit warning without losing command results.
            if not IS_WINDOWS:
                os.mkfifo(root/'tracking-pipe')
                result = ok('shell', {'command':'printf still-runs'})
                assert result['stdout']=='still-runs' and 'incomplete' in result['tracking_warning']
                (root/'tracking-pipe').unlink()
            assert ok('terminal',{'command':terminal_command})['exit_code']==7
            result = ok('shell',{'command':output_command})
            assert len(result['stdout'])==1024*1024 and len(result['stderr'])==1024*1024
            assert result['stdout_truncated'] and result['stderr_truncated']
            result = ok('shell', {'command':invalid_output_command})
            assert result['stdout'] == '\ufffd\ufffd'
            started=time.monotonic()
            result = ok('shell',{'command':timeout_command,'timeout_ms':100})
            assert result['timed_out']
            assert time.monotonic() - started < 12, 'shell timeout should stop quickly when SIGKILL works'
            if not IS_WINDOWS:
                child=int((root/'child.pid').read_text())
                time.sleep(.05)
                status=subprocess.run(['ps','-p',str(child),'-o','stat='],text=True,capture_output=True,check=False)
                process_state=status.stdout.strip()
                assert not process_state or process_state.startswith('Z'), 'child still running'
            result = ok('shell',{'command':timeout_command}, cancel_after_ms=100)
            assert result['cancelled']
            result = ok('shell',{'command':before_cancel_command}, cancel_after_ms=100)
            assert result['cancelled'] and str(root/'before-cancel') in result['changed_paths']
            error('shell',{'command':'true','timeout_ms':600001})
            error('git',{'operation':'status'})
            subprocess.run(['git','init','-q',str(root)],check=True)
            subprocess.run(['git','-C',str(root),'add','root.pas'],check=True)
            subprocess.run(['git','-C',str(root),'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','initial'],check=True)
            for operation in ('status','diff','log','show'):
                assert ok('git',{'operation':operation}, mode='Ask')['exit_code']==0
            error('git',{'operation':'reset'})
            error('git',{'operation':'show','revision':'--help'})
            ok('write_file',{'path':'ok.pas','content':'program ok; begin end.\n'})
            result = ok('diagnostics',{'action':'build','target':'ok.pas'})
            assert result['status']=='success' and result['target'].endswith('ok.pas')
            assert result['runner'].lower() == 'fpc' and result['compiler'].lower() == 'fpc'
            assert isinstance(result.get('stdout'), str) and isinstance(result.get('stderr'), str)
            resolve = ok('_resolve_build', target='ok.pas')
            assert resolve['runner'] == 'fpc' and resolve['executable'] == 'fpc'
            parsed = ok('_parse_diagnostics', text='src/main.pas(2,3): Error: bad symbol\nWarning: generic\n')
            assert any(m.get('path') == 'src/main.pas' and m['line'] == 2 for m in parsed)
            ok('write_file', {'path': 'touch.ran', 'content': ''})
            cmd = 'echo touched>touch.ran' if IS_WINDOWS else 'touch touch.ran'
            result = ok('diagnostics', {'action': 'build', 'command': cmd})
            assert result['status'] == 'success' and result['runner'] == 'shell'
            assert (root / 'touch.ran').exists()
            assert str(root / 'touch.ran') in result['changed_paths']
            assert not (root/'ok.ran').exists()
            assert ok('diagnostics',{'action':'read'},mode='Ask')['target']==result['target']
            ok('write_file',{'path':'bad.pas','content':'program bad; begin MissingIdentifier; end.\n'})
            result = ok('diagnostics',{'action':'build','target':'bad.pas'})
            assert result['status']=='failed' and any(m.get('line')==1 and m['severity']=='error' for m in result['messages'])
            assert any(m.get('path', '').lower().endswith('bad.pas') for m in result['messages']), result['messages']
            error('diagnostics',{'action':'build'})
            tasks=[{'id':'one','text':'Refactor','status':'in_progress'},{'id':'two','text':'Verify','status':'pending'}]
            assert ok('plan',{'action':'replace','items':tasks},mode='Plan')['items']==tasks
            assert ok('todo',{'action':'read'},mode='Ask')['items']==tasks
            error('todo',{'action':'replace','items':tasks+[tasks[0]]})
            assert ok('todo',{'action':'read'})['items']==tasks
            error('todo',{'action':'replace','items':[{'id':'x','text':'x','status':'unknown'}]})
            assert ok('_fallback',text='```json\n'+json.dumps({'name':'grep','arguments':{'query':'needle'}})+'\n```')['total_matches']==500
            ok('_clear')
            assert ok('todo',{'action':'read'})['items']==[]
            assert ok('diagnostics',{'action':'read'})['status']=='unavailable'
            isolated = subprocess.run([driver,str(root)], input=json.dumps({'tool':'search_code','args':{'query':'__native_search_no_path__'}})+'\n'+json.dumps({'tool':'git','args':{'operation':'status'}})+'\n', env={**os.environ,'PATH':'/nonexistent'}, text=True, encoding='utf-8', capture_output=True, timeout=5)
            assert isolated.returncode == 0
            unavailable = [json.loads(line) for line in isolated.stdout.splitlines()]
            assert unavailable[0]['matches'] == [] and 'error' not in unavailable[0]
            assert 'Git' in unavailable[1]['error']
            print(f'Local tool integration tests passed ({count} tool calls plus native-search dependency fixture).')
        finally:
            process.stdin.close()
            process.wait(timeout=5)
            assert process.returncode==0

if __name__ == '__main__':
    run(sys.argv[1])
