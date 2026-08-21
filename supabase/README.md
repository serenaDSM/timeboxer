# TimeBoxer cloud foundation

This directory is a local, unlinked Supabase project. It is intentionally not
connected to the existing `s-nz-ledger` project in the developer account.

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

## Before linking a cloud project

1. Create a dedicated TimeBoxer Supabase project in `ap-southeast-2`.
2. Link this directory with the pinned Supabase CLI.
3. Apply the migration to a non-production branch first.
4. Run database tests and both security and performance advisors.
5. Deploy authenticated pairing, device sync and APNs Edge Functions.

No migration has been applied to an online database yet.
