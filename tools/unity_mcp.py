"""Invoke the project's local Unity MCP server through its public MCP protocol."""

import argparse
import json
import urllib.request


class UnityMcp:
    def __init__(self, endpoint="http://127.0.0.1:8080/mcp"):
        self.endpoint = endpoint
        self.headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        self.sequence = 0
        self.request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "wukong-clone", "version": "1.0"},
            },
        )
        self.request("notifications/initialized", notification=True)

    def request(self, method, params=None, notification=False):
        self.sequence += 1
        payload = {"jsonrpc": "2.0", "method": method}
        if not notification:
            payload["id"] = self.sequence
        if params is not None:
            payload["params"] = params
        request = urllib.request.Request(
            self.endpoint,
            data=json.dumps(payload).encode(),
            headers=self.headers,
        )
        with urllib.request.urlopen(request, timeout=180) as response:
            session = response.headers.get("Mcp-Session-Id")
            if session:
                self.headers["Mcp-Session-Id"] = session
            raw = response.read().decode()
        if not raw:
            return None
        if any(line.startswith("data: ") for line in raw.splitlines()):
            events = [
                json.loads(line[6:])
                for line in raw.splitlines()
                if line.startswith("data: ")
            ]
            result = next(
                (event for event in events if event.get("id") == payload.get("id")),
                events[-1] if events else {},
            )
        else:
            result = json.loads(raw)
        if "error" in result:
            raise RuntimeError(json.dumps(result["error"], ensure_ascii=False))
        return result.get("result")

    def select(self, instance):
        return self.request(
            "tools/call",
            {"name": "set_active_instance", "arguments": {"instance": instance}},
        )

    def read(self, uri):
        return self.request("resources/read", {"uri": uri})

    def call(self, name, arguments):
        result = self.request("tools/call", {"name": name, "arguments": arguments})
        structured = result.get("structuredContent")
        if result.get("isError") or (structured and structured.get("success") is False):
            raise RuntimeError(json.dumps(structured or result, ensure_ascii=False))
        return structured or result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", default="http://127.0.0.1:8080/mcp")
    parser.add_argument("--instance")
    parser.add_argument("kind", choices=["resource", "tool", "tools"])
    parser.add_argument("name", nargs="?")
    parser.add_argument("--args", default="{}")
    parser.add_argument("--args-file")
    options = parser.parse_args()
    client = UnityMcp(options.endpoint)
    if options.instance:
        client.select(options.instance)
    if options.kind == "resource":
        result = client.read(options.name)
    elif options.kind == "tools":
        result = client.request("tools/list")
    else:
        if options.args_file:
            with open(options.args_file, encoding="utf-8") as source:
                arguments = json.load(source)
        else:
            arguments = json.loads(options.args)
        result = client.call(options.name, arguments)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
