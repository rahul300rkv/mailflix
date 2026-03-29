#!/bin/bash
FILES=(index.html job-application.html whatsapp-dhanda.html resignation.html sarkari-letter.html)

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "✗ $f not found, skipping"
    continue
  fi

  # Fix wrong proxy URL to correct Netlify function URL
  sed -i "s|/api/groq|/.netlify/functions/groq|g" "$f"

  echo "✓ fixed: $f"
done

echo ""
echo "Done! Now git add . && git commit -m 'fix: correct Netlify function URL' && git push"
