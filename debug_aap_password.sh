#!/bin/bash
AAP_URL="https://aap.push-lab.com"
CLIENT_ID=$1
CLIENT_SECRET=$2
USERNAME=$3
PASSWORD=$4

echo "========================================================"
echo "TEST: Password Grant (/o/token/)"
echo "========================================================"
curl -v -X POST "$AAP_URL/o/token/" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD"
