-- Optional interests and a short conversation starter on each member profile.
alter table public.spark_profiles
  add column interests text[] not null default '{}',
  add column prompt_question text not null default '',
  add column prompt_answer text not null default '';

alter table public.spark_profiles
  add constraint spark_profile_interests_valid check (
    cardinality(interests) <= 5
    and interests <@ array[
      'Music','Travel','Food','Books','Films','Fitness',
      'Art','Gaming','Nature','Pets','Dancing','Coffee'
    ]::text[]
  ),
  add constraint spark_profile_prompt_valid check (
    prompt_question in (
      '',
      'A perfect weekend looks like…',
      'The quickest way to make me laugh…',
      'A small thing I love…',
      'Let’s talk about…'
    )
    and char_length(prompt_answer) <= 180
    and (prompt_question <> '' or prompt_answer = '')
  );
