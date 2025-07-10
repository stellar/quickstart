#!/bin/bash

# Simple HTTP server for health checks
# Listens on port 8004 and responds to health check requests

PORT=8004

echo "Health service starting on port $PORT"

# Function to check if a service is healthy
check_stellar_core() {
    if [ "$ENABLE_CORE" != "true" ]; then
        return 0  # Not enabled, so considered healthy
    fi
    
    # Check if stellar-core is responding
    if curl -s --max-time 5 "http://localhost:11626/info" > /dev/null 2>&1; then
        return 0  # Healthy
    else
        return 1  # Unhealthy
    fi
}

check_horizon() {
    if [ "$ENABLE_HORIZON" != "true" ]; then
        return 0  # Not enabled, so considered healthy
    fi
    
    # Check if horizon is responding and ingesting
    local response=$(curl -s --max-time 5 "http://localhost:8001" 2>/dev/null)
    if [ -z "$response" ]; then
        return 1  # Unhealthy
    fi
    
    # Check if basic fields are present and reasonable
    local protocol_version=$(echo "$response" | jq -r '.supported_protocol_version // 0' 2>/dev/null)
    local core_ledger=$(echo "$response" | jq -r '.core_latest_ledger // 0' 2>/dev/null)
    local history_ledger=$(echo "$response" | jq -r '.history_latest_ledger // 0' 2>/dev/null)
    
    if [ "$protocol_version" -gt 0 ] && [ "$core_ledger" -gt 0 ] && [ "$history_ledger" -gt 0 ]; then
        return 0  # Healthy
    else
        return 1  # Unhealthy
    fi
}

check_stellar_rpc() {
    if [ "$ENABLE_RPC" != "true" ]; then
        return 0  # Not enabled, so considered healthy
    fi
    
    # Check stellar-rpc health using getHealth method
    local response=$(curl -s --max-time 5 -X POST "http://localhost:8003" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc": "2.0", "id": 10235, "method": "getHealth"}' 2>/dev/null)
    
    if [ -z "$response" ]; then
        return 1  # Unhealthy
    fi
    
    local status=$(echo "$response" | jq -r '.result.status // ""' 2>/dev/null)
    if [ "$status" = "healthy" ]; then
        return 0  # Healthy
    else
        return 1  # Unhealthy
    fi
}

# Function to generate JSON health response
generate_health_response() {
    local overall_status="healthy"
    local services_json="{"
    local first_service=true
    
    # Check each enabled service
    if [ "$ENABLE_CORE" = "true" ]; then
        if [ "$first_service" = true ]; then
            first_service=false
        else
            services_json="$services_json,"
        fi
        
        if check_stellar_core; then
            services_json="$services_json\"stellar-core\":\"healthy\""
        else
            services_json="$services_json\"stellar-core\":\"unhealthy\""
            overall_status="unhealthy"
        fi
    fi
    
    if [ "$ENABLE_HORIZON" = "true" ]; then
        if [ "$first_service" = true ]; then
            first_service=false
        else
            services_json="$services_json,"
        fi
        
        if check_horizon; then
            services_json="$services_json\"horizon\":\"healthy\""
        else
            services_json="$services_json\"horizon\":\"unhealthy\""
            overall_status="unhealthy"
        fi
    fi
    
    if [ "$ENABLE_RPC" = "true" ]; then
        if [ "$first_service" = true ]; then
            first_service=false
        else
            services_json="$services_json,"
        fi
        
        if check_stellar_rpc; then
            services_json="$services_json\"stellar-rpc\":\"healthy\""
        else
            services_json="$services_json\"stellar-rpc\":\"unhealthy\""
            overall_status="unhealthy"
        fi
    fi
    
    services_json="$services_json}"
    
    echo "{\"status\":\"$overall_status\",\"services\":$services_json}"
}

# Simple HTTP server using netcat
while true; do
    {
        # Read the HTTP request (we ignore most of it)
        read request_line
        while read header && [ "$header" != $'\r' ]; do
            true  # Ignore headers
        done
        
        # Generate health response
        health_response=$(generate_health_response)
        overall_status=$(echo "$health_response" | jq -r '.status')
        
        # Set HTTP status code
        if [ "$overall_status" = "healthy" ]; then
            http_status="200 OK"
        else
            http_status="503 Service Unavailable"
        fi
        
        # Send HTTP response
        echo -e "HTTP/1.1 $http_status\r"
        echo -e "Content-Type: application/json\r"
        echo -e "Content-Length: ${#health_response}\r"
        echo -e "\r"
        echo -n "$health_response"
        
    } | nc -l -p $PORT -q 1
    
    # Log the health check
    echo "$(date): Health check - $overall_status"
done