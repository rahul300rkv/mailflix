#!/usr/bin/env bash

set -e

echo "============================================================"
echo "           MAILFLIX SEO + CLEAN URL FIX"
echo "============================================================"
echo

# ------------------------------------------------------------
# 0. Verify repository
# ------------------------------------------------------------

if [ ! -d ".git" ]; then
    echo "ERROR: .git folder not found."
    echo "Run this script from the Mailflix repository root."
    exit 1
fi

if [ ! -f "index.html" ]; then
    echo "ERROR: index.html not found."
    echo "This does not look like the Mailflix repository root."
    exit 1
fi

echo "Repository detected."
echo

# ------------------------------------------------------------
# 1. Backup
# ------------------------------------------------------------

echo "[1/8] Creating backup..."

BACKUP="mailflix_backup_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP/html"

[ -f "_redirects" ] && cp "_redirects" "$BACKUP/_redirects"
[ -f "robots.txt" ] && cp "robots.txt" "$BACKUP/robots.txt"
[ -f "sitemap.xml" ] && cp "sitemap.xml" "$BACKUP/sitemap.xml"

find . -maxdepth 1 -type f -name "*.html" \
    -exec cp {} "$BACKUP/html/" \;

echo "Backup created: $BACKUP"
echo

# ------------------------------------------------------------
# 2. Netlify redirects
# ------------------------------------------------------------

echo "[2/8] Updating Netlify redirects..."

cat > _redirects <<'EOF'
# ============================================================
# Mailflix canonical URL redirects
# .html URL -> clean URL = 301
# clean URL -> physical .html file = 200 rewrite
# ============================================================

/index.html /

/city-compare.html /city-compare 301
/ctc-calculator.html /ctc-calculator 301
/date-calculator.html /date-calculator 301
/epf-withdrawal-guide.html /epf-withdrawal-guide 301
/gratuity-rules-india.html /gratuity-rules-india 301
/gst-invoice.html /gst-invoice 301
/health-calculator.html /health-calculator 301
/how-ctc-is-calculated.html /how-ctc-is-calculated 301
/hra-calculator.html /hra-calculator 301
/income-tax-slabs.html /income-tax-slabs 301
/increment-calculator.html /increment-calculator 301
/itr-calculator.html /itr-calculator 301
/job-application.html /job-application 301
/json-tools.html /json-tools 301
/leave-encashment.html /leave-encashment 301
/new-vs-old-tax-regime.html /new-vs-old-tax-regime 301
/paraphrase.html /paraphrase 301
/photo-resizer.html /photo-resizer 301
/privacy.html /privacy 301
/professional-tax-india.html /professional-tax-india 301
/qr-generator.html /qr-generator 301
/rent-receipt.html /rent-receipt 301
/resignation.html /resignation 301
/retirement-calculator.html /retirement-calculator 301
/salary-glossary.html /salary-glossary 301
/sarkari-letter.html /sarkari-letter 301
/vehicle-scrappage.html /vehicle-scrappage 301
/what-is-form-16.html /what-is-form-16 301
/what-is-tds.html /what-is-tds 301
/whatsapp-dhanda.html /whatsapp-dhanda 301

# ============================================================
# Clean URL rewrites
# ============================================================

/city-compare /city-compare.html 200
/ctc-calculator /ctc-calculator.html 200
/date-calculator /date-calculator.html 200
/epf-withdrawal-guide /epf-withdrawal-guide.html 200
/gratuity-rules-india /gratuity-rules-india.html 200
/gst-invoice /gst-invoice.html 200
/health-calculator /health-calculator.html 200
/how-ctc-is-calculated /how-ctc-is-calculated.html 200
/hra-calculator /hra-calculator.html 200
/income-tax-slabs /income-tax-slabs.html 200
/increment-calculator /increment-calculator.html 200
/itr-calculator /itr-calculator.html 200
/job-application /job-application.html 200
/json-tools /json-tools.html 200
/leave-encashment /leave-encashment.html 200
/new-vs-old-tax-regime /new-vs-old-tax-regime.html 200
/paraphrase /paraphrase.html 200
/photo-resizer /photo-resizer.html 200
/privacy /privacy.html 200
/professional-tax-india /professional-tax-india.html 200
/qr-generator /qr-generator.html 200
/rent-receipt /rent-receipt.html 200
/resignation /resignation.html 200
/retirement-calculator /retirement-calculator.html 200
/salary-glossary /salary-glossary.html 200
/sarkari-letter /sarkari-letter.html 200
/vehicle-scrappage /vehicle-scrappage.html 200
/what-is-form-16 /what-is-form-16.html 200
/what-is-tds /what-is-tds.html 200
/whatsapp-dhanda /whatsapp-dhanda.html 200
EOF

echo "_redirects updated."
echo

