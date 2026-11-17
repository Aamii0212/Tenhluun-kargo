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
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Админ аккаунтаар нэвтэрнэ үү." }, 401);

    const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: userData, error: userError } = await caller.auth.getUser();
    if (userError || !userData.user) return json({ error: "Нэвтрэх эрх баталгаажаагүй." }, 401);

    const { data: profile, error: profileError } = await caller
      .from("profiles").select("role").eq("id", userData.user.id).maybeSingle();
    if (profileError || profile?.role !== "admin") return json({ error: "Зөвхөн админ ажилтан нэмнэ." }, 403);

    const body = await req.json();
    const email = String(body.email || "").trim().toLowerCase();
    const branchId = String(body.branch_id || "").trim();
    if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(email)) return json({ error: "Имэйл хаяг буруу байна." }, 400);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(branchId)) {
      return json({ error: "Ажиллах салбараа сонгоно уу." }, 400);
    }

    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: branch, error: branchError } = await admin.from("branches").select("id,name").eq("id", branchId).maybeSingle();
    if (branchError || !branch) return json({ error: "Салбар олдсонгүй. Салбарын жагсаалтыг шинэчилнэ үү." }, 404);

    const { data: users, error: usersError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (usersError) return json({ error: "Хэрэглэгч шалгахад алдаа гарлаа: " + usersError.message }, 500);
    let target = users.users.find((u) => (u.email || "").toLowerCase() === email);
    let invited = false;
    let recoverySent = false;

    if (!target) {
      const { data, error } = await admin.auth.admin.inviteUserByEmail(email);
      if (error) return json({ error: error.message }, 400);
      target = data.user || undefined;
      invited = true;
      if (!target) return json({ error: "Урилга илгээсэн ч хэрэглэгчийн ID олдсонгүй." }, 500);
    }

    const { data: existingProfile } = await admin.from("profiles").select("role").eq("id", target.id).maybeSingle();
    if (existingProfile?.role === "admin") return json({ error: "Админы аккаунтыг ажилтан болгож өөрчлөхгүй." }, 409);

    const { error: profileUpsertError } = await admin.from("profiles")
      .upsert({ id: target.id, role: "employee" }, { onConflict: "id" });
    if (profileUpsertError) {
      return json({ error: "Хэрэглэгч олдсон боловч ажилтны эрх олгоход алдаа гарлаа: " + profileUpsertError.message }, 500);
    }

    const { error: accessError } = await admin.from("employee_branch_access")
      .upsert({ employee_id: target.id, branch_id: branchId, employee_email: email }, { onConflict: "employee_id,branch_id" });
    if (accessError) {
      return json({ error: "Ажилтны эрх үүссэн боловч салбар онооход алдаа гарлаа: " + accessError.message }, 500);
    }

    if (!invited) {
      const { error: recoveryError } = await admin.auth.resetPasswordForEmail(email);
      recoverySent = !recoveryError;
    }

    const message = invited
      ? "✓ " + email + " хаяг руу ажилтны урилга илгээж, " + branch.name + " салбарт оноолоо. Имэйлээ нээж урилгаа баталгаажуулна уу."
      : "✓ " + email + " ажилтны эрхийг идэвхжүүлж, " + branch.name + " салбарт оноолоо. " + (recoverySent ? "Нууц үг сэргээх холбоос имэйл рүү илгээлээ." : "Нэвтрэх нууц үгээ мартсан бол нэвтрэх хуудсын сэргээх холбоосыг ашиглана уу.");
    return json({ success: true, user_id: target.id, email, invited, recovery_sent: recoverySent, message });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Тодорхойгүй алдаа" }, 500);
  }
});
