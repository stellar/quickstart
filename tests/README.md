# Stellar Quickstart Tests

This directory contains tests for the Stellar Quickstart docker container and its services.

## Health Endpoint Tests

### `test_health_endpoint.go`
- **Purpose**: Tests the health endpoint through nginx proxy
- **Language**: Go
- **Endpoint**: `http://localhost:8000/health` (proxied to internal readiness service)
- **Expected Response**: `{"status": "ready", "services": {...}}`
- **Timeout**: 6 minutes (readiness service handles startup sequence properly)
- **Usage**: `go run test_health_endpoint.go`

### `test_health_endpoint.sh`
- **Purpose**: Comprehensive testing of the health endpoint
- **Language**: Bash
- **Endpoint**: `http://localhost:8000/health` (proxied to internal readiness service)
- **Dependencies**: `curl`, `jq`
- **Usage**: `./test_health_endpoint.sh`

## Other Service Tests

### Core Services
- `test_core.go` - Tests stellar-core functionality
- `test_horizon_core_up.go` - Tests Horizon-Core connectivity
- `test_horizon_ingesting.go` - Tests Horizon ledger ingestion
- `test_horizon_up.go` - Tests Horizon service availability

### RPC Services  
- `test_stellar_rpc_healthy.go` - Tests Stellar RPC health
- `test_stellar_rpc_up.go` - Tests Stellar RPC availability

### Other Services
- `test_friendbot.go` - Tests Friendbot funding functionality

## Health Endpoint Architecture

The health endpoint is served through a multi-layer architecture:

| Layer | Port | Service | Purpose |
|-------|------|---------|---------|
| **External Access** | 8000 | Nginx | Main HTTP proxy, exposes `/health` endpoint to host |
| **Internal Service** | 8004 | Custom Readiness Service | Comprehensive health checking of all services |

### Response Format
The health endpoint returns a Kubernetes-style readiness response:
```json
{
  "status": "ready|not ready",
  "services": {
    "stellar-core": "ready",
    "horizon": "ready", 
    "stellar-rpc": "ready"
  }
}
```

_Note: Port 8004 is internal-only and not exposed to the host. All health checks should use `http://localhost:8000/health`._

## Running Tests

### Prerequisites
- Stellar Quickstart container running with port 8000 exposed
- For Go tests: Go runtime installed  
- For shell tests: `curl` and `jq` installed

### Setup Container for Testing
```bash
# Start container with main port exposed (readiness service runs internally)
docker run --rm -d -p "8000:8000" --name stellar stellar/quickstart:latest --local

# Wait for services to be ready (30-60 seconds for local, 2-3 minutes for pubnet)
sleep 60
```

_Note: The readiness service should be built into the Docker image by default. If it's not running, you may need to manually start it or rebuild the image._

### Quick Test
```bash
# Test the health endpoint (proxied through nginx)
./test_health_endpoint.sh

# Test the health endpoint using Go
go run test_health_endpoint.go
```

### Example Output
```
[test] Testing health endpoint...
[test] HTTP Status: 200
[test] Response: {"status": "ready", "services": {...}}
[test] ✅ Status field found: ready
[test] ✅ Services field found
[test] 🎉 Health endpoint is working correctly with readiness service!
```

## Custom Readiness Service

The custom readiness service runs internally on port 8004 and provides enhanced health checking capabilities. It's implemented in Python (`common/readiness/bin/readiness-service.py`) and is proxied through nginx on port 8000.

**Smart Startup Handling**: The readiness service intelligently handles the startup sequence by considering Horizon ready when Stellar-Core is syncing, even if Horizon hasn't ingested ledgers yet. This prevents false negatives during the normal startup process.

**✅ Now integrated into CI!** The health endpoint test runs automatically in GitHub Actions when `matrix.horizon` is enabled.

## CI Integration

The health endpoint test (`test_health_endpoint.go`) is now part of the GitHub Actions CI pipeline:

- **Trigger**: Runs when `matrix.horizon` is enabled
- **Timing**: Executes after Horizon is confirmed to be running
- **Logs**: Captures Horizon supervisor logs during testing
- **Matrix**: Runs on both `pubnet` and `local` network configurations
- **Timeout**: 6 minutes (readiness service handles startup sequence properly)

- **Auto-detection**: Automatically detects which services are enabled
- **Kubernetes-compatible**: Uses "ready"/"not ready" terminology
- **Comprehensive**: Checks individual service health  
- **Detailed reporting**: Includes nested health information from Horizon
- **Proper HTTP codes**: Returns 200 for ready, 503 for not ready
- **Internal architecture**: Runs on port 8004, proxied through nginx on port 8000
