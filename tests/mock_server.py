"""Deterministic local JSON-RPC mock. Never connects to IBM i."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_error(405)
    do_PUT = do_GET
    do_DELETE = do_GET

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        status = 200
        try:
            request = json.loads(raw)
        except (ValueError, UnicodeDecodeError):
            response = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}
            self.reply(400, response)
            return
        if not isinstance(request, dict) or request.get("jsonrpc") != "2.0" or not isinstance(request.get("method"), str):
            self.reply(400, {"jsonrpc": "2.0", "id": request.get("id") if isinstance(request, dict) else None,
                             "error": {"code": -32600, "message": "Invalid Request"}})
            return
        method = request["method"]
        ident = request.get("id")
        if method == "notifications/initialized":
            self.send_response(202)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if method == "initialize":
            result = {"protocolVersion": "2025-11-25", "capabilities": {}, "serverInfo": {"name": "local-mock", "version": "1"}}
        elif method == "tools/list":
            result = {"tools": [{"name": "ibmi_get_customer", "inputSchema": {"type": "object"}},
                                {"name": "ibmi_simulate_credit", "inputSchema": {"type": "object"}}]}
        elif method == "tools/call":
            name = request.get("params", {}).get("name")
            if name not in ("ibmi_get_customer", "ibmi_simulate_credit"):
                self.reply(200, {"jsonrpc": "2.0", "id": ident, "error": {"code": -32602, "message": "Unknown tool"}})
                return
            result = {"content": [{"type": "text", "text": "mock-only"}], "isError": False}
        else:
            self.reply(200, {"jsonrpc": "2.0", "id": ident, "error": {"code": -32601, "message": "Method not found"}})
            return
        self.reply(status, {"jsonrpc": "2.0", "id": ident, "result": result})

    def reply(self, status, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
