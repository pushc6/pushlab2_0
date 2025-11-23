#!/bin/bash
AAP_URL="https://aap.push-lab.com"
CLIENT_ID=$1
CLIENT_SECRET=$2

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "Usage: ./debug_aap.sh <CLIENT_ID> <CLIENT_SECRET>"
  exit 1
fi

echo "========================================================"
echo "TEST 1: Standard OAuth2 Endpoint (/api/o/token/)"
echo "========================================================"
curl -v -X POST "$AAP_URL/api/o/token/" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"

echo ""
echo ""
echo "========================================================"
echo "TEST 2: Gateway Token Endpoint (/api/gateway/v1/tokens/)"
echo "========================================================"
curl -v -X POST "$AAP_URL/api/gateway/v1/tokens/" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
