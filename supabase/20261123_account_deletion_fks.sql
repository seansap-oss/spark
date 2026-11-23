-- A moderator can delete their own account without leaving dangling references.
alter table public.spark_reports
  drop constraint spark_reports_reviewed_by_fkey,
  add constraint spark_reports_reviewed_by_fkey foreign key (reviewed_by)
    references auth.users(id) on delete set null;

alter table public.spark_suspended_profiles
  drop constraint spark_suspended_profiles_moderator_id_fkey,
  add constraint spark_suspended_profiles_moderator_id_fkey foreign key (moderator_id)
    references auth.users(id) on delete set null;
