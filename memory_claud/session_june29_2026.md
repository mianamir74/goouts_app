# Session Memory — 29 June 2026

## Session Focus
GoOuts website (www.goouts.co.uk) debugging, fixes, and deployment. Word cycle animation, Firebase config, SSL/security issues.

---

## Website Files
| File | Path |
|---|---|
| Source HTML | `C:\Users\Maz\goouts\index.html` |
| Public HTML | `C:\Users\Maz\goouts\goouts_website\public\index.html` |
| Firebase config | `C:\Users\Maz\goouts\goouts_website\firebase.json` |
| Deploy script | `C:\Users\Maz\goouts\goouts_website\deploy_website.bat` |
| Firebase project | `goouts-f16db` | site: `goouts-website` |
| Live URL | https://www.goouts.co.uk |
| Naked domain | https://goouts.co.uk → redirects via Firebase Console |

---

## Issues Fixed This Session

### 1. Word cycle stuck on "rewards."
**Root cause:** The HTML file (`index.html`) was truncated mid-line at `// ── Smooth scroll for nav links ──`. The `</script>`, `</body>`, and `</html>` closing tags were all missing. Browsers do not reliably execute unclosed `<script>` blocks.

**Fix:** Used Python3 to detect and remove the broken last line, then appended:
```js
// ── Smooth scroll for nav links ──
document.querySelectorAll('a[href^="#"]').forEach(a=>{
  a.addEventListener('click',e=>{
    const target = document.querySelector(a.getAttribute('href'));
    if(target){ e.preventDefault(); target.scrollIntoView({behavior:'smooth'}); }
  });
});

// ── Mobile overlay close ──
document.getElementById('mobOverlay').addEventListener('click', closeDrawer);
document.querySelectorAll('.mob-link').forEach(l=>l.addEventListener('click', closeDrawer));
```
Then closed with `</script></body></html>`.

**File now:** 1999 lines, 3 script blocks all properly closed.

**Confirmed working:** Chrome MCP showed cycleWord cycling food. → rewards. → etc.

### 2. Website not loading after deploy
**Root cause:** `firebase.json` had redirect rules:
```json
{"source": "/", "destination": "https://www.goouts.co.uk", "type": 301},
{"source": "/:path*", "destination": "https://www.goouts.co.uk/:path*", "type": 301}
```
Both `www.goouts.co.uk` and `goouts.co.uk` point to the same Firebase site `goouts-website`. These redirect rules caused an **infinite redirect loop** — www.goouts.co.uk redirected to itself.

**Fix:** Removed the `redirects` block entirely from `firebase.json`. Firebase Console already handles naked domain → www redirect natively.

### 3. Chrome showing "Not Secure"
**Root cause:** Chrome caches domain security state. goouts.co.uk previously had no SSL so Chrome flagged it. Firefox/IE don't have the same strict HSTS cache.

**Fix:** 
- Firebase Console: added goouts.co.uk as custom domain with A record `199.36.158.100` + TXT `hosting-site=goouts-website`
- GoDaddy DNS: `@` A record = `199.36.158.100`, `@` TXT = `hosting-site=goouts-website`
- Firebase provisioned SSL for naked domain — now resolves as secure
- Chrome: use `chrome://net-internals/#hsts` to clear cached domain state if needed

### 4. Mixed content check
Performed full audit on live site — **zero http:// resources found**. All assets load over HTTPS. Site is clean.

---

## Current firebase.json (CORRECT VERSION)
```json
{
  "hosting": {
    "site": "goouts-website",
    "public": "public",
    "ignore": ["firebase.json", "**/.*"],
    "headers": [
      {"source": "/index.html", "headers": [{"key": "Cache-Control", "value": "no-cache, no-store, must-revalidate"}]},
      {"source": "**", "headers": [{"key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains; preload"}]}
    ],
    "rewrites": [
      {"source": "/robots.txt", "destination": "/robots.txt"},
      {"source": "/sitemap.xml", "destination": "/sitemap.xml"},
      {"source": "**", "destination": "/index.html"}
    ]
  }
}
```
NO redirects block — removing it fixed the infinite loop.

---

## Word Cycle Code (WORKING)
In the third `<script>` block of index.html:
```js
const words = [
  {t:'rewards.',c:'#0392CA'},
  {t:'food.',c:'#10B981'},
  {t:'earnings.',c:'#6C63FF'},
  {t:'experiences.',c:'var(--amber)'},
];
let wi = 0;
const wEl = document.getElementById('cycleWord');
setInterval(()=>{
  wi = (wi+1) % words.length;
  wEl.style.transition = 'opacity 0.3s, transform 0.3s';
  wEl.style.opacity = '0';
  wEl.style.transform = 'translateY(12px)';
  setTimeout(()=>{
    wEl.textContent = words[wi].t;
    wEl.style.color = words[wi].c;
    wEl.style.opacity = '1';
    wEl.style.transform = 'translateY(0)';
  }, 320);
}, 2800);
```
Span uses: `style="display:inline-block;min-width:8em;white-space:nowrap;"` to prevent layout shift.

---

## Important Python3 Pattern for File Edits
The HTML file contains emoji (🇬🇧, 𝕏) which break standard UTF-8 reads.
Always use:
```python
with open(path, 'rb') as f:
    content = f.read()
text = content.decode('utf-8', errors='replace')
```
Then write back with `open(path, 'w', encoding='utf-8')`.

---

## DNS Setup (GoDaddy for goouts.co.uk)
| Type | Name | Value |
|---|---|---|
| A | @ | 199.36.158.100 |
| TXT | @ | hosting-site=goouts-website |
| CNAME | www | goouts-website.web.app |

---

## NEW IDEA — Remind Next Session
**Add website section: "Redeem Points Abroad with GoOuts Virtual Card"**
- New section on www.goouts.co.uk explaining how users can redeem cashback points internationally using the GoOuts Virtual Card (Apple Wallet / Google Pay via Stripe Issuing)
- Explain the flow: earn points in UK → load onto virtual card → spend anywhere Mastercard/Visa accepted worldwide
- Link to V8 Hybrid Ledger architecture (GO-SPONSOR-V8-HYBRID-2026) for implementation context

---

## Pending Tasks (carry forward)
- Task #59: Firebase Hosting config + deploy.bat — LARGELY COMPLETE, mark done next session
- Task #69: Merchant Portal — Add delivery settings (hours, radius, min order, fee)
- Task #73: Consumer App — Cart and checkout flow with delivery address
- Task #75: Consumer App — Order history and reorder screen
- Task #76: Build GoOuts DAPP — Flutter Android driver app
- Task #77: Admin Panel — Food delivery orders management screen
- Task #78: Admin Panel — Driver management screen
- Task #79: Admin Panel — Menu moderation screen
- Task #80: Backend — Food delivery Cloud Functions
- Task #82: Research — What Deliveroo/Uber Eats do NOT offer (GoOuts competitive advantage)
- Task #84: Social Boost Food Delivery — Instagram post = free delivery
- Task #87: B2B Channel Partnerships — Deliverect, Lightspeed, Epos Now

---

## Website Status
- www.goouts.co.uk — LIVE, SECURE, word cycle WORKING
- goouts.co.uk — LIVE, SECURE, SSL provisioned by Firebase
- PageSpeed: ~70 mobile performance, 100 SEO (from previous session)
- robots.txt + sitemap.xml in place
- HSTS header active
- No mixed content
- Burger image: WebP (83KB) + JPEG fallback (117KB) via `<picture>` element