# ------------------------------------------------------------
# 3. Internal links
# ------------------------------------------------------------

echo "[3/8] Converting internal links to clean URLs..."

declare -A URLS=(
    ["index.html"]="/"
    ["city-compare.html"]="/city-compare"
    ["ctc-calculator.html"]="/ctc-calculator"
    ["date-calculator.html"]="/date-calculator"
    ["epf-withdrawal-guide.html"]="/epf-withdrawal-guide"
    ["gratuity-rules-india.html"]="/gratuity-rules-india"
    ["gst-invoice.html"]="/gst-invoice"
    ["health-calculator.html"]="/health-calculator"
    ["how-ctc-is-calculated.html"]="/how-ctc-is-calculated"
    ["hra-calculator.html"]="/hra-calculator"
    ["income-tax-slabs.html"]="/income-tax-slabs"
    ["increment-calculator.html"]="/increment-calculator"
    ["itr-calculator.html"]="/itr-calculator"
    ["job-application.html"]="/job-application"
    ["json-tools.html"]="/json-tools"
    ["leave-encashment.html"]="/leave-encashment"
    ["new-vs-old-tax-regime.html"]="/new-vs-old-tax-regime"
    ["paraphrase.html"]="/paraphrase"
    ["photo-resizer.html"]="/photo-resizer"
    ["privacy.html"]="/privacy"
    ["professional-tax-india.html"]="/professional-tax-india"
    ["qr-generator.html"]="/qr-generator"
    ["rent-receipt.html"]="/rent-receipt"
    ["resignation.html"]="/resignation"
    ["retirement-calculator.html"]="/retirement-calculator"
    ["salary-glossary.html"]="/salary-glossary"
    ["sarkari-letter.html"]="/sarkari-letter"
    ["vehicle-scrappage.html"]="/vehicle-scrappage"
    ["what-is-form-16.html"]="/what-is-form-16"
    ["what-is-tds.html"]="/what-is-tds"
    ["whatsapp-dhanda.html"]="/whatsapp-dhanda"
)

for file in *.html; do

    [ -f "$file" ] || continue

    for old in "${!URLS[@]}"; do

        new="${URLS[$old]}"

        sed -i \
            -e "s|href=\"$old\"|href=\"$new\"|g" \
            -e "s|href=\"./$old\"|href=\"$new\"|g" \
            -e "s|href=\"/$old\"|href=\"$new\"|g" \
            "$file"

    done

done

echo "Internal links processed."
echo

# ------------------------------------------------------------
# 4. Canonical + OG URLs
# ------------------------------------------------------------

echo "[4/8] Fixing canonical and Open Graph URLs..."

for file in *.html; do

    [ -f "$file" ] || continue

    sed -i \
        -e 's|https://mailflix\.netlify\.app/index\.html|https://mailflix.netlify.app|g' \
        -e 's|https://mailflix\.netlify\.app/city-compare\.html|https://mailflix.netlify.app/city-compare|g' \
        -e 's|https://mailflix\.netlify\.app/ctc-calculator\.html|https://mailflix.netlify.app/ctc-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/date-calculator\.html|https://mailflix.netlify.app/date-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/epf-withdrawal-guide\.html|https://mailflix.netlify.app/epf-withdrawal-guide|g' \
        -e 's|https://mailflix\.netlify\.app/gratuity-rules-india\.html|https://mailflix.netlify.app/gratuity-rules-india|g' \
        -e 's|https://mailflix\.netlify\.app/gst-invoice\.html|https://mailflix.netlify.app/gst-invoice|g' \
        -e 's|https://mailflix\.netlify\.app/health-calculator\.html|https://mailflix.netlify.app/health-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/how-ctc-is-calculated\.html|https://mailflix.netlify.app/how-ctc-is-calculated|g' \
        -e 's|https://mailflix\.netlify\.app/hra-calculator\.html|https://mailflix.netlify.app/hra-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/income-tax-slabs\.html|https://mailflix.netlify.app/income-tax-slabs|g' \
        -e 's|https://mailflix\.netlify\.app/increment-calculator\.html|https://mailflix.netlify.app/increment-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/itr-calculator\.html|https://mailflix.netlify.app/itr-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/job-application\.html|https://mailflix.netlify.app/job-application|g' \
        -e 's|https://mailflix\.netlify\.app/json-tools\.html|https://mailflix.netlify.app/json-tools|g' \
        -e 's|https://mailflix\.netlify\.app/leave-encashment\.html|https://mailflix.netlify.app/leave-encashment|g' \
        -e 's|https://mailflix\.netlify\.app/new-vs-old-tax-regime\.html|https://mailflix.netlify.app/new-vs-old-tax-regime|g' \
        -e 's|https://mailflix\.netlify\.app/paraphrase\.html|https://mailflix.netlify.app/paraphrase|g' \
        -e 's|https://mailflix\.netlify\.app/photo-resizer\.html|https://mailflix.netlify.app/photo-resizer|g' \
        -e 's|https://mailflix\.netlify\.app/privacy\.html|https://mailflix.netlify.app/privacy|g' \
        -e 's|https://mailflix\.netlify\.app/professional-tax-india\.html|https://mailflix.netlify.app/professional-tax-india|g' \
        -e 's|https://mailflix\.netlify\.app/qr-generator\.html|https://mailflix.netlify.app/qr-generator|g' \
        -e 's|https://mailflix\.netlify\.app/rent-receipt\.html|https://mailflix.netlify.app/rent-receipt|g' \
        -e 's|https://mailflix\.netlify\.app/resignation\.html|https://mailflix.netlify.app/resignation|g' \
        -e 's|https://mailflix\.netlify\.app/retirement-calculator\.html|https://mailflix.netlify.app/retirement-calculator|g' \
        -e 's|https://mailflix\.netlify\.app/salary-glossary\.html|https://mailflix.netlify.app/salary-glossary|g' \
        -e 's|https://mailflix\.netlify\.app/sarkari-letter\.html|https://mailflix.netlify.app/sarkari-letter|g' \
        -e 's|https://mailflix\.netlify\.app/vehicle-scrappage\.html|https://mailflix.netlify.app/vehicle-scrappage|g' \
        -e 's|https://mailflix\.netlify\.app/what-is-form-16\.html|https://mailflix.netlify.app/what-is-form-16|g' \
        -e 's|https://mailflix\.netlify\.app/what-is-tds\.html|https://mailflix.netlify.app/what-is-tds|g' \
        -e 's|https://mailflix\.netlify\.app/whatsapp-dhanda\.html|https://mailflix.netlify.app/whatsapp-dhanda|g' \
        "$file"

