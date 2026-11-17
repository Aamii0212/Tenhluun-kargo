-- Тэнхлүүн Карго: трак кодыг бүх салбарт давхар бүртгэхээс хамгаалах
-- Supabase Dashboard → SQL Editor дээр нэг удаа ажиллуул.
-- Одоогийн хуучин давхардсан бүртгэлийг устгахгүй; зөвхөн цаашдын INSERT/UPDATE-г хориглоно.

CREATE OR REPLACE FUNCTION public.prevent_duplicate_cargo_tracking_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_code text;
BEGIN
  normalized_code := upper(regexp_replace(btrim(coalesce(NEW.tracking_code, '')), '\s+', '', 'g'));

  IF normalized_code = '' THEN
    RAISE EXCEPTION 'Трак код хоосон байж болохгүй.'
      USING ERRCODE = '23514';
  END IF;

  -- Ижил кодын зэрэгцээ орж ирсэн хүсэлтүүдийг дарааллуулна.
  PERFORM pg_advisory_xact_lock(hashtextextended(normalized_code, 0));

  IF TG_TABLE_NAME = 'parcels' THEN
    IF EXISTS (
      SELECT 1 FROM public.parcels p
      WHERE upper(regexp_replace(btrim(coalesce(p.tracking_code, '')), '\s+', '', 'g')) = normalized_code
        AND p.id::text IS DISTINCT FROM NEW.id::text
    ) THEN
      RAISE EXCEPTION 'Энэ трак код өмнө нь бүртгэгдсэн: %', normalized_code
        USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.customer_pre_registrations r
      WHERE upper(regexp_replace(btrim(coalesce(r.tracking_code, '')), '\s+', '', 'g')) = normalized_code
        AND coalesce(r.status, 'pending') <> 'confirmed'
    ) THEN
      RAISE EXCEPTION 'Энэ трак код урьдчилан бүртгэгдсэн байна: %', normalized_code
        USING ERRCODE = '23505';
    END IF;
  ELSIF TG_TABLE_NAME = 'customer_pre_registrations' THEN
    IF EXISTS (
      SELECT 1 FROM public.customer_pre_registrations r
      WHERE upper(regexp_replace(btrim(coalesce(r.tracking_code, '')), '\s+', '', 'g')) = normalized_code
        AND r.id::text IS DISTINCT FROM NEW.id::text
    ) THEN
      RAISE EXCEPTION 'Энэ трак код урьдчилан бүртгэгдсэн байна: %', normalized_code
        USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.parcels p
      WHERE upper(regexp_replace(btrim(coalesce(p.tracking_code, '')), '\s+', '', 'g')) = normalized_code
    ) THEN
      RAISE EXCEPTION 'Энэ трак код ачаанд аль хэдийн бүртгэгдсэн байна: %', normalized_code
        USING ERRCODE = '23505';
    END IF;
  END IF;

  NEW.tracking_code := normalized_code;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS parcels_prevent_duplicate_tracking_code ON public.parcels;
CREATE TRIGGER parcels_prevent_duplicate_tracking_code
BEFORE INSERT OR UPDATE OF tracking_code ON public.parcels
FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_cargo_tracking_code();

DROP TRIGGER IF EXISTS pre_registrations_prevent_duplicate_tracking_code ON public.customer_pre_registrations;
CREATE TRIGGER pre_registrations_prevent_duplicate_tracking_code
BEFORE INSERT OR UPDATE OF tracking_code ON public.customer_pre_registrations
FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_cargo_tracking_code();

-- Давхардсан хуучин кодыг шалгах (устгахгүй):
-- SELECT upper(regexp_replace(btrim(tracking_code), '\s+', '', 'g')) AS code,
--        count(*) AS copies
-- FROM public.parcels
-- GROUP BY 1 HAVING count(*) > 1 ORDER BY copies DESC;
--
-- SELECT upper(regexp_replace(btrim(tracking_code), '\s+', '', 'g')) AS code,
--        count(*) AS copies
-- FROM public.customer_pre_registrations
-- GROUP BY 1 HAVING count(*) > 1 ORDER BY copies DESC;

NOTIFY pgrst, 'reload schema';
