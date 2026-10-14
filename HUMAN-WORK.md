# What still needs human work

Ordered by what blocks a public launch first.

## 1. Build and device QA (engineering)

- [ ] **Compile the app target in Xcode 26** and fix SDK-level errors. The SwiftUI code was
      written and syntax-checked on Linux but never compiled (see AUDIT.md).
- [ ] Visual pass on every `#Preview` (light/dark/AX5/FR/NL/EN) and on devices: iPhone SE,
      standard size, Pro Max. Then iOS 18 (material) and iOS 26 (Liquid Glass).
- [ ] Real-device tests: Vision blurring on varied photos (night, crowds, plates at an
      angle). Add a manual "blur this area" tool if detection misses cases.
- [ ] Walk-home with the screen locked for 45 min: battery, location continuity,
      notifications, the alert e-mail actually arriving.
- [ ] Final app icon and brand pass (the current icon is a generated placeholder).

## 2. Legal and GDPR (lawyer)

- [ ] GDPR review before launch (spec §10.2). Reports about theft, aggression and
      harassment may be **data relating to offences (art. 10 GDPR)**. Get advice on the
      legal basis, art. 10 conditions, and whether a public body must be involved.
- [ ] **DPIA (AIPD)**: geolocation, potential sexual-violence data, walk-home tracking.
- [ ] Privacy policy and terms (CGU) in FR/NL/EN. Put their URLs in `LegalLinks`
      (`App/Features/Settings/SettingsView.swift`); the rows are hidden until then.
- [ ] Review the in-app privacy explainer (`privacy.*` strings) against the policy.
- [ ] Processor agreements (DPA): Supabase (EU region), e-mail provider (Resend or an EU
      alternative), Apple (MapKit, push).
- [ ] Walk-home: the contact receives e-mails about someone else's location. Check the
      information duty to that contact and the consent wording.
- [ ] Defamation and stigmatisation (spec §8): validate the text policy, neutral wording,
      and the decision to restrict share cards to road and cleanliness.
- [ ] Police transmission of serious reports (spec §6) is **not built**: it requires
      explicit consent and a legal framework.
- [ ] Retention periods (12 months for reports, 24 h for walks) are drafts: confirm them.
- [ ] Align the App Store privacy label with `PrivacyInfo.xcprivacy`.

## 3. Emergency numbers and help content (verify with each organisation)

All entries in `Packages/BruskKit/Sources/BruskCore/Safety/EmergencyDirectory.swift`.
Unverified entries are **hidden in Release builds** and badged "To verify" in Debug.

| Entry | Number in code | To do |
|---|---|---|
| 112 (all emergencies) | 112 | Final confirmation (statutory) |
| 101 (police) | 101 | Final confirmation (statutory) |
| CPVS Brussels (CHU Saint-Pierre), 24/7 | *none* | Get the official number and hours; confirm on-site complaint filing |
| Victim support | *none* | Decide which service(s): police victim assistance, SAV/CAW Brussel; numbers per language |
| SOS Viol | 0800 98 100 | Verify number, hours, languages |
| Écoute Violences Conjugales | 0800 30 030 | Verify |
| 1712 (Dutch-language violence line) | 1712 | Verify that it serves Brussels Dutch speakers |

Then set `verification: .verified` per entry.

- [ ] Complaint guide (`complaint.step.*`): verify "file at any police station", the
      Police-on-web scope, and the "injured party declaration" wording.

## 4. Native-speaker review of the texts

- [ ] **Dutch (Belgian Dutch)**: all 342 app strings (`Tools/l10n/strings/*.py`), the
      e-mails and walk page (`supabase/functions/_shared/i18n.ts`, `dispatch-outbox`), the
      OTP template. Check "Intimidatie" vs "straatintimidatie", "melding" gender
      agreement, "je" vs "u" register.
- [ ] **French (Belgium)**: register ("vous"; inclusive "·e" as in the spec), Belgian usage.
- [ ] English: light review.
- [ ] App Store listing, screenshots and keywords in the three languages.

## 5. Moderation (spec §8: solo founder, App Store UGC rules)

- [ ] Define who moderates, how often, and the SLA (personal-data flags first).
- [ ] Tooling exists only as SQL: the `moderation_queue` view, `mark_cell_resolved()` and
      `add_moderation_strike()`. Build a minimal admin screen or Retool/Supabase-studio
      procedure.
- [ ] Rules for serial-account detection (same device, bursts of new accounts in one
      cell), and restricting accounts.
- [ ] Notes are never shown publicly (only to services and moderators). Confirm this
      still satisfies App Review's UGC requirements (report, block).
- [ ] Calibrate the thresholds in `app_settings` during the single-commune pilot (spec
      §10.4).

## 6. Services and routing (spec §6)

- [ ] Agreements with Bruxelles-Propreté / Net Brussel, the pilot commune, and Brussels
      Mobility; addresses in `ROUTING_EMAILS`.
- [ ] Road ownership (regional vs communal roads) to route cleanliness and road reports
      correctly. Currently cleanliness goes to Bruxelles-Propreté and road to the commune.
- [ ] Study a relay to FixMyStreet with the Region.
- [ ] Decide what users see when a service never answers (the "unresolved" counter
      already does this publicly).
- [ ] A process to mark cells resolved when the service confirms the fix.

## 7. Infrastructure and accounts

- [ ] Product name: trademark, App Store, domain, X handle. Replace "Brusk" (`app.name`,
      `CFBundleDisplayName`, OTP template, e-mails) and `brusk.app` (`DeepLink`, entitlements).
- [ ] Host the `apple-app-site-association` file and simple web pages for shared links
      (`/z/<category>/<i>/<j>`), so cards open in the app or show a public page.
- [ ] E-mail domain with SPF/DKIM/DMARC for OTP, alerts and service e-mails.
- [ ] Apple Developer account, bundle id, signing, *Time Sensitive Notifications*, and the
      background-location justification for App Review (walk-home only, with the system
      indicator).
- [ ] Commune boundaries from UrbIS (README §6) with attribution.
- [ ] Monitoring and alerts on `walk-watchdog` failures (a failed alert is safety-critical).
- [ ] Security review / pentest before launch, including auth rate limits and CAPTCHA.

## 8. Product validation (spec §10)

- [ ] Interviews and 5–10 user tests of the four screens, including people who walk home
      alone at night and neighbourhood committees.
- [ ] Measure the "under 20 seconds" report goal in real conditions.
- [ ] Test with VoiceOver users and people with low vision.
