#!/usr/bin/env bash
# Removes the hosted zone Route53 created when handwrittenjournal.app was registered
# (Z05889073RVN2B44M1XGS). The stack's own zone (Z0557600392EBQZX08OFZ) is the one the
# registry points at; this duplicate only carries mirror copies of the same records so the
# nameserver change could propagate safely. Run it a day or two after 2026-09-02.
set -euo pipefail
PROFILE="${AWS_PROFILE:-claude_prod_thebridgeto_ai}"
ZONE="${1:-Z05889073RVN2B44M1XGS}"
export AWS_PROFILE="$PROFILE" AWS_REGION=us-east-1

name=$(aws route53 get-hosted-zone --id "$ZONE" --query 'HostedZone.Name' --output text)
comment=$(aws route53 get-hosted-zone --id "$ZONE" --query 'HostedZone.Config.Comment' --output text)
echo "Zone $ZONE: $name ($comment)"
[[ "$comment" == *"Route53 Registrar"* ]] || { echo "This does not look like the registrar-created zone; stopping." >&2; exit 1; }

# Delete every record except the zone's own NS and SOA, which go with the zone itself.
batch=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE" --output json | python3 -c '
import json, sys
zone = json.load(sys.stdin)["ResourceRecordSets"]
apex = next(r["Name"] for r in zone if r["Type"] == "SOA")
changes = [{"Action": "DELETE", "ResourceRecordSet": r} for r in zone
           if not (r["Name"] == apex and r["Type"] in ("NS", "SOA"))]
print(json.dumps({"Comment": "Remove mirror records before deleting the duplicate zone", "Changes": changes}) if changes else "")
')
if [[ -n "$batch" ]]; then
  echo "$batch" | python3 -c 'import json,sys; [print("  delete", c["ResourceRecordSet"]["Type"], c["ResourceRecordSet"]["Name"]) for c in json.load(sys.stdin)["Changes"]]'
  aws route53 change-resource-record-sets --hosted-zone-id "$ZONE" --change-batch "$batch" --query 'ChangeInfo.Status' --output text
fi
aws route53 delete-hosted-zone --id "$ZONE" --query 'ChangeInfo.Status' --output text
echo "Deleted hosted zone $ZONE"
