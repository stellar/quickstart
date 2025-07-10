#!/usr/bin/env python3

import json
import logging
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request
import urllib.error

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HealthCheckHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/' or self.path == '/health':
            self.handle_health_check()
        else:
            self.send_error(404)
    
    def handle_health_check(self):
        """Handle health check requests"""
        enable_core = os.getenv('ENABLE_CORE', 'false').lower() == 'true'
        enable_horizon = os.getenv('ENABLE_HORIZON', 'false').lower() == 'true'
        enable_rpc = os.getenv('ENABLE_RPC', 'false').lower() == 'true'
        
        response = {
            'status': 'healthy',
            'services': {}
        }
        
        all_healthy = True
        
        # Check stellar-core if enabled
        if enable_core:
            if self.check_stellar_core():
                response['services']['stellar-core'] = 'healthy'
            else:
                response['services']['stellar-core'] = 'unhealthy'
                all_healthy = False
        
        # Check horizon if enabled
        if enable_horizon:
            if self.check_horizon():
                response['services']['horizon'] = 'healthy'
            else:
                response['services']['horizon'] = 'unhealthy'
                all_healthy = False
        
        # Check stellar-rpc if enabled
        if enable_rpc:
            if self.check_stellar_rpc():
                response['services']['stellar-rpc'] = 'healthy'
            else:
                response['services']['stellar-rpc'] = 'unhealthy'
                all_healthy = False
        
        if not all_healthy:
            response['status'] = 'unhealthy'
            status_code = 503
        else:
            status_code = 200
        
        # Send response
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        
        response_json = json.dumps(response)
        self.wfile.write(response_json.encode('utf-8'))
        
        logger.info(f"Health check - Status: {response['status']}, Services: {response['services']}")
    
    def check_stellar_core(self):
        """Check if stellar-core is healthy"""
        try:
            with urllib.request.urlopen('http://localhost:11626/info', timeout=5) as resp:
                return resp.status == 200
        except Exception as e:
            logger.debug(f"stellar-core check failed: {e}")
            return False
    
    def check_horizon(self):
        """Check if horizon is healthy"""
        try:
            with urllib.request.urlopen('http://localhost:8001', timeout=5) as resp:
                if resp.status != 200:
                    return False
                
                data = json.load(resp)
                protocol_version = data.get('supported_protocol_version', 0)
                core_ledger = data.get('core_latest_ledger', 0)
                history_ledger = data.get('history_latest_ledger', 0)
                
                # Check that horizon is properly started and ingesting
                return protocol_version > 0 and core_ledger > 0 and history_ledger > 0
        except Exception as e:
            logger.debug(f"horizon check failed: {e}")
            return False
    
    def check_stellar_rpc(self):
        """Check if stellar-rpc is healthy"""
        try:
            request_data = {
                'jsonrpc': '2.0',
                'id': 10235,
                'method': 'getHealth'
            }
            
            req = urllib.request.Request(
                'http://localhost:8003',
                data=json.dumps(request_data).encode('utf-8'),
                headers={'Content-Type': 'application/json'}
            )
            
            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status != 200:
                    return False
                
                data = json.load(resp)
                return data.get('result', {}).get('status') == 'healthy'
        except Exception as e:
            logger.debug(f"stellar-rpc check failed: {e}")
            return False
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(format % args)

def main():
    port = 8004
    server = HTTPServer(('0.0.0.0', port), HealthCheckHandler)
    logger.info(f"Health service starting on port {port}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Health service shutting down")
        server.shutdown()

if __name__ == '__main__':
    main()