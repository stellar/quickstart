#!/bin/bash

# test_health_endpoint.sh - Comprehensive health endpoint testing
#
# This script tests both health endpoints:
# 1. Horizon's built-in health endpoint (port 8000/health) 
# 2. Our custom readiness service (port 8004)
#
# Usage: ./test_health_endpoint.sh
# 
# The script will exit with status 0 if all tests pass, 1 if any fail.

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

# Test our custom readiness service on port 8004
test_custom_readiness() {
    log_test "Testing custom readiness service on port 8004..."
    
    local timeout=60
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            log_error "❌ TIMEOUT: Custom readiness service did not become ready"
            return 1
        fi
        
        local response=$(curl -s -w "HTTP_STATUS:%{http_code}" http://localhost:8004)
        local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
        
        log_test "Response status: $http_status"
        
        if [ "$http_status" = "200" ]; then
            local status=$(echo "$body" | jq -r '.status // "unknown"')
            log_test "Response data: $body"
            
            if [ "$status" = "ready" ]; then
                log_test "✅ SUCCESS: Custom readiness service reports all services are ready!"
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

# Test Horizon's health endpoint on port 8000
test_horizon_health() {
    log_test "Testing Horizon health endpoint on port 8000..."
    
    local response=$(curl -s -w "HTTP_STATUS:%{http_code}" http://localhost:8000/health)
    local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    log_test "Response status: $http_status"
    
    if [ "$http_status" = "200" ]; then
        log_test "Response data: $body"
        
        local db_connected=$(echo "$body" | jq -r '.database_connected // false')
        local core_up=$(echo "$body" | jq -r '.core_up // false')
        local core_synced=$(echo "$body" | jq -r '.core_synced // false')
        
        if [ "$db_connected" = "true" ] && [ "$core_up" = "true" ] && [ "$core_synced" = "true" ]; then
            log_test "✅ SUCCESS: Horizon health endpoint reports all systems healthy!"
            return 0
        else
            log_error "Some services not healthy - db:$db_connected, core_up:$core_up, core_synced:$core_synced"
            return 1
        fi
    else
        log_error "Non-200 status code: $http_status"
        return 1
    fi
}

# Main test execution
main() {
    log_test "Starting health endpoint tests..."
    
    # Test both endpoints
    if test_horizon_health && test_custom_readiness; then
        log_test "🎉 ALL TESTS PASSED!"
        exit 0
    else
        log_error "❌ Some tests failed"
        exit 1
    fi
}

main "$@"
