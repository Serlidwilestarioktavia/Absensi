# Supabase setup

This app can keep using local browser storage until Supabase is configured. Once configured, teachers and managers sign in with Supabase Auth and share students, attendance, and face descriptors in the same school workspace.

## Project setup

1. Create a Supabase project and open its SQL Editor.
2. Run `supabase/schema.sql`.
3. Create the first manager user in Authentication > Users. Use the manager's name and Gmail address.
4. Promote that account in the SQL Editor, replacing the email:

```sql
update public.profiles
set role = 'manager'
where email = 'manager@school.ac.id';
```

5. Deploy the app files to an HTTPS static host such as Netlify, Vercel, or GitHub Pages. Camera access on phones requires a secure HTTPS origin.
6. In Authentication > URL Configuration, set the deployed HTTPS address as the Site URL.
7. Put the Project URL and the publishable/anon key in `supabase-config.js`. Never put the `service_role` key in this file.
8. Install and log in to the Supabase CLI, link this project, and deploy the Edge Function:

```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy create-teacher
```

The function uses Supabase's server-side `SUPABASE_SERVICE_ROLE_KEY`; do not expose that key to the browser. Cloud login and shared data remain disabled until the schema, function, project URL, and publishable key are configured.

## Security and data

- Row Level Security limits data access to authenticated accounts. All accounts in this project share the same student and attendance records.
- Managers can create teacher accounts through the app; teachers cannot create accounts.
- Face descriptors are biometric data. This setup stores them in the shared database as requested. Use explicit consent, restrict project membership, and use HTTPS for the deployed site.
- Existing records in `localStorage` are not uploaded automatically. Import them only after the cloud connection is configured and the data has been reviewed.
