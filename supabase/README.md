# TimeBoxer cloud foundation

This directory belongs only to the dedicated hosted Supabase project `timeboxer`
(`jysdafvxexnyfplehqga`) in `ap-southeast-2`. It has its own Postgres database,
API endpoint, Auth users and scaling limits. It is not connected to and must never
be linked to the existing `s-nz-ledger` project.

## Security model

- Parent users authenticate through Supabase Auth and receive a publishable key.
- Every table in the exposed `public` schema has Row Level Security enabled.
- Family access is derived from `family_members`, never user-editable JWT metadata.
- Child Macs do not sign in as parents and never receive a Supabase secret key.
- Pairing codes, device credentials and APNs tokens live in the unexposed `private`
  schema and are accessible only by server-side functions using `service_role`.
- Raw pairing codes and raw device secrets are never stored.
- Activity events contain only a category, app/domain label and small event payload;
  screenshots, page contents, keystrokes and file contents are outside the contract.

The first migration grants explicit table privileges because new Supabase projects
no longer expose newly-created public tables to the Data API automatically.

## Hosted project status

- Dedicated project created on 2026-08-22 on the Free plan.
- Initial schema and follow-up RLS migrations applied successfully.
- A real authenticated-role transaction created a profile, family, owner
  membership and child through RLS, then removed all verification data.
- All 12 TimeBoxer tables have RLS enabled. Security Advisor reports no warning or
  error findings; the only information notices are intentional policy-free private
  tables that default-deny client access.
- Performance Advisor reports only expected unused-index notices on the empty
  database. The indexes support future family, event and device queries.

Next: deploy authenticated pairing, device synchronization and APNs Edge Functions.
