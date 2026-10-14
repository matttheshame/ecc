import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

/** Service-role client. Never exposed to the app; used by scheduled functions only. */
export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

/** Scheduled functions are called by pg_cron with the service-role key. */
export function isServiceCall(request: Request): boolean {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const header = request.headers.get("Authorization") ?? "";
  return Boolean(key) && header === `Bearer ${key}`;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export interface Email {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

/** Transactional e-mail through Resend (EU region recommended). Configure RESEND_API_KEY and EMAIL_FROM. */
export async function sendEmail(email: Email): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("EMAIL_FROM");
  if (!apiKey || !from) throw new Error("RESEND_API_KEY / EMAIL_FROM missing");
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [email.to], subject: email.subject, text: email.text, html: email.html }),
  });
  if (!response.ok) {
    throw new Error(`e-mail provider returned ${response.status}: ${await response.text()}`);
  }
}
