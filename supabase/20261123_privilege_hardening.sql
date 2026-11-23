-- Default public-schema grants include TRUNCATE, which bypasses row policies.
-- Browser roles only need the row operations granted in the feature migrations.
revoke truncate, references, trigger on
  public.spark_profiles,
  public.spark_blocks,
  public.spark_connections,
  public.spark_messages,
  public.spark_reports,
  public.spark_social_links,
  public.spark_profile_photos,
  public.spark_moderators,
  public.spark_suspended_profiles
from anon, authenticated;
