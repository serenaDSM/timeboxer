# TimeBoxer distribution architecture

## Products

| Product | Platform | Distribution | Responsibility |
| --- | --- | --- | --- |
| TimeBoxer Parent | iPhone | TestFlight, then New Zealand App Store | Parent account, policies, approvals, alerts and subscription |
| TimeBoxer Child | macOS 13+ | Developer ID signed and notarized DMG/PKG | Local enforcement, offline policy cache, heartbeat and event upload |
| TimeBoxer Cloud | Supabase + APNs | Managed backend | Family isolation, pairing, policy revisions, event ingestion and push |

## Trust boundaries

1. Parent clients authenticate with Supabase Auth and use only a publishable key.
2. Family membership is enforced by database RLS, not hidden UI or user metadata.
3. A child Mac creates a device identity in Keychain during pairing.
4. The Mac calls authenticated Edge Functions with its device credential. It never
   receives a parent access token or backend secret.
5. The Mac keeps the last acknowledged policy locally and continues enforcing it
   when the network or cloud is unavailable.
6. Server-side code validates every policy change and extra-time approval before
   increasing the policy revision.
7. APNs credentials and device tokens remain server-side.

## Pairing sequence

1. The signed-in parent asks the cloud for a 10-minute pairing session.
2. The cloud returns a six-digit code and stores only its digest.
3. The child Mac submits the code, installation ID and device public key.
4. The parent confirms the named Mac in the iPhone app.
5. The cloud consumes the single-use session and issues a scoped device credential.
6. The Mac stores the credential in Keychain, downloads policy revision 1 and
   reports the acknowledgement.

## Release gates

- Dedicated TimeBoxer Supabase project and non-production branch.
- RLS tests plus Supabase security and performance advisors with no unresolved
  high-severity findings.
- Developer ID Application/Installer certificates, Hardened Runtime, notarization
  and Gatekeeper tests for the Mac package.
- Apple Push Notifications entitlement and production APNs key for the parent app.
- TestFlight family pilot before App Store submission.
- Privacy policy, account deletion, data export and retention controls.
- StoreKit subscription only after pairing, synchronization and notifications are
  reliable for the free pilot cohort.
