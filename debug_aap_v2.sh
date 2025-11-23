#!/bin/bash
AAP_URL="https://aap.push-lab.com"
CLIENT_ID=$1
CLIENT_SECRET=$2

echo "========================================================"
echo "TEST 1: Gateway Endpoint - Credentials in BODY"
echo "Target: $AAP_URL/api/gateway/v1/tokens/"
echo "========================================================"
curl -v -X POST "$AAP_URL/api/gateway/v1/tokens/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET"

echo ""
echo "========================================================"
echo "TEST 2: Controller OAuth2 Endpoint (/api/controller/o/token/)"
echo "========================================================"
curl -v -X POST "$AAP_URL/api/controller/o/token/" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=client_credentials"

echo ""
echo "========================================================"
echo "TEST 3: Legacy v2 OAuth2 Endpoint (/api/v2/o/token/)"
echo "========================================================"
curl -v -X POST "$AAP_URL/api/v2/o/token/" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=client_credentials"

echo ""
echo "========================================================"
echo "TEST 4: Root OAuth2 Endpoint (/o/token/)"
echo "========================================================"
curl -v -X POST "$AAP_URL/o/token/" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=client_credentials"
