// Sends FCM HTTP v1 messages to every token in public.user_fcm_tokens.
//
// Deploy:
//   supabase functions deploy send-push
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
//
// Payload (all optional except that silent defaults to true):
// {
//   "type": "sync_content" | "new_content" | "content_updated" | "force_update",
//   "silent": true,
//   "entity": "artist" | "album" | "song" | "all",
//   "entityId": "...",
//   "title": "...",
//   "body": "...",
//   "reference": "..."
// }
//
// Silent (artist rename, lyric edit): data-only + APNs content-available.
// Visible (new song): notification+data so the OS can show a tray item when
// the app is backgrounded or killed, PLUS a twin silent data message so the
// Dart isolate can refresh SQLite without the user opening the app.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "mahlete-semay-project";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const CONTENT_CHANNEL = "content_updates_v3";
const APP_UPDATE_CHANNEL = "app_updates_v1";

type PushRequest = {
  type?: string;
  silent?: boolean;
  entity?: string;
  entityId?: string;
  title?: string;
  body?: string;
  reference?: string;
  latestVersion?: string;
  minRequiredVersion?: string;
  forceUpdate?: boolean;
  apkUrl?: string;
};

type ServiceAccount = {
  project_id?: string;
  client_email: string;
  private_key: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    await assertCallerAllowed(authHeader);

    const body = (await req.json().catch(() => ({}))) as PushRequest;
    const silent =
      body.silent !== false &&
      body.type !== "new_content" &&
      body.type !== "force_update";
    const type = body.type ?? (silent ? "sync_content" : "new_content");
    const entity = body.entity ?? "all";
    const entityId = body.entityId ?? "";
    const title = body.title ?? "";
    const bodyText = body.body ?? "";
    const reference = body.reference ?? entityId;
    const isForceUpdate = type === "force_update";

    if (await isDuplicate(type, silent, entity, entityId)) {
      return json({ ok: true, deduped: true, sent: 0 });
    }

    const tokens = await loadTokens();
    if (tokens.length === 0) {
      return json({ ok: true, sent: 0, reason: "no_tokens" });
    }

    const accessToken = await getGoogleAccessToken();
    const projectId =
      readServiceAccount().project_id ?? FIREBASE_PROJECT_ID;

    const data: Record<string, string> = {
      type,
      silent: silent.toString(),
      entity,
      k: "new_content",
    };
    if (entityId) data.entity_id = entityId;
    if (title) data.title = title;
    if (bodyText) data.body = bodyText;
    if (reference) data.r = reference;
    if (body.latestVersion) data.latest_version = String(body.latestVersion);
    if (body.minRequiredVersion) {
      data.min_required_version = String(body.minRequiredVersion);
    }
    if (body.forceUpdate != null) data.force_update = String(body.forceUpdate);
    if (body.apkUrl) data.apk_url = String(body.apkUrl);
    if (isForceUpdate) data.k = "force_update";

    const staleTokens: string[] = [];
    let sent = 0;

    await mapPool(tokens, 8, async (token) => {
      if (silent) {
        const result = await sendFcm(accessToken, projectId, token, {
          data,
          android: { priority: "HIGH" },
          apns: silentApns,
        });
        if (result.stale) staleTokens.push(token);
        if (result.ok) sent += 1;
        return;
      }

      // Visible tray item for background / killed processes.
      const visible = await sendFcm(accessToken, projectId, token, {
        notification: {
          title: title || (isForceUpdate ? "New Version Available" : "Mahlete Semay"),
          body: bodyText || (isForceUpdate
            ? "A new version of Mahlete Semay is ready. Open the app to update."
            : ""),
        },
        data: { ...data, silent: "false" },
        android: {
          priority: "HIGH",
          notification: {
            channel_id: isForceUpdate ? APP_UPDATE_CHANNEL : CONTENT_CHANNEL,
            icon: "ic_notification",
            color: "#1E88E5",
          },
        },
        apns: {
          headers: { "apns-priority": "10", "apns-push-type": "alert" },
          payload: { aps: { sound: "default", "content-available": 1 } },
        },
      });
      if (visible.stale) staleTokens.push(token);
      if (visible.ok) sent += 1;

      // Twin silent wake so Android still runs the Dart background handler
      // (notification+data messages do not invoke onBackgroundMessage).
      const twin = await sendFcm(accessToken, projectId, token, {
        data: {
          ...data,
          silent: "true",
          type: isForceUpdate ? "force_update" : "sync_content",
        },
        android: { priority: "HIGH" },
        apns: silentApns,
      });
      if (twin.stale) staleTokens.push(token);
    });

    if (staleTokens.length > 0) {
      await deleteStaleTokens(staleTokens);
    }

    return json({ ok: true, sent, staleRemoved: staleTokens.length });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = message === "forbidden" ? 403 : 500;
    return json({ ok: false, error: message }, status);
  }
});

