#!/bin/bash
# Installs a Halloway Pryce signature into Apple Mail, into the signature
# with an exact name. Never guesses which file to overwrite.
#
#   bash <(curl -sL https://www.hallowaypryce.com/assets/sig/install.sh) FILE "Name in Mail"
#   bash <(curl -sL https://www.hallowaypryce.com/assets/sig/install.sh)          # lists signatures
#
# FILE is one of: halloway, william, shinji, shinjidark, florea, stronger

PB=${PLISTBUDDY:-/usr/libexec/PlistBuddy}
KEY="$1"; NAME="$2"
BASE="https://www.hallowaypryce.com/assets/sig"

dirs=()
for d in "$HOME"/Library/Mobile\ Documents/com~apple~mail/Data/V*/MailData/Signatures "$HOME"/Library/Mail/V*/MailData/Signatures; do
  [ -f "$d/AllSignatures.plist" ] && dirs+=("$d")
done
if [ ${#dirs[@]} -eq 0 ]; then
  echo "Hittar inga signaturer. Ge Terminal Full diskåtkomst (Systeminställningar > Integritet och säkerhet) och starta om Terminal."
  exit 1
fi

list() {
  for d in "${dirs[@]}"; do
    i=0
    while n=$("$PB" -c "Print :$i:SignatureName" "$d/AllSignatures.plist" 2>/dev/null); do
      id=$("$PB" -c "Print :$i:SignatureUniqueId" "$d/AllSignatures.plist")
      echo "$n|$id|$d"
      i=$((i+1))
    done
  done
}

if [ -z "$KEY" ] || [ -z "$NAME" ]; then
  echo "Signaturer i Mail:"
  list | cut -d'|' -f1 | sort -u | sed 's/^/  - /'
  echo
  echo "Användning: bash <(curl -sL $BASE/install.sh) halloway|william|shinji|shinjidark|florea|stronger \"Namn i Mail\""
  exit 0
fi

case "$KEY" in halloway|william|shinji|shinjidark|florea|stronger) ;; *) echo "Okänd signatur: $KEY (halloway, william, shinji, shinjidark, florea, stronger)"; exit 1;; esac

if pgrep -x Mail >/dev/null; then
  echo "Avsluta Mail först (Cmd+Q) och kör kommandot igen."
  exit 1
fi

matches=$(list | awk -F'|' -v n="$NAME" 'tolower($1)==tolower(n)')
if [ -z "$matches" ]; then
  echo "Ingen signatur heter \"$NAME\" i Mail. Befintliga:"
  list | cut -d'|' -f1 | sort -u | sed 's/^/  - /'
  exit 1
fi
if [ "$(printf '%s\n' "$matches" | cut -d'|' -f2 | sort -u | wc -l | tr -d ' ')" != "1" ]; then
  echo "Flera signaturer heter \"$NAME\". Döp om dem så att namnet är unikt och försök igen."
  exit 1
fi

body=$(curl -fsL "$BASE/$KEY.txt") || { echo "Kunde inte hämta $KEY.txt"; exit 1; }
backup="$HOME/Desktop/Signatur-backup"; mkdir -p "$backup"
stamp=$(date +%Y%m%d-%H%M%S)
done_any=0

while IFS='|' read -r n id d; do
  f="$d/$id.mailsignature"
  if [ ! -f "$f" ]; then
    echo "Signaturfilen för \"$n\" finns inte än. Öppna Mail, skriv ett tecken i signaturen, stäng inställningarna, avsluta Mail och försök igen."
    exit 1
  fi
  cp "$f" "$backup/$n-$stamp.mailsignature"
  chflags nouchg "$f"
  { awk '1;/^\r?$/{exit}' "$f"; printf '%s\n' "$body"; } > "$f.tmp" && mv "$f.tmp" "$f"
  chflags uchg "$f"
  done_any=1
done <<< "$matches"

[ "$done_any" = 1 ] && echo "KLART: \"$NAME\" har nu signaturen $KEY. Backup: $backup"
