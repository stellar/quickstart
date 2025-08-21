#!/bin/bash

# test_health_endpoint.sh - Health endpoint testing
#
# This script tests the /health endpoint that provides comprehensive
# readiness information for all services.
#
# Usage: ./test_health_endpoint.sh
# 
# The script will exit with status 0 if the test passes, 1 if it fails.

# Colors for output
GREEN='\033[32;1m'
RED='\033[31;1m'
NC='\033[0m' # No Color

log_test() {
    echo -e "${GREEN}[test]${NC} $*"
}

log_error() {
    echo -e "${RED}[test]${NC} $*"
}

# Test the /health endpoint through nginx on port 8000
test_health_endpoint() {
    log_test "Testing /health endpoint through nginx on port 8000..."
    
    local timeout=60
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            log_error "❌ TIMEOUT: Health endpoint did not become ready"
            return 1
        fi
        
        local response=$(curl -s -w "HTTP_STATUS:%{http_code}" http://localhost:8000/health)
        local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
        
        log_test "Response status: $http_status"
        
        if [ "$http_status" = "200" ]; then
            local status=$(echo "$body" | jq -r '.status // "unknown"')
            log_test "Response data: $body"
            
            if [ "$status" = "ready" ]; then
                log_test "✅ SUCCESS: Health endpoint reports all services are ready!"
                return 0
            else
                log_test "Status is: $status"
            fi
        else
            log_test "Non-200 status code: $http_status"
        fi
        
        log_test "Waiting 5 seconds before retry..."
        sleep 5
    done
}

# Main test execution
main() {
    log_test "Starting health endpoint test..."
    
    # Test the new /health endpoint
    if test_health_endpoint; then
        log_test "🎉 HEALTH ENDPOINT TEST PASSED!"
        exit 0
    else
        log_error "❌ Health endpoint test failed"
        exit 1
    fi
}

main "$@"
