#!/bin/bash
# Run this from the root of your mailflix repo
# It applies the 3 security patches to all 5 HTML files

KEY_PATTERN="const GROQ_KEY = 'gsk_[^']*';"
PROXY_COMMENT="\/\/ Groq key removed — calls proxied via \/api\/groq Netlify function"
GROQ_URL="https:\/\/api.groq.com\/openai\/v1\/chat\/completions"
PROXY_URL="\/api\/groq"

FILES=(index.html job-application.html whatsapp-dhanda.html resignation.html sarkari-letter.html)

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "✗ $f not found, skipping"
    continue
  fi

  # 1. Remove hardcoded key line
  sed -i "s/${KEY_PATTERN}/${PROXY_COMMENT}/" "$f"

  # 2. Replace Groq API URL with proxy
  sed -i "s|${GROQ_URL}|${PROXY_URL}|g" "$f"

  # 3. Remove Authorization header (single-quote style)
  sed -i "/'Authorization': 'Bearer ' + GROQ_KEY,/d" "$f"
  sed -i "/'Authorization': 'Bearer ' + GROQ_KEY/d" "$f"

  echo "✓ patched: $f"
done

echo ""
echo "All done! Now:"
echo "  1. Add GROQ_API_KEY env var in Netlify dashboard"
echo "  2. Make sure netlify/functions/groq.js exists (already provided)"
echo "  3. git add . && git commit -m 'chore: remove hardcoded Groq key, proxy via Netlify function' && git push"
