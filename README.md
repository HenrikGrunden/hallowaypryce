# hallowaypryce.com

Statisk landningssida + en serverless-funktion (`/api/contact`) som skickar formuläret till info@hallowaypryce.com via Resend.

## Struktur
- `index.html` – sidan
- `api/contact.js` – tar emot formuläret och mejlar det
- `assets/emblem.svg`, `assets/favicon.svg` – ikonen med duvan
- `vercel.json` – rena URL:er och säkerhetsheaders

## Driftsätt på Vercel
1. Lägg mappen i ett GitHub-repo och importera det i Vercel (Framework preset: "Other", inget build-kommando).
2. Skapa ett konto på resend.com, lägg till domänen `hallowaypryce.com` och lägg in DNS-posterna (SPF/DKIM) som Resend visar.
3. I Vercel → Settings → Environment Variables:
   - `RESEND_API_KEY` = nyckeln från Resend
   - (valfritt) `CONTACT_TO` = info@hallowaypryce.com
   - (valfritt) `CONTACT_FROM` = `Halloway Pryce Website <website@hallowaypryce.com>`
4. Vercel → Settings → Domains: lägg till `hallowaypryce.com` och `www.hallowaypryce.com` och peka DNS enligt instruktionen.
5. Deploya och skicka ett testformulär.

## Att fylla i innan lansering
- Sidorna `/privacy`, `/cookies` och `/complaints` (skapa `privacy.html` osv. i roten)
