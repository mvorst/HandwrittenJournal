#!/usr/bin/env bash
# Uploads the built site to the site bucket and invalidates the CloudFront cache.
#   Website/deploy.sh            upload Go_To_Market/website/dist
#   Website/deploy.sh --build    run Go_To_Market/website/build.py --clean first
#   Website/deploy.sh --dry-run  show what would change
# Environment overrides: AWS_PROFILE, STACK_NAME, SITE_DIR.
set -euo pipefail
cd "$(dirname "$0")"
REPO="$(cd .. && pwd)"

PROFILE="${AWS_PROFILE:-claude_prod_thebridgeto_ai}"
REGION=us-east-1
STACK="${STACK_NAME:-handwrittenjournal-website}"
SITE_DIR="${SITE_DIR:-$REPO/Go_To_Market/website/dist}"
DRYRUN=0
BUILD=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRYRUN=1 ;;
    --build) BUILD=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [[ $BUILD -eq 1 ]]; then
  python3 "$REPO/Go_To_Market/website/build.py" --clean
fi
[[ -f "$SITE_DIR/index.html" ]] || { echo "no index.html in $SITE_DIR (build first?)" >&2; exit 1; }

output() {
  aws cloudformation describe-stacks --profile "$PROFILE" --region "$REGION" --stack-name "$STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
BUCKET="$(output SiteBucketName)"
DIST_ID="$(output DistributionId)"
[[ -n "$BUCKET" && -n "$DIST_ID" ]] || { echo "stack $STACK has no outputs yet" >&2; exit 1; }

common=(--profile "$PROFILE" --region "$REGION" --exclude ".DS_Store" --exclude "*/.DS_Store")
if [[ $DRYRUN -eq 1 ]]; then common+=(--dryrun); fi
hashed=(--exclude "*" --include "assets/site.*.css" --include "assets/site.*.js")
not_hashed=(--exclude "assets/site.*.css" --exclude "assets/site.*.js")
year="public, max-age=31536000, immutable"
day="public, max-age=86400"
minutes="public, max-age=300"

# 1. New hashed CSS/JS first, without deleting, so new pages never reference a missing file.
aws s3 sync "$SITE_DIR" "s3://$BUCKET" "${common[@]}" "${hashed[@]}" --cache-control "$year"
# 2. Images, PDFs, robots, sitemap: a day in caches; the invalidation refreshes the edge.
aws s3 sync "$SITE_DIR" "s3://$BUCKET" "${common[@]}" "${not_hashed[@]}" --exclude "*.html" \
  --delete --cache-control "$day"
# 3. HTML: short browser cache so a redeploy shows up within minutes everywhere.
aws s3 sync "$SITE_DIR" "s3://$BUCKET" "${common[@]}" --exclude "*" --include "*.html" \
  --delete --content-type "text/html; charset=utf-8" --cache-control "$minutes"
# 4. Now the new HTML is live, drop hashed files nothing references any more.
aws s3 sync "$SITE_DIR" "s3://$BUCKET" "${common[@]}" "${hashed[@]}" --delete --cache-control "$year"

if [[ $DRYRUN -eq 0 ]]; then
  aws cloudfront create-invalidation --profile "$PROFILE" --distribution-id "$DIST_ID" \
    --paths "/*" --query 'Invalidation.{Id:Id,Status:Status}' --output table
  echo "Deployed $SITE_DIR to s3://$BUCKET and invalidated distribution $DIST_ID"
fi
