// Vercel serverless function: POST /api/contact
// Sends website enquiries to info@hallowaypryce.com via Resend (https://resend.com).
//
// Environment variables (set in Vercel → Project → Settings → Environment Variables):
//   RESEND_API_KEY   required  API key from Resend
//   CONTACT_TO       optional  defaults to info@hallowaypryce.com
//   CONTACT_FROM     optional  defaults to "Halloway Pryce Website <website@hallowaypryce.com>"
//                              (the domain must be verified in Resend)

const MATTERS = [
  'Strategy & Growth',
  'E-commerce & Brand',
  'M&A & Transactions',
  'Corporate & Commercial',
  'Private Client',
  'Dispute Resolution',
  'Real Estate',
  'Other',
];

function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function clean(v, max) {
  return typeof v === 'string' ? v.trim().slice(0, max) : '';
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  body = body || {};

  // Honeypot: bots fill the hidden "company" field. Pretend success.
  if (clean(body.company, 200)) return res.status(200).json({ ok: true });

  const name = clean(body.name, 120);
  const email = clean(body.email, 200);
  const phone = clean(body.phone, 40);
  const matter = clean(body.matter, 60);
  const message = clean(body.message, 5000);

  if (!name) return res.status(400).json({ error: 'Please enter your full name.' });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return res.status(400).json({ error: 'Please enter a valid email address.' });
  if (!MATTERS.includes(matter)) return res.status(400).json({ error: 'Please choose the nature of your enquiry.' });
  if (!message) return res.status(400).json({ error: 'Please tell us briefly how we can help.' });
  if (body.consent !== true) return res.status(400).json({ error: 'Please agree to the privacy notice to send your enquiry.' });

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.error('RESEND_API_KEY is not set');
    return res.status(500).json({ error: 'Your enquiry could not be sent. Please email info@hallowaypryce.com directly.' });
  }

  const to = process.env.CONTACT_TO || 'info@hallowaypryce.com';
  const from = process.env.CONTACT_FROM || 'Halloway Pryce Website <website@hallowaypryce.com>';

  const text = [
    `New enquiry via hallowaypryce.com`,
    ``,
    `Name: ${name}`,
    `Email: ${email}`,
    `Telephone: ${phone || '-'}`,
    `Nature of enquiry: ${matter}`,
    ``,
    message,
  ].join('\n');

  const html = `
    <div style="font-family:Georgia,serif;color:#14202E;max-width:620px">
      <p style="font-size:13px;letter-spacing:.2em;color:#4A5563">NEW ENQUIRY · HALLOWAYPRYCE.COM</p>
      <table style="font-family:Arial,sans-serif;font-size:14px;border-collapse:collapse">
        <tr><td style="padding:4px 16px 4px 0;color:#4A5563">Name</td><td>${esc(name)}</td></tr>
        <tr><td style="padding:4px 16px 4px 0;color:#4A5563">Email</td><td><a href="mailto:${esc(email)}">${esc(email)}</a></td></tr>
        <tr><td style="padding:4px 16px 4px 0;color:#4A5563">Telephone</td><td>${esc(phone || '-')}</td></tr>
        <tr><td style="padding:4px 16px 4px 0;color:#4A5563">Enquiry</td><td>${esc(matter)}</td></tr>
      </table>
      <p style="font-family:Arial,sans-serif;font-size:15px;line-height:1.6;white-space:pre-wrap;border-top:1px solid #C9C3B6;padding-top:16px">${esc(message)}</p>
    </div>`;

  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        reply_to: email,
        subject: `Website enquiry: ${matter} – ${name}`,
        text,
        html,
      }),
    });

    if (!r.ok) {
      console.error('Resend error', r.status, await r.text());
      return res.status(502).json({ error: 'Your enquiry could not be sent. Please email info@hallowaypryce.com directly.' });
    }
    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('Send failed', err);
    return res.status(502).json({ error: 'Your enquiry could not be sent. Please email info@hallowaypryce.com directly.' });
  }
};
