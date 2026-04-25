#!/bin/bash
# Strip pandoc's empty comments.xml and unused footnotes hyperlink rels
# from a generated .docx so Word doesn't show "unreadable content".
set -e
DOCX="$1"
[ -f "$DOCX" ] || { echo "missing: $DOCX" >&2; exit 1; }

WORK=$(mktemp -d)
cd "$WORK"
unzip -q "$DOCX"

# 1. Remove empty comments.xml + its references
if [ -f word/comments.xml ]; then
  rm -f word/comments.xml
  # Remove from [Content_Types].xml
  python3 -c "
import re
with open('[Content_Types].xml','r') as f: t=f.read()
t=re.sub(r'<Override PartName=\"/word/comments\.xml\"[^/]*/>','',t)
with open('[Content_Types].xml','w') as f: f.write(t)
"
  # Remove comments rel from document.xml.rels
  python3 -c "
import re
with open('word/_rels/document.xml.rels','r') as f: t=f.read()
t=re.sub(r'<Relationship[^>]*Target=\"comments\.xml\"[^/]*/>','',t)
with open('word/_rels/document.xml.rels','w') as f: f.write(t)
"
fi

# 2. Remove footnotes.xml.rels if its only relationship is an unused hyperlink
if [ -f word/_rels/footnotes.xml.rels ]; then
  # Check if footnotes.xml actually references the hyperlink
  if [ -f word/footnotes.xml ] && ! grep -q 'r:id=' word/footnotes.xml; then
    rm -f word/_rels/footnotes.xml.rels
  fi
fi

# Re-zip (must use specific structure for docx)
rm -f "$DOCX"
zip -q -r "$DOCX" . -x "*.DS_Store"
cd /
rm -rf "$WORK"
echo "cleaned: $DOCX"
