#!/usr/bin/env bash
# Creates or updates the website stack (S3 + CloudFront + Route53, then the domain).
#
#   infra/deploy-infra.sh                  create or update everything; the domain stays attached
#   infra/deploy-infra.sh --detach-domain  drop the certificate, aliases and DNS records again
#                                          (--attach-domain is accepted and is the default)
#
# Environment overrides: AWS_PROFILE, DOMAIN, HOSTED_ZONE_ID (use an existing zone), STACK_NAME.
set -euo pipefail
cd "$(dirname "$0")"

PROFILE="${AWS_PROFILE:-claude_prod_thebridgeto_ai}"
REGION=us-east-1
STACK="${STACK_NAME:-handwrittenjournal-website}"
DOMAIN="${DOMAIN:-handwrittenjournal.app}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
ATTACH=true
for arg in "$@"; do
  case "$arg" in
    --attach-domain) ATTACH=true ;;
    --detach-domain) ATTACH=false ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

overrides=("DomainName=$DOMAIN" "AttachDomain=$ATTACH")
if [[ -n "$HOSTED_ZONE_ID" ]]; then overrides+=("HostedZoneId=$HOSTED_ZONE_ID"); fi

echo "Deploying $STACK for $DOMAIN (attach domain: $ATTACH) with profile $PROFILE ..."
aws cloudformation deploy \
  --profile "$PROFILE" --region "$REGION" \
  --stack-name "$STACK" \
  --template-file website.yaml \
  --parameter-overrides "${overrides[@]}" \
  --tags Project=HandwrittenJournal Environment=prod ManagedBy=CloudFormation \
  --no-fail-on-empty-changeset

aws cloudformation describe-stacks \
  --profile "$PROFILE" --region "$REGION" --stack-name "$STACK" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
