import { createClient } from "npm:@supabase/supabase-js@2";

type ActivityRow = {
  id: string;
  group_id: string;
  actor_member_id: string | null;
  target_id: string | null;
  metadata: Record<string, unknown> | null;
};

const encoder = new TextEncoder();

function base64url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? encoder.encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  return Uint8Array.from(atob(body), (char) => char.charCodeAt(0));
}

async function apnsJWT(): Promise<string> {
  const keyID = Deno.env.get("APNS_KEY_ID")!;
  const teamID = Deno.env.get("APNS_TEAM_ID")!;
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY")!.replaceAll("\\n", "\n");
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const claims = base64url(JSON.stringify({ iss: teamID, iat: Math.floor(Date.now() / 1000) }));
  const input = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(input),
  );
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (request.headers.get("x-webhook-secret") !== Deno.env.get("WEBHOOK_SECRET")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { activity_id } = await request.json();
  if (!activity_id) return new Response("Missing activity_id", { status: 400 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: activity, error: activityError } = await supabase
    .from("activity")
    .select("id, group_id, actor_member_id, target_id, metadata")
    .eq("id", activity_id)
    .single<ActivityRow>();
  if (activityError || !activity) return new Response("Activity not found", { status: 404 });

  const [{ data: group }, { data: actor }, { data: expense }, { data: members }] = await Promise.all([
    supabase.from("groups").select("name").eq("id", activity.group_id).single(),
    activity.actor_member_id
      ? supabase.from("group_members").select("display_name").eq("id", activity.actor_member_id).single()
      : Promise.resolve({ data: null }),
    activity.target_id
      ? supabase.from("expenses").select("description").eq("id", activity.target_id).single()
      : Promise.resolve({ data: null }),
    supabase.from("group_members")
      .select("user_id")
      .eq("group_id", activity.group_id)
      .eq("is_active", true)
      .neq("id", activity.actor_member_id ?? "00000000-0000-0000-0000-000000000000")
      .not("user_id", "is", null),
  ]);

  const userIDs = (members ?? []).map((member) => member.user_id).filter(Boolean);
  if (userIDs.length === 0) return Response.json({ delivered: 0 });

  const { data: tokens } = await supabase
    .from("push_tokens")
    .select("id, token, environment")
    .in("user_id", userIDs);
  if (!tokens?.length) return Response.json({ delivered: 0 });

  const jwt = await apnsJWT();
  let delivered = 0;
  const invalidTokenIDs: string[] = [];
  const title = group?.name ?? "Groopay";
  const actorName = actor?.display_name ?? "Bir grup üyesi";
  const description = expense?.description ?? activity.metadata?.description ?? "yeni bir masraf";

  for (const token of tokens) {
    const { data: prior } = await supabase
      .from("push_deliveries")
      .select("activity_id")
      .eq("activity_id", activity.id)
      .eq("token_id", token.id)
      .maybeSingle();
    if (prior) continue;

    const host = token.environment === "sandbox"
      ? "https://api.sandbox.push.apple.com"
      : "https://api.push.apple.com";
    const response = await fetch(`${host}/3/device/${token.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": "com.groopay.app",
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify({
        aps: {
          alert: { title, body: `${actorName}, ${description} masrafını ekledi.` },
          sound: "default",
        },
        group_id: activity.group_id,
        expense_id: activity.target_id,
      }),
    });

    if (response.ok) {
      delivered += 1;
      await supabase.from("push_deliveries").insert({ activity_id: activity.id, token_id: token.id });
    } else if ([400, 410].includes(response.status)) {
      const body = await response.json().catch(() => ({}));
      if (["BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered"].includes(body.reason)) {
        invalidTokenIDs.push(token.id);
      }
    }
  }

  if (invalidTokenIDs.length) {
    await supabase.from("push_tokens").delete().in("id", invalidTokenIDs);
  }
  return Response.json({ delivered });
});
