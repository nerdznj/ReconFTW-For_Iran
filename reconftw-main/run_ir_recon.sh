#!/bin/bash
# run_ir_recon.sh v2.0 - Fixed & Enhanced Runner

TARGET="$1"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <domain.ir>"
  exit 1
fi

RECON_DIR="Recon/$TARGET"

# 1. Pre-checks (Fix Bug #2 - API Keys)
echo "[*] checking environment and API keys..."
if ! grep -q "SHODAN_API_KEY" reconftw.cfg; then
    echo " [!] WARNING: No SHODAN_API_KEY found. Passive scan will be limited."
fi

# 2. Smart Resume (Fix Bug #10)
if [[ -d "$RECON_DIR" && -f "$RECON_DIR/all_subdomains.txt" ]]; then
    read -p " [?] Previous scan found. Resume enrichment only? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        echo "[*] Resuming enrichment phase..."
        ./iran_passive_enrich.sh "$TARGET"
        exit 0
    fi
fi

# 3. Scope Setup
echo "$TARGET" > "$TARGET.scope"
echo "*.$TARGET" >> "$TARGET.scope"

# 4. Running reconFTW with Fixed Config
# -f reconftw_ir.cfg (Fix bug #1, #5, #6, #8)
echo "[*] Running main reconFTW engine..."
./reconftw.sh -d "$TARGET" -p -f reconftw_ir.cfg

# 5. Enrichment Phase
./iran_passive_enrich.sh "$TARGET"

echo "=== FINAL SUMMARY for $TARGET ==="
[ -f "$RECON_DIR/clean_subs.txt" ] && echo " - Verified Subdomains: $(wc -l < $RECON_DIR/clean_subs.txt)"
[ -f "$RECON_DIR/ip_ranges.txt" ] && echo " - ASN/IP Ranges: Found"
[ -f "$RECON_DIR/sensitive_files.txt" ] && echo " - Sensitive Files/Mobile Endpoints: $(wc -l < $RECON_DIR/sensitive_files.txt)"
