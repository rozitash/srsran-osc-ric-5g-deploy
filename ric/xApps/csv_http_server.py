#!/usr/bin/env python3
"""
csv_http_server.py

Simple HTTP server that serves the KPI_Metrics.csv file on port 3030,
allowing Grafana's Infinity datasource to read it via HTTP.
"""

import http.server
import os
import sys

PORT = 3030
SERVE_DIR = os.environ.get("XAPP_LOGS_DIR", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "logs"))


class CORSHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler with CORS headers for Grafana access."""

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        # Suppress request logs to keep output clean
        pass


def main():
    os.chdir(SERVE_DIR)
    print(f"[HTTP] Serving {SERVE_DIR} on port {PORT}")
    print(f"[HTTP] CSV available at http://localhost:{PORT}/KPI_Metrics.csv")

    server = http.server.HTTPServer(("0.0.0.0", PORT), CORSHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[HTTP] Server stopped.")
        sys.exit(0)


if __name__ == "__main__":
    main()
