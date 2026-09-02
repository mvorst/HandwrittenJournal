# Website hosting

How the Handwritten Journal site is hosted: static files in a private S3 bucket behind
CloudFront, in AWS account 148768123182 (us-east-1), managed with the
`claude_prod_thebridgeto_ai` profile. Set up 2026-09-02. The site itself (pages, styles,
build script) lives in [`../Go_To_Market/website/`](../Go_To_Market/website/README.md).

| | |
|---|---|
| Live | https://handwrittenjournal.app (also https://d1zog19glnvtua.cloudfront.net; `www` redirects to the apex) |
| Domain | `handwrittenjournal.app`, registered through Route53 Domains on 2026-09-02 (auto-renew on, transfer lock on, expires 2027-09-02). Attached to the distribution the same day. |
| Certificate | ACM `arn:aws:acm:us-east-1:148768123182:certificate/090e331c-52b9-4587-a23b-c138a0217a86` for the apex and `www`, DNS-validated in the hosted zone, renews itself. |
| Design | Claude Design canvas: https://claude.ai/code/artifact/8d8fa93b-8d13-4cae-9ee1-b5c056ea248d. Working files in `design/`. |
| Stack | CloudFormation `handwrittenjournal-website`, template `infra/website.yaml` |
| Site bucket | `us-east-1.www.handwrittenjournal.app` (private, versioned, old versions expire after 30 days; CloudFront reads it through origin access control) |
| Logs bucket | `us-east-1.logs.handwrittenjournal.app` (CloudFront access logs under `cloudfront/`, kept 90 days) |
| Distribution | `EGRUI7HCTVRYF` = `d1zog19glnvtua.cloudfront.net`; price class 100 (North America and Europe), HTTP/2 and 3, IPv6 |
| Hosted zone | `Z0557600392EBQZX08OFZ` for `handwrittenjournal.app` |
| Nameservers | `ns-357.awsdns-44.com` `ns-776.awsdns-33.net` `ns-1335.awsdns-38.org` `ns-1915.awsdns-47.co.uk` |

## What is in this folder

| Path | What it is |
|---|---|
| `deploy.sh` | Uploads `Go_To_Market/website/dist/` to the bucket and invalidates the CloudFront cache. `--build` runs `build.py --clean` first; `--dry-run` shows what would change. |
| `infra/website.yaml` | The whole environment as one CloudFormation template. |
| `infra/deploy-infra.sh` | Creates or updates the stack. The domain stays attached by default; `--detach-domain` removes the certificate, aliases and DNS records. |
| `infra/delete-duplicate-zone.sh` | Removes the hosted zone Route53 created at registration once the nameserver change has had a day or two to propagate (below). |
| `design/` | The design canvas working files: `Main.dc.html` (home, desktop), `Mobile.dc.html` (home, phone), `Support.dc.html`, `Privacy.dc.html`, `canvas.json`, and the downsampled screenshots they use. |

## Publishing the site

```bash
Website/deploy.sh --build
```

(or plain `Website/deploy.sh` when `dist/` is already current). Rules the CDN applies:

- Pages are directories, as `build.py` writes them: `/privacy/` serves `privacy/index.html`.
  A page address without its slash, such as `/privacy`, gets a 301 to `/privacy/`, so the
  App Store's privacy and support URLs can be typed either way. Paths with an extension
  and anything under `/.well-known/` are passed through untouched.
- A missing page serves `/404.html` with a 404 status; `build.py` produces that file.
- Caching: the hashed `assets/site.<hash>.css` and `.js` are cached for a year and marked
  immutable (a rebuild changes the hash); images, PDFs, `robots.txt` and `sitemap.xml` for
  a day; HTML for five minutes. Every deploy invalidates the whole distribution, so a
  change shows up within a minute or two regardless.
- `www.handwrittenjournal.app` redirects (301) to the apex, path and query kept.
- Responses carry HSTS (with preload, which `.app` requires anyway), `nosniff`,
  `X-Frame-Options: DENY`, a referrer policy and a permissions policy. There is no
  Content-Security-Policy yet. The site loads only its own CSS and JS, so a strict one is
  feasible; test the hero animation (inline SVG) before adding it to `SecurityHeadersPolicy`.
- Text is compressed (brotli or gzip) at the edge.

The App Store fields want `https://handwrittenjournal.app/support/` and
`https://handwrittenjournal.app/privacy/`; both are live.

## The domain (done 2026-09-02)

The domain was registered through Route53 Domains, which created its own hosted zone
(`Z05889073RVN2B44M1XGS`). The stack's zone (`Z0557600392EBQZX08OFZ`) was kept as the real
one: the domain's nameservers were repointed at it with `update-domain-nameservers`, the
certificate validated, and `deploy-infra.sh --attach-domain` put both names on the
distribution and added the A and AAAA alias records.

The registrar's duplicate zone still exists and carries mirror copies of the same records
(the two certificate-validation CNAMEs and the four alias records), so resolvers that
cached the original delegation keep working while it expires. It costs $0.50 a month and
would silently ignore any DNS edits made in it, so remove it after a day or two:

```bash
Website/infra/delete-duplicate-zone.sh
```

Any future DNS record (mail, verification TXT, subdomains) goes in the stack's zone
`Z0557600392EBQZX08OFZ`.

## Changing the domain

`DOMAIN=example.com Website/infra/deploy-infra.sh` redeploys against another name (a new
hosted zone, certificate and buckets), and `site.config.json` needs the same change before
a rebuild. Bucket names derive from the
domain, so CloudFormation creates new buckets and leaves the old ones behind (they are set
to be retained); empty and delete those by hand.

## Costs

Hosted zone $0.50 a month, the domain $20 a year, S3 and CloudFront a few cents a month at
launch traffic, logs negligible.

## Tearing down

The two buckets and the hosted zone are retained on stack deletion so nothing is lost by
accident. Empty the buckets, run `aws cloudformation delete-stack --stack-name
handwrittenjournal-website`, then delete the buckets and the zone yourself.

## Verified on 2026-09-02

The built site deployed with `deploy.sh`: `/`, `/press/`, `/privacy/`, `/schools/`,
`/specialists/`, `/support/` and `/terms/` return 200 as `text/html; charset=utf-8`;
`/nope` redirects to `/nope/`, which serves the custom 404 page with a 404 status; the
hashed CSS and JS carry the one-year immutable header and the right content types;
`.webp`, `.png`, `.pdf`, `robots.txt` and `sitemap.xml` are served with their proper types
and the one-day header; `http://` redirects to `https://`; the security headers are
present; brotli is on; the bucket refuses direct access (403).

After the domain was attached: `https://handwrittenjournal.app/` serves the site with the
Amazon-issued certificate (TLS 1.3); `/support/`, `/privacy/` and the 404 page behave the
same on the domain; `/privacy` redirects to `/privacy/`; `https://www.handwrittenjournal.app/support/?x=1`
redirects to the apex with the query kept; `http://` on either name redirects to `https://`;
HSTS is served on the domain.
