#!/bin/bash
# Installs Halloway Pryce signatures into Apple Mail, into the signature
# with an exact name. Never guesses which file to overwrite.
#
#   bash <(curl -sL https://www.hallowaypryce.com/assets/sig/install.sh)                  # lists signatures
#   bash <(curl -sL https://www.hallowaypryce.com/assets/sig/install.sh) all              # installs every known signature found by name
#   bash <(curl -sL https://www.hallowaypryce.com/assets/sig/install.sh) FILE "Name in Mail"
#
# FILE is one of: halloway, william, shinji, shinjidark, shinjiauto, shinjimono, florea, stronger, strongerorb
# "all" uses these names in Mail: Halloway Pryce, William Davis, Shinji, Shinji Dark, Shinji Auto, Shinji Monogram, Florea, Stronger, Stronger Orb

PB=${PLISTBUDDY:-/usr/libexec/PlistBuddy}
KEY="$1"; NAME="$2"
BASE="https://www.hallowaypryce.com/assets/sig"
KEYS="halloway william shinji shinjidark shinjiauto shinjimono florea stronger strongerorb"

default_name() {
  case "$1" in
    halloway) echo "Halloway Pryce";; william) echo "William Davis";; shinji) echo "Shinji";;
    shinjidark) echo "Shinji Dark";; shinjiauto) echo "Shinji Auto";; shinjimono) echo "Shinji Monogram";; florea) echo "Florea";; stronger) echo "Stronger";; strongerorb) echo "Stronger Orb";;
  esac
}

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

if [ -z "$KEY" ]; then
  echo "Signaturer i Mail:"
  list | while IFS='|' read -r n id d; do
    if [ -s "$d/$id.mailsignature" ]; then s="har innehåll"; else s="TOM / saknar fil"; fi
    echo "  - $n ($s)"
  done | sort -u
  echo
  echo "Installera alla:  bash <(curl -sL $BASE/install.sh) all"
  echo "Installera en:    bash <(curl -sL $BASE/install.sh) halloway|william|shinji|shinjidark|shinjiauto|shinjimono|florea|stronger|strongerorb \"Namn i Mail\""
  exit 0
fi

if pgrep -x Mail >/dev/null; then
  echo "Avsluta Mail först (Cmd+Q) och kör kommandot igen."
  exit 1
fi

backup="$HOME/Desktop/Signatur-backup"; mkdir -p "$backup"
stamp=$(date +%Y%m%d-%H%M%S)

# Write the signature as multipart/related with every image embedded, the same
# way Mail stores a pasted image. Mail then never has to fetch anything from the
# web, so images show in Settings and in new messages even when remote content
# is blocked. An image that cannot be downloaded keeps its web address.
imgdir=$(mktemp -d "${TMPDIR:-/tmp}/hp-sig.XXXXXX")
trap 'rm -rf "$imgdir"' EXIT
newid() { uuidgen 2>/dev/null || printf '%s-%s' "$(date +%s)" "$RANDOM$RANDOM"; }

write_sig() {
  local f="$1" body="$2" msgid="" boundary url file name mime cid try from to parts=""
  [ -f "$f" ] && msgid=$(grep -m1 -i '^Message-Id:' "$f" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r')
  [ -z "$msgid" ] && msgid="<$(newid)>"
  boundary="Apple-Mail=_$(newid)"
  for url in $(printf '%s' "$body" | grep -oE 'https://www\.hallowaypryce\.com/assets/sig/[A-Za-z0-9._-]+\.(png|gif|jpg)(\?[A-Za-z0-9=&._-]*)?' | sort -u); do
    name=${url##*/}; name=${name%%\?*}
    file="$imgdir/$name"
    for try in 1 2 3; do [ -s "$file" ] && break; curl -fsL "$url" -o "$file" || { rm -f "$file"; sleep 1; }; done
    [ -s "$file" ] || { echo "  (kunde inte hämta $name, behåller webbadressen)"; continue; }
    case "$name" in *.gif) mime=image/gif;; *.jpg) mime=image/jpeg;; *) mime=image/png;; esac
    cid=$(newid)
    from="src=\"$url\""; to="apple-inline=\"yes\" src=\"cid:$cid\""
    body=${body//"$from"/$to}
    body=${body//"$url"/cid:$cid}
    parts+=$(printf '\n--%s\nContent-Transfer-Encoding: base64\nContent-Disposition: inline;\n\tfilename=%s\nContent-Type: %s;\n\tx-unix-mode=0644;\n\tname="%s"\nContent-Id: <%s>\n\n%s\n' \
      "$boundary" "$name" "$mime" "$name" "$cid" "$(base64 < "$file" | tr -d '\n' | fold -w 76)")
  done
  {
    printf 'Content-Type: multipart/related;\n\ttype="text/html";\n\tboundary="%s"\n' "$boundary"
    printf 'Message-Id: %s\n' "$msgid"
    printf 'Mime-Version: 1.0 (Mac OS X Mail 16.0)\n'
    printf '\n'
    printf -- '--%s\nContent-Transfer-Encoding: 7bit\nContent-Type: text/html;\n\tcharset=us-ascii\n\n%s\n' "$boundary" "$body"
    printf '%s\n' "$parts"
    printf -- '--%s--\n' "$boundary"
  } > "$f.tmp"
}

# install_one KEY NAME [quiet-if-missing]
install_one() {
  local key="$1" name="$2" quiet="$3"
  local matches
  matches=$(list | awk -F'|' -v n="$name" 'tolower($1)==tolower(n)')
  if [ -z "$matches" ]; then
    [ -n "$quiet" ] && { echo "  - hoppar över $key: ingen signatur heter \"$name\""; return 0; }
    echo "Ingen signatur heter \"$name\" i Mail. Befintliga:"
    list | cut -d'|' -f1 | sort -u | sed 's/^/  - /'
    return 1
  fi
  if [ "$(printf '%s\n' "$matches" | cut -d'|' -f2 | sort -u | wc -l | tr -d ' ')" != "1" ]; then
    echo "Flera signaturer heter \"$name\". Döp om dem så att namnet är unikt och försök igen."
    return 1
  fi
  local body
  local try
  for try in 1 2 3; do body=$(curl -fsL "$BASE/$key.txt") && break; body=""; sleep 1; done
  [ -n "$body" ] || { echo "Kunde inte hämta $key.txt"; return 1; }
  while IFS='|' read -r n id d; do
    local f="$d/$id.mailsignature"
    if [ -f "$f" ]; then
      cp "$f" "$backup/$n-$stamp.mailsignature"
      chflags nouchg "$f"
    fi
    write_sig "$f" "$body"
    mv "$f.tmp" "$f" && chflags uchg "$f"
  done <<< "$matches"
  echo "  KLART: \"$name\" har nu signaturen $key"
}

if [ "$KEY" = "all" ]; then
  echo "Installerar alla signaturer som finns i Mail:"
  for k in $KEYS; do install_one "$k" "$(default_name "$k")" quiet; done
  echo "Backup: $backup"
  exit 0
fi

case " $KEYS " in *" $KEY "*) ;; *) echo "Okänd signatur: $KEY ($KEYS, all)"; exit 1;; esac
[ -z "$NAME" ] && NAME=$(default_name "$KEY")
install_one "$KEY" "$NAME" && echo "Backup: $backup"
