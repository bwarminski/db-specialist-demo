# ABOUTME: Loads benchmark-sized demo records for the Rails anti-pattern endpoints.
# ABOUTME: Seeds users and todos from env-controlled SQL so benchmark resets stay fast.
rows_per_table = Integer(ENV.fetch("ROWS_PER_TABLE", "100000"))
user_count = Integer(ENV.fetch("USER_COUNT", "1000"))
seed_value = Integer(ENV.fetch("SEED", "42"))
open_fraction = Float(ENV.fetch("OPEN_FRACTION", "0.6"))

ActiveRecord::Base.connection.execute(<<~SQL)
  TRUNCATE TABLE todos, users RESTART IDENTITY;
  SELECT setseed(#{seed_value.to_f / 1000});

  INSERT INTO users (name, created_at, updated_at)
  SELECT
    'user_' || i,
    NOW(),
    NOW()
  FROM generate_series(1, #{user_count}) AS i;

  INSERT INTO todos (title, status, user_id, created_at, updated_at)
  SELECT
    'todo ' || i,
    CASE
      WHEN random() < #{open_fraction} THEN 'open'
      ELSE 'closed'
    END,
    ((i - 1) % #{user_count}) + 1,
    NOW(),
    NOW()
  FROM generate_series(1, #{rows_per_table}) AS i;

  ANALYZE users;
  ANALYZE todos;
SQL
