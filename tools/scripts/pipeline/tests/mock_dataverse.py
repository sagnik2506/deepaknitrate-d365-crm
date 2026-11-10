"""A tiny local stand-in for the Dataverse Web API, used only to test the pipeline scripts offline (tools/scripts/pipeline/tests/Test-PipelineScripts.ps1).
It keeps a small in-memory state and records every write. It is NOT a faithful copy of Dataverse: it checks that the scripts call the expected paths with the expected bodies.
Usage: python mock_dataverse.py <port> <state.json> <log.json>   (state is loaded at start; the write log is rewritten after every write)"""
import json, re, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
port, state_file, log_file = int(sys.argv[1]), sys.argv[2], sys.argv[3]
S = json.load(open(state_file, encoding='utf-8'))
LOG = []

def save_log(): json.dump(LOG, open(log_file, 'w', encoding='utf-8'), indent=1)

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj=None):
        body = json.dumps(obj).encode('utf-8') if obj is not None else b''
        self.send_response(code); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
    def _body(self):
        n = int(self.headers.get('Content-Length') or 0); raw = self.rfile.read(n).decode('utf-8') if n else ''
        ctype = self.headers.get('Content-Type', '')
        return json.loads(raw) if raw and 'json' in ctype else raw
    def _path(self):
        u = urllib.parse.urlparse(self.path); return urllib.parse.unquote(u.path), urllib.parse.parse_qs(u.query)
    def do_POST(self):
        path, q = self._path(); body = self._body()
        if path.endswith('/oauth2/v2.0/token'): return self._send(200, {'access_token': 'mock-token', 'expires_in': 3600})
        LOG.append({'method': 'POST', 'path': path, 'body': body, 'headers': {k: v for k, v in self.headers.items() if k.startswith('MSCRM') or k == 'Prefer'}}); save_log()
        p = path.split('/api/data/v9.2/')[-1]
        if p == 'sdkmessageprocessingsteps':
            new = {'sdkmessageprocessingstepid': 'new-step-id'}; return self._send(201, new)
        if p == 'webresourceset': return self._send(201, {'webresourceid': 'new-wr-id'})
        return self._send(204)
    def do_PATCH(self):
        path, q = self._path(); body = self._body(); LOG.append({'method': 'PATCH', 'path': path, 'body': body}); save_log()
        m = re.search(r'/(\w+)\(([^)]+)\)$', path)
        if m:
            coll, key = m.group(1), m.group(2)
            rec = S.get(coll, {}).get(key)
            if rec is not None and isinstance(body, dict): rec.update(body)
        return self._send(204)
    def do_PUT(self):
        path, q = self._path(); body = self._body(); LOG.append({'method': 'PUT', 'path': path, 'body': body, 'headers': {k: v for k, v in self.headers.items() if k.startswith('MSCRM')}}); save_log()
        m = re.search(r"EntityDefinitions\(LogicalName='(\w+)'\)/Attributes\(LogicalName='(\w+)'\)$", path)
        if m: S['attributes'][m.group(1) + '.' + m.group(2)] = body
        return self._send(204)
    def do_DELETE(self):
        path, q = self._path(); LOG.append({'method': 'DELETE', 'path': path}); save_log(); return self._send(204)
    def do_GET(self):
        path, q = self._path(); p = path.split('/api/data/v9.2/')[-1]
        flt = (q.get('$filter') or [''])[0]
        if p == 'WhoAmI': return self._send(200, {'UserId': 'x'})
        m = re.match(r'(systemforms|savedqueries|workflows|pluginassemblies|webresourceset)\(([^)]+)\)$', p)
        if m:
            rec = S.get(m.group(1), {}).get(m.group(2))
            return self._send(200, rec) if rec is not None else self._send(404, {'error': 'not found'})
        m = re.match(r"(roles|webresourceset|pluginassemblies|plugintypes|sdkmessages|sdkmessagefilters|sdkmessageprocessingsteps)$", p)
        if m:
            coll = m.group(1); allrecs = list(S.get(coll, {}).values()); out = allrecs
            nm = re.search(r"name eq '([^']*)'", flt) or re.search(r"typename eq '([^']*)'", flt)
            if nm: out = [r for r in allrecs if r.get('name') == nm.group(1).replace("''", "'") or r.get('typename') == nm.group(1)]
            if coll == 'sdkmessagefilters':
                en = re.search(r"primaryobjecttypecode eq '([^']*)'", flt); out = [r for r in allrecs if en and r.get('primaryobjecttypecode') == en.group(1)]
            if coll == 'roles' and '_parentroleid_value eq null' in flt: out = [r for r in allrecs if not r.get('_parentroleid_value')]
            return self._send(200, {'value': out})
        m = re.match(r"GlobalOptionSetDefinitions\(Name='(\w+)'\)$", p)
        if m: return self._send(200, S['optionsets'][m.group(1)])
        m = re.match(r"EntityDefinitions\(LogicalName='(\w+)'\)/Attributes\(LogicalName='(\w+)'\)$", p)
        if m: return self._send(200, S['attributes'][m.group(1) + '.' + m.group(2)])
        return self._send(404, {'error': 'mock has no handler for ' + p})

HTTPServer(('127.0.0.1', port), H).serve_forever()
