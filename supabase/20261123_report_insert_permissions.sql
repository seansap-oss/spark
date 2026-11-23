-- Review fields are set by moderators only; reporters submit the three input fields.
revoke insert on public.spark_reports from authenticated;
grant insert(reporter_id,reported_id,reason) on public.spark_reports to authenticated;