done

echo "Canonical / OG URLs processed."
echo

# ------------------------------------------------------------
# 5. JSON-LD URLs
# ------------------------------------------------------------

echo "[5/8] JSON-LD URLs use the same clean absolute URLs."
echo "Absolute URL cleanup already applied above."
echo

# ------------------------------------------------------------
# 6. Sitemap
# ------------------------------------------------------------

echo "[6/8] Checking sitemap.xml..."

if [ -f "sitemap.xml" ]; then

    if grep -qi ".html" sitemap.xml; then

        echo "Found .html URLs in sitemap."

        sed -i \
            -e 's|/index\.html|/|g' \
            -e 's|\.html</loc>|</loc>|g' \
            sitemap.xml

        echo "Sitemap cleaned."

    else

        echo "No .html URLs found in sitemap."

    fi

else

    echo "WARNING: sitemap.xml not found."

fi

echo

# ------------------------------------------------------------
# 7. robots.txt
# ------------------------------------------------------------

echo "[7/8] Checking robots.txt..."

if [ -f "robots.txt" ]; then

    if grep -qiE '^[[:space:]]*LLMs[[:space:]]*:' robots.txt; then

        echo "Found invalid LLMs: directive."
        echo "Removing it..."

        sed -i '/^[[:space:]]*LLMs[[:space:]]*:/Id' robots.txt

        echo "Removed."

    else

        echo "No LLMs: directive found."

    fi

    echo
    echo "Sitemap directive:"
    grep -i "^Sitemap:" robots.txt || echo "WARNING: Sitemap directive not found."

else

    echo "WARNING: robots.txt not found."

fi

echo

# ------------------------------------------------------------
# 8. Final audit
# ------------------------------------------------------------

echo "[8/8] Running final audit..."
echo

echo "============================================================"
echo "Remaining .html references in HTML"
echo "============================================================"

grep -Rni --include="*.html" ".html" . \
    --exclude-dir=".git" \
    --exclude-dir="$BACKUP" \
    || echo "No .html references found."

echo
echo "============================================================"
echo "Sitemap URLs"
echo "============================================================"

if [ -f "sitemap.xml" ]; then
    grep -i "<loc>" sitemap.xml || true
else
    echo "sitemap.xml missing."
fi

echo
echo "============================================================"
echo "Git changes"
echo "============================================================"

git status --short

echo
echo "============================================================"
echo "                    FIX COMPLETE"
echo "============================================================"
echo
echo "Backup:"
echo "$BACKUP"
echo
echo "IMPORTANT: Review changes before committing."
echo
echo "Run:"
echo "    git diff"
echo
echo "If everything looks correct:"
echo
echo "    git add ."
echo '    git commit -m "Fix clean URLs and SEO canonicalization"'
echo "    git push"
echo
echo "Expected architecture:"
echo
echo "    /ctc-calculator       -> 200"
echo "    /ctc-calculator.html  -> 301 -> /ctc-calculator"
echo

exit 0
