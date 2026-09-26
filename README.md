# 📶 Captive Portal Lab (`captive-fas`)

> Exploring modern Captive Portals, Forwarding Authentication Servers (FAS), and guest Wi-Fi integrations for hospitality and venue networks.

Welcome to my side hustle playground! This repository houses experiments, reference implementations, and production-ready scripts for building sleek, privacy-conscious, and frictionless captive portals. 

The goal of this project is to take standard, clunky guest Wi-Fi logins and turn them into smooth, modern digital touchpoints for cafes, restaurants, hotels, and venues—capturing leads, handling terms of service, and integrating with cloud tools while keeping hardware overhead on the gateway minimal.

---

## 🚀 What's Implemented

### 1. `email_capture` Flow
A complete, lightweight end-to-end guest Wi-Fi onboarding experience built on top of [openNDS](https://opennds.readthedocs.io/) and standard OpenWrt/BusyBox utilities.

```
                  ┌───────────────────────────────┐
                  │        Guest Connects         │
                  └──────────────┬────────────────┘
                                 │
                     (HTTP / RFC 8908 redirect)
                                 ▼
                  ┌───────────────────────────────┐
                  │   openNDS Gateway Redirect    │
                  │   (FAS Level 2 / Base64 URL)  │
                  └──────────────┬────────────────┘
                                 │
                                 ▼
                  ┌───────────────────────────────┐
                  │      `index.html` (FAS UI)    │
                  │   - Decodes client MAC / IP   │
                  │   - Collects email + ToS consent│
                  └──────────────┬────────────────┘
                                 │
                       (POST /cgi-bin/login.sh)
                                 ▼
                  ┌───────────────────────────────┐
                  │     `login.sh` (BusyBox CGI)  │
                  ├───────────────────────────────┤
                  │ 1. ndsctl auth <MAC> <time>   │──► Internet Unlocked
                  │ 2. Async Webhook to Google    │──► Lead stored in Sheets / CRM
                  │ 3. Return "Access Granted" UI │──► Guest redirected to venue site
                  └───────────────────────────────┘
```

#### Core Components:

* **[index.html](email_capture/index.html)** — **Modern Responsive Portal UI**
  * Minimalist, mobile-first design with clean typography and system fonts.
  * **openNDS FAS Level 2 Decoder:** Automatically unpacks and URL-decodes the base64-encoded `?fas=...` parameter injected by openNDS (or falls back to plain query parameters), extracting `clientmac`, `clientip`, `gatewayurl`, `hid`, and `gatewayname`.
  * Built-in collapsible **Query Parameter Debugger** to inspect live gateway parameters during field deployments.
  * Terms of Service acceptance and email input validation.

* **[login.sh](email_capture/login.sh)** — **BusyBox / uhttpd CGI Authentication Handler**
  * Zero external dependencies: parses HTTP POST bodies using POSIX shell commands compatible with embedded BusyBox environments (`head -c`, `tr`, `sed`).
  * **Instant Authentication:** Executes `ndsctl auth "$CLIENT_MAC" "$SESSION_DURATION"` (or IP fallback) to unlock internet access directly on the router for the configured duration (default: 24h / 1440 min).
  * **Asynchronous Webhook Lead Capture:** Fires an asynchronous, background `curl` request containing the guest email, MAC, and IP to a Google Apps Script endpoint (or webhook/CRM) without stalling the user's browser response.
  * Serves an elegant "Access Granted" success card directing guests onward to the venue's landing page (e.g., `prokop.dev`).

* **[captive-api.sh](email_capture/captive-api.sh)** — **RFC 8908 Captive-Portal API Endpoint**
  * Implements modern standard [RFC 8908](https://datatracker.ietf.org/doc/html/rfc8908) (`application/captive+json`) for native operating system integration (iOS, Android, macOS, Windows 11).
  * Queries `ndsctl json` to check client authorization state and calculates remaining session duration.
  * Eliminates false-positive captive alerts and enables seamless automatic closure of system captive browser sheets once authenticated.

---

## 🛠 Tech Stack & Architecture

* **Gateway Daemon:** [openNDS](https://github.com/openNDS/openNDS) (Captive Portal engine for OpenWrt & Linux)
* **Web Server:** `uhttpd` / lightweight CGI on OpenWrt
* **Scripting:** Pure POSIX `/bin/sh` & BusyBox utilities
* **Standards:** RFC 8908 (Captive Portal Identification API via DHCP Option 114 / IPv6 RA)
* **Integrations:** Google Apps Script Webhooks (Google Sheets lead collection)

---

## 💡 Side Hustle Roadmap & Ideas

- [ ] **SMS / WhatsApp Verification:** OTP verification for higher-trust guest capture.
- [ ] **Social & OAuth Logins:** One-click Google and Apple sign-in flows.
- [ ] **Paid Access & Vouchers:** Stripe integration for high-speed tiers or extended time limits in coworking spaces and hotels.
- [ ] **Cloud-Hosted Multi-Tenant FAS:** Centralized dashboard for managing captive portals across multiple remote client venues.
- [ ] **Venue Analytics & Marketing Sync:** Automated synchronization into Mailchimp, Klaviyo, or HubSpot with repeat visitor analytics.
