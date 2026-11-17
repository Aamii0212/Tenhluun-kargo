import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Нэвтэрнэ үү." }, 401);

    const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: userData, error: userError } = await caller.auth.getUser();
    if (userError || !userData.user) return json({ error: "Нэвтрэх эрх баталгаажаагүй." }, 401);

    const { data: profile, error: profileError } = await caller
      .from("profiles").select("role").eq("id", userData.user.id).maybeSingle();
    if (profileError || profile?.role !== "admin") return json({ error: "Зөвхөн админ ажилтан нэмнэ." }, 403);

    const body = await req.json();
    const email = String(body.email || "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "Имэйл хаяг буруу байна." }, 400);

    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email);
    if (inviteError) {
      if (/already|registered|exists/i.test(inviteError.message)) {
        return json({ error: "Энэ имэйлээр хэрэглэгч өмнө нь бүртгэгдсэн байна. Салбар оноох товчийг ашиглана уу." }, 409);
      }
      return json({ error: inviteError.message }, 400);
    }
    if (!invited.user) return json({ error: "Урилга илгээсэн ч хэрэглэгчийн мэдээлэл буцаж ирсэнгүй." }, 500);

    const { error: upsertError } = await admin.from("profiles")
      .upsert({ id: invited.user.id, role: "employee" }, { onConflict: "id" });
    if (upsertError) return json({ error: "Урилга илгээгдсэн боловч ажилтны эрх тохируулахад алдаа гарлаа: " + upsertError.message }, 500);

    return json({ success: true, user_id: invited.user.id, email, message: "Ажилтны урилга илгээгдлээ." });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Тодорхойгүй алдаа" }, 500);
  }
});