const silentApns = {
  headers: {
    "apns-push-type": "background",
    "apns-priority": "5",
  },
  payload: {
    aps: { "content-available": 1 },
  },
};

async function assertCallerAllowed(authHeader: string): Promise<void> {
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) throw new Error("forbidden");

  const role = decodeJwtRole(jwt);
  if (role === "service_role") return;

  const supabase = serviceClient();
  const { data: userData, error } = await supabase.auth.getUser(jwt);
  if (error || !userData.user) throw new Error("forbidden");

  const { data: moderator } = await supabase
    .from("moderators")
    .select("id, role, status")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (
    moderator &&
    (moderator.role === "admin" || moderator.role === "moderator") &&
    moderator.status !== "blocked"
  ) {
    return;
  }

  throw new Error("forbidden");
}

function decodeJwtRole(jwt: string): string | null {
  try {
    const payload = jwt.split(".")[1] ?? "";
    const padded = payload.replace(/-/g, "+").replace(/_/g, "/");
    const json = JSON.parse(atob(padded));
    return typeof json.role === "string" ? json.role : null;
  } catch {
    return null;
  }
}

async function isDuplicate(
  type: string,
  silent: boolean,
  entity: string,
  entityId: string,
): Promise<boolean> {
  try {
    const supabase = serviceClient();
    const windowSec = Math.floor(Date.now() / 15000);
    const key = `${type}:${silent}:${entity}:${entityId}:${windowSec}`;
    const { error } = await supabase.from("push_dedup").insert({ key });
    if (!error) return false;
    return (error.code ?? "") === "23505";
  } catch {
    return false;
  }
}

async function loadTokens(): Promise<string[]> {
  const supabase = serviceClient();
  const { data, error } = await supabase
    .from("user_fcm_tokens")
    .select("token");
  if (error) throw error;
  return (data ?? [])
    .map((row) => String(row.token ?? ""))
    .filter((token) => token.length > 0);
}

async function deleteStaleTokens(tokens: string[]): Promise<void> {
  const supabase = serviceClient();
  const unique = [...new Set(tokens)];
  await supabase.from("user_fcm_tokens").delete().in("token", unique);
}

function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function readServiceAccount(): ServiceAccount {
  const raw =
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ??
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT secret is not set");
  }
  return parseServiceAccount(raw);
}

function parseServiceAccount(raw: string): ServiceAccount {
  let value: unknown = raw.trim();
  if (typeof value === "string") {
    value = JSON.parse(value);
  }
  // Some dashboard pastes store the JSON double-encoded.
  if (typeof value === "string") {
    value = JSON.parse(value);
  }
  const sa = value as ServiceAccount;
  if (!sa?.client_email || !sa?.private_key) {
    throw new Error("Firebase service account JSON is missing client_email or private_key");
  }
  return sa;
}

async function getGoogleAccessToken(): Promise<string> {
  const sa = readServiceAccount();
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const jsonBody = await response.json();
  if (!response.ok || !jsonBody.access_token) {
    throw new Error(`Google token exchange failed: ${JSON.stringify(jsonBody)}`);
  }
  return jsonBody.access_token as string;
}

async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  message: Record<string, unknown>,
): Promise<{ ok: boolean; stale: boolean }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: { token, ...message } }),
    },
  );
  if (response.ok) return { ok: true, stale: false };

  const err = await response.json().catch(() => ({}));
  const status = (err?.error?.status ?? "") as string;
  const details = JSON.stringify(err?.error?.details ?? []);
  const stale =
    status === "NOT_FOUND" ||
    status === "INVALID_ARGUMENT" ||
    details.includes("UNREGISTERED");
  console.error("FCM send failed", status, err);
  return { ok: false, stale };
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const raw = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    raw,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64url(input: string | ArrayBuffer): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function mapPool<T>(
  items: T[],
  concurrency: number,
  worker: (item: T) => Promise<void>,
): Promise<void> {
  let index = 0;
  const runners = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (index < items.length) {
      const current = items[index++];
      await worker(current);
    }
  });
  await Promise.all(runners);
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
