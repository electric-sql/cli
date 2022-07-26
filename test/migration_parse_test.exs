defmodule MigrationsParseTest do
  use ExUnit.Case

  describe "Parse sql" do
    test "tests can get column names" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS fish (
      value TEXT PRIMARY KEY,
      colour TEXT
      ) STRICT, WITHOUT ROWID;
      """

      migration = %{name: "test1", original_body: sql_in}
      {:ok, info, _} = Electric.Migrations.Parse.sql_ast_from_migrations([migration])

      column_names = info["main.fish"][:columns]
      assert column_names == ["value", "colour"]
    end

    test "tests nonsense SQL fails" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS fish (
      value TEXT PRIMARY KEY
      );
      SOME BOLLOCKS;
      """

      migration = %{name: "test1", original_body: sql_in}

      {_status, reason} = Electric.Migrations.Parse.sql_ast_from_migrations([migration])
      assert reason == ["In migration test1 SQL error: near \"SOME\": syntax error"]
    end

    test "tests can check for strictness and rowid" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS fish (
      value TEXT PRIMARY KEY,
      colour TEXT
      );
      """

      {:error, message} =
        Electric.Migrations.Parse.sql_ast_from_migrations([
          %{name: "test1", original_body: sql_in}
        ])

      expected = [
        "The table fish is not WITHOUT ROWID.",
        "The primary key value in table fish isn't NOT NULL. Please add NOT NULL to this column."
      ]

      assert message == expected
    end

    test "test doesn't allow main namespace" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS main.fish (
      value TEXT PRIMARY KEY,
      colour TEXT
      )STRICT, WITHOUT ROWID;
      """

      {:error, message} =
        Electric.Migrations.Parse.sql_ast_from_migrations([
          %{name: "test1", original_body: sql_in}
        ])

      expected = [
        "The table main.fish has a database name. Please leave this out and only give the table name."
      ]

      assert message == expected
    end

    test "text find_table_names" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS main.fish (
      value TEXT PRIMARY KEY,
      colour TEXT
      )STRICT, WITHOUT ROWID;

      CREATE TABLE  goat
      (
      value TEXT PRIMARY KEY,
      colour TEXT
      )STRICT, WITHOUT ROWID;

      create table  apples.house
      (
      value TEXT PRIMARY KEY,
      colour TEXT
      )STRICT, WITHOUT ROWID;

      """

      names = Electric.Migrations.Parse.namespaced_table_names(sql_in)

      assert names == ["main.fish", "apples.house"]
    end

    test "test doesn't allow any namespaces" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS apple.fish (
      value TEXT PRIMARY KEY,
      colour TEXT
      )STRICT, WITHOUT ROWID;
      """

      {:error, message} =
        Electric.Migrations.Parse.sql_ast_from_migrations([
          %{name: "test1", original_body: sql_in}
        ])

      expected = [
        "The table apple.fish has a database name. Please leave this out and only give the table name."
      ]

      assert message == expected
    end

    test "tests getting SQL structure for templating" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS parent (
        id INTEGER PRIMARY KEY,
        value TEXT
      ) STRICT, WITHOUT ROWID;

      CREATE TABLE IF NOT EXISTS child (
        id INTEGER PRIMARY KEY,
        daddy INTEGER NOT NULL,
        FOREIGN KEY(daddy) REFERENCES parent(id)
      ) STRICT, WITHOUT ROWID;
      """

      {:ok, info, _} =
        Electric.Migrations.Parse.sql_ast_from_migrations([
          %{name: "test1", original_body: sql_in}
        ])

      expected_info = %{
        "main.parent" => %{
          :namespace => "main",
          :table_name => "parent",
          :validation_fails => [],
          :warning_messages => [],
          :primary => ["id"],
          :foreign_keys => [],
          :columns => ["id", "value"],
          column_infos: %{
            0 => %{
              cid: 0,
              dflt_value: nil,
              name: "id",
              notnull: 1,
              pk: 1,
              type: "INTEGER",
              pk_desc: false,
              unique: false
            },
            1 => %{
              cid: 1,
              dflt_value: nil,
              name: "value",
              notnull: 0,
              pk: 0,
              type: "TEXT",
              pk_desc: false,
              unique: false
            }
          },
          foreign_keys_info: [],
          table_info: %{
            name: "parent",
            rootpage: 2,
            sql:
              "CREATE TABLE parent (\n  id INTEGER PRIMARY KEY,\n  value TEXT\n) STRICT, WITHOUT ROWID",
            tbl_name: "parent",
            type: "table"
          }
        },
        "main.child" => %{
          :namespace => "main",
          :table_name => "child",
          :validation_fails => [],
          :warning_messages => [],
          :primary => ["id"],
          :foreign_keys => [
            %{:child_key => "daddy", :parent_key => "id", :table => "main.parent"}
          ],
          :columns => ["id", "daddy"],
          column_infos: %{
            0 => %{
              cid: 0,
              dflt_value: nil,
              name: "id",
              notnull: 1,
              pk: 1,
              type: "INTEGER",
              pk_desc: false,
              unique: false
            },
            1 => %{
              cid: 1,
              dflt_value: nil,
              name: "daddy",
              notnull: 1,
              pk: 0,
              type: "INTEGER",
              pk_desc: false,
              unique: false
            }
          },
          foreign_keys_info: [
            %{
              from: "daddy",
              id: 0,
              match: "NONE",
              on_delete: "NO ACTION",
              on_update: "NO ACTION",
              seq: 0,
              table: "parent",
              to: "id"
            }
          ],
          table_info: %{
            name: "child",
            rootpage: 3,
            sql:
              "CREATE TABLE child (\n  id INTEGER PRIMARY KEY,\n  daddy INTEGER NOT NULL,\n  FOREIGN KEY(daddy) REFERENCES parent(id)\n) STRICT, WITHOUT ROWID",
            tbl_name: "child",
            type: "table"
          }
        }
      }

      assert info == expected_info
    end

    test "tests getting uniques" do
      sql_in = """
      CREATE TABLE IF NOT EXISTS parent (
        id INTEGER PRIMARY KEY DESC,
        value TEXT,
        email TEXT UNIQUE
      ) STRICT, WITHOUT ROWID;

      CREATE TABLE IF NOT EXISTS child (
        id INTEGER PRIMARY KEY,
        daddy INTEGER NOT NULL,
        FOREIGN KEY(daddy) REFERENCES parent(id)
      ) STRICT, WITHOUT ROWID;
      """

      {:ok, info, _} =
        Electric.Migrations.Parse.sql_ast_from_migrations([
          %{name: "test1", original_body: sql_in}
        ])

      expected_info = %{
        "main.child" => %{
          column_infos: %{
            0 => %{
              cid: 0,
              dflt_value: nil,
              name: "id",
              notnull: 1,
              pk: 1,
              type: "INTEGER",
              unique: false,
              pk_desc: false
            },
            1 => %{
              cid: 1,
              dflt_value: nil,
              name: "daddy",
              notnull: 1,
              pk: 0,
              type: "INTEGER",
              unique: false,
              pk_desc: false
            }
          },
          columns: ["id", "daddy"],
          foreign_keys: [%{child_key: "daddy", parent_key: "id", table: "main.parent"}],
          foreign_keys_info: [
            %{
              from: "daddy",
              id: 0,
              match: "NONE",
              on_delete: "NO ACTION",
              on_update: "NO ACTION",
              seq: 0,
              table: "parent",
              to: "id"
            }
          ],
          namespace: "main",
          validation_fails: [],
          warning_messages: [],
          primary: ["id"],
          table_info: %{
            name: "child",
            rootpage: 4,
            sql:
              "CREATE TABLE child (\n  id INTEGER PRIMARY KEY,\n  daddy INTEGER NOT NULL,\n  FOREIGN KEY(daddy) REFERENCES parent(id)\n) STRICT, WITHOUT ROWID",
            tbl_name: "child",
            type: "table"
          },
          table_name: "child"
        },
        "main.parent" => %{
          column_infos: %{
            0 => %{
              cid: 0,
              dflt_value: nil,
              name: "id",
              notnull: 1,
              pk: 1,
              type: "INTEGER",
              unique: false,
              pk_desc: true
            },
            1 => %{
              cid: 1,
              dflt_value: nil,
              name: "value",
              notnull: 0,
              pk: 0,
              type: "TEXT",
              unique: false,
              pk_desc: false
            },
            2 => %{
              cid: 2,
              dflt_value: nil,
              name: "email",
              notnull: 0,
              pk: 0,
              type: "TEXT",
              unique: true,
              pk_desc: false
            }
          },
          columns: ["id", "value", "email"],
          foreign_keys: [],
          validation_fails: [],
          warning_messages: [],
          foreign_keys_info: [],
          namespace: "main",
          primary: ["id"],
          table_info: %{
            name: "parent",
            rootpage: 2,
            sql:
              "CREATE TABLE parent (\n  id INTEGER PRIMARY KEY DESC,\n  value TEXT,\n  email TEXT UNIQUE\n) STRICT, WITHOUT ROWID",
            tbl_name: "parent",
            type: "table"
          },
          table_name: "parent"
        }
      }

      assert info == expected_info
    end
  end
end
