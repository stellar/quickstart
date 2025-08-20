# Stellar Quickstart Tests

This directory contains tests for the Stellar Quickstart docker container and its services.

## Health Endpoint Tests

### `test_health_endpoint.go`
- **Purpose**: Tests the custom readiness service on port 8004
- **Language**: Go
- **Endpoint**: `http://localhost:8004`  
- **Expected Response**: `{"status": "ready", "services": {...}}`
- **Usage**: `go run test_health_endpoint.go`

### `test_health_endpoint.sh`
- **Purpose**: Comprehensive testing of both health endpoints
- **Language**: Bash
- **Endpoints**: 
  - `http://localhost:8000/health` (Horizon's built-in health)
  - `http://localhost:8004` (Custom readiness service)
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

## Health Endpoints Comparison

| Endpoint | Port | Service | Response Format | Purpose |
|----------|------|---------|----------------|---------|
| `/health` | 8000 | Horizon | `{"database_connected": bool, "core_up": bool, "core_synced": bool}` | Horizon health status |
| `/` | 8004 | Custom Readiness | `{"status": "ready\|not ready", "services": {...}}` | Kubernetes-style readiness probe |

## Running Tests

### Prerequisites
- Stellar Quickstart container running with ports 8000 and 8004 exposed
- For Go tests: Go runtime installed  
- For shell tests: `curl` and `jq` installed

### Setup Container for Testing
```bash
# Start container with both ports exposed
docker run --rm -d -p "8000:8000" -p "8004:8004" --name stellar stellar/quickstart:latest --local

# Enable custom readiness service (required for port 8004 tests)
docker exec stellar mkdir -p /opt/stellar/readiness/bin
docker cp ../common/readiness/bin/ stellar:/opt/stellar/readiness/
docker cp ../common/supervisor/etc/supervisord.conf.d/readiness.conf stellar:/opt/stellar/supervisor/etc/supervisord.conf.d/
docker exec stellar supervisorctl reread
docker exec stellar supervisorctl add readiness

# Wait for services to be ready (30-60 seconds)
sleep 60
```

### Quick Test
```bash
# Test both health endpoints
./test_health_endpoint.sh

# Test only custom readiness service  
go run test_health_endpoint.go
```

### Example Output
```
[test] Starting health endpoint tests...
[test] Testing Horizon health endpoint on port 8000...
[test] ✅ SUCCESS: Horizon health endpoint reports all systems healthy!
[test] Testing custom readiness service on port 8004...
[test] ✅ SUCCESS: Custom readiness service reports all services are ready!
[test] 🎉 ALL TESTS PASSED!
```

## Custom Readiness Service

The custom readiness service (port 8004) is implemented in Python (`common/readiness/bin/readiness-service.py`) and provides enhanced health checking capabilities:

**✅ Now integrated into CI!** The health endpoint test runs automatically in GitHub Actions when `matrix.horizon` is enabled.

## CI Integration

The health endpoint test (`test_health_endpoint.go`) is now part of the GitHub Actions CI pipeline:

- **Trigger**: Runs when `matrix.horizon` is enabled
- **Timing**: Executes after Horizon is confirmed to be running
- **Logs**: Captures Horizon supervisor logs during testing
- **Matrix**: Runs on both `pubnet` and `local` network configurations

- **Auto-detection**: Automatically detects which services are enabled
- **Kubernetes-compatible**: Uses "ready"/"not ready" terminology
- **Comprehensive**: Checks individual service health  
- **Detailed reporting**: Includes nested health information from Horizon
- **Proper HTTP codes**: Returns 200 for ready, 503 for not ready
