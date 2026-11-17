-- Тэнхлүүн Карго: трак кодыг давхар бүртгэхээс мэдээллийн сангийн түвшинд хамгаална.
-- Supabase Dashboard → SQL Editor дээр нэг удаа ажиллуулна.
-- Одоо байгаа давхардсан мөрүүдийг УСТГАХГҮЙ; зөвхөн цаашдын insert/update-г хамгаална.

CREATE OR REPLACE FUNCTION public.cargo_guard_unique_tracking_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_code text;
  v_id text;
  v_phone text;
  v_pre_count integer := 0;
  v_exists boolean := false;
BEGIN
  v_code := upper(regexp_replace(btrim(coalesce(NEW.tracking_code, '')), '\s+', '', 'g'));
  IF v_code = '' THEN
    RAISE EXCEPTION 'Трак код хоосон байж болохгүй.' USING ERRCODE = '23514';
  END IF;
  NEW.tracking_code := v_code;
  v_id := coalesce(to_jsonb(NEW)->>'id', '');

  -- Ижил кодын зэрэгцээ хүсэлтүүдийг дараалалд оруулж race condition-оос хамгаална.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_code, 0));

  IF TG_TABLE_NAME = 'customer_pre_registrations' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.parcels p
      WHERE upper(regexp_replace(btrim(coalesce(p.tracking_code, '')), '\s+', '', 'g')) = v_code
    ) INTO v_exists;
    IF v_exists THEN
      RAISE EXCEPTION 'Энэ трак код ачааны жагсаалтад аль хэдийн бүртгэгдсэн байна: %', v_code
        USING ERRCODE = '23505';
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.customer_pre_registrations r
      WHERE upper(regexp_replace(btrim(coalesce(r.tracking_code, '')), '\s+', '', 'g')) = v_code
        AND r.id::text <> v_id
    ) INTO v_exists;
    IF v_exists THEN
      RAISE EXCEPTION 'Энэ трак код урьдчилсан бүртгэлд аль хэдийн байна: %', v_code
        USING ERRCODE = '23505';
    END IF;

  ELSIF TG_TABLE_NAME = 'parcels' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.parcels p
      WHERE upper(regexp_replace(btrim(coalesce(p.tracking_code, '')), '\s+', '', 'g')) = v_code
        AND p.id::text <> v_id
    ) INTO v_exists;
    IF v_exists THEN
      RAISE EXCEPTION 'Энэ трак код ачааны жагсаалтад аль хэдийн байна: %', v_code
        USING ERRCODE = '23505';
    END IF;

    -- Нэг урьдчилсан бүртгэлийг админ батлахад parcels руу шилжүүлэхийг зөвшөөрнө.
    -- Харин ижил кодын олон урьдчилсан хүсэлт байвал баталгаажуулалтыг хориглоно.
    SELECT count(*), min(r.customer_phone)
      INTO v_pre_count, v_phone
    FROM public.customer_pre_registrations r
    WHERE upper(regexp_replace(btrim(coalesce(r.tracking_code, '')), '\s+', '', 'g')) = v_code;

    IF v_pre_count > 1 THEN
      RAISE EXCEPTION 'Энэ трак код урьдчилсан бүртгэлд давхар байна. Эхлээд давхардлыг шалгана уу: %', v_code
        USING ERRCODE = '23505';
    ELSIF v_pre_count = 1 AND v_phone IS DISTINCT FROM NEW.customer_phone THEN
      RAISE EXCEPTION 'Энэ трак код өөр хэрэглэгчийн урьдчилсан бүртгэлтэй байна: %', v_code
        USING ERRCODE = '23505';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cargo_unique_tracking_pre_reg ON public.customer_pre_registrations;
CREATE TRIGGER cargo_unique_tracking_pre_reg
BEFORE INSERT OR UPDATE OF tracking_code ON public.customer_pre_registrations
FOR EACH ROW EXECUTE FUNCTION public.cargo_guard_unique_tracking_code();

DROP TRIGGER IF EXISTS cargo_unique_tracking_parcels ON public.parcels;
CREATE TRIGGER cargo_unique_tracking_parcels
BEFORE INSERT OR UPDATE OF tracking_code ON public.parcels
FOR EACH ROW EXECUTE FUNCTION public.cargo_guard_unique_tracking_code();

NOTIFY pgrst, 'reload schema';
