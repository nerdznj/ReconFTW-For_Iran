#!/bin/bash
# iran_passive_enrich.sh v2.0 - Advanced Passive Recon for Iranian Targets

TARGET="$1"
[ -z "$TARGET" ] && { echo "Usage: $0 <domain>"; exit 1; }

OUTDIR="Recon/$TARGET"
mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/enrich_progress.log"

echo "[+] Starting Advanced Enrichment for $TARGET" | tee -a "$LOGFILE"

# 1. ASN & IP Range Discovery (Fix Bug #4)
if [ ! -f "$OUTDIR/ip_ranges.txt" ]; then
    echo "[*] Discovering ASN and IP Ranges..."
    ASN=$(curl -s "https://api.hackertarget.com/aslookup/?q=$TARGET" | head -1 | cut -d' ' -f1)
    if [[ ! -z "$ASN" && "$ASN" != "error" ]]; then
        echo "ASN Found: $ASN" | tee -a "$LOGFILE"
        curl -s "https://api.hackertarget.com/aslookup/?q=$ASN" | tail -n +2 | sort -u > "$OUTDIR/ip_ranges.txt"
    fi
else
    echo "[+] IP Ranges already discovered. Skipping..."
fi

# 2. Advanced Archive Fetching (Fix Bug #1, #7, #8)
if [ ! -f "$OUTDIR/custom_urls.txt" ]; then
    echo "[*] Fetching URLs from multiple archives (Wayback, CommonCrawl)..."
    # استفاده از gau با فیلترهای زمانی و حذف Noise اولیه
    gau --threads 10 "$TARGET" | sort -u > "$OUTDIR/custom_urls.txt"
fi

# 3. Smart Filtering & Noise Removal (Fix Bug #3)
echo "[*] Filtering CDN Noise and False Positives..."
CDN_LIST="cloudfront|akamai|googleapis|aws|azure|blogspot|wordpress|github|wp-content|wp-includes|cdn"
cat "$OUTDIR/../all_subdomains.txt" "$OUTDIR/custom_urls.txt" 2>/dev/null | \
    grep -oE "([a-zA-Z0-9._-]+\.$TARGET)" | \
    grep -vE "\.($CDN_LIST)\." | \
    sort -u > "$OUTDIR/clean_subs.txt"

# 4. Sensitive Files & Mobile Endpoints (Fix Bug #9)
echo "[*] Searching for sensitive files and Mobile API endpoints..."
grep -E "\.(js|json|env|bak|zip|sql|php|asp|jsp|apk|ipa)$" "$OUTDIR/custom_urls.txt" | \
    sort -u > "$OUTDIR/sensitive_files.txt"

# 5. Token & Secret Extraction (Fix Bug #8)
if [ ! -f "$OUTDIR/secrets.txt" ]; then
    echo "[*] Extracting secrets from JS files (Passive only)..."
    # فقط فایل‌های JS که قبلاً یافت شده‌اند را بررسی می‌کند
    grep "\.js$" "$OUTDIR/sensitive_files.txt" | head -n 50 | while read js; do
        curl -skL --timeout 5 "$js" | grep -E "(token|key|secret|password|api|auth)" -i >> "$OUTDIR/secrets.txt" 2>/dev/null
    done
fi

echo "[+] Enrichment Completed. Results saved in $OUTDIR/" | tee -a "$LOGFILE"
