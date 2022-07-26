defmodule CommandMigrationsTest do
  use ExUnit.Case

  setup_all do
    tmp_dir = "tmp"
    File.rm_rf(tmp_dir)
    File.mkdir(tmp_dir)
  end

  def temp_folder() do
    Path.join(["tmp", UUID.uuid4()])
  end

  describe "run commands" do
    test "init migrations" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: nil,
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"
    end

    test "build migrations" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"

      sql_file_paths = Path.join([migrations_path, "*", "migration.sql"]) |> Path.wildcard()
      my_new_migration = List.first(sql_file_paths)
      #      migration_folder = Path.dirname(my_new_migration)

      new_content = """
      CREATE TABLE IF NOT EXISTS items (
        value TEXT PRIMARY KEY
      ) STRICT, WITHOUT ROWID;
      """

      File.write!(my_new_migration, new_content, [:append])

      {:success, _msg} =
        Electric.Commands.Migrations.build(%{
          args: [],
          flags: [],
          options: %{:dir => migrations_path},
          unknown: nil
        })

      assert File.exists?(Path.join([migrations_path, "manifest.json"]))
    end

    test "build migrations errors" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"

      sql_file_paths = Path.join([migrations_path, "*", "migration.sql"]) |> Path.wildcard()
      my_new_migration = List.first(sql_file_paths)
      #      migration_folder = Path.dirname(my_new_migration)

      new_content = """
      CREATE TABLE IF NOT EXISTS items (
        value TEXT PRIMARY KEY
      ) STRICT, WITHOUT ROWID;
      """

      File.write!(my_new_migration, new_content, [:append])

      {:error, msg} =
        Electric.Commands.Migrations.build(%{
          args: [],
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert msg == "There were 1 errors:\nThe migrations folder must be called \"migrations\""
    end

    test "sync migrations" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"

      sql_file_paths = Path.join([migrations_path, "*", "migration.sql"]) |> Path.wildcard()
      my_new_migration = List.first(sql_file_paths)
      _migration_folder = Path.dirname(my_new_migration)

      new_content = """
      CREATE TABLE IF NOT EXISTS items (
        value TEXT PRIMARY KEY
      ) STRICT, WITHOUT ROWID;
      """

      File.write!(my_new_migration, new_content, [:append])

      {:success, msg} =
        Electric.Commands.Migrations.sync(%{
          args: %{},
          flags: [],
          options: %{:dir => migrations_path, :env => "production"},
          unknown: nil
        })

      assert msg == "Migrations synchronized with server successfully"
    end

    test "new migrations" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"

      sql_file_paths = Path.join([migrations_path, "*", "migration.sql"]) |> Path.wildcard()
      my_new_migration = List.first(sql_file_paths)

      new_content = """
      CREATE TABLE IF NOT EXISTS items (
        value TEXT PRIMARY KEY
      ) STRICT, WITHOUT ROWID;
      """

      File.write!(my_new_migration, new_content, [:append])

      {:success, msg} =
        Electric.Commands.Migrations.new(%{
          args: %{migration_title: "Another migration"},
          flags: [],
          options: %{:dir => migrations_path},
          unknown: nil
        })

      assert msg == "New migration created"
    end

    test "list migrations" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"

      sql_file_paths = Path.join([migrations_path, "*", "migration.sql"]) |> Path.wildcard()
      my_new_migration = List.first(sql_file_paths)
      migration_name = Path.dirname(my_new_migration) |> Path.basename()

      new_content = """
      CREATE TABLE IF NOT EXISTS items (
        value TEXT PRIMARY KEY
      ) STRICT, WITHOUT ROWID;
      """

      File.write!(my_new_migration, new_content, [:append])

      {:success, msg} =
        Electric.Commands.Migrations.list(%{
          args: %{},
          flags: [],
          options: %{:dir => migrations_path},
          unknown: nil
        })

      assert msg ==
               "\e[0m\n------ Electric SQL Migrations ------\n\n#{migration_name}\tdefault: -\n"
    end

    test "revert migrations" do
      temp = temp_folder()
      migrations_path = Path.join([temp, "migrations"])

      {:success, msg} =
        Electric.Commands.Migrations.init(%{
          args: %{app: "app-name"},
          flags: [],
          options: %{:dir => temp},
          unknown: nil
        })

      assert File.exists?(migrations_path)
      assert msg == "Migrations initialised"

      sql_file_paths = Path.join([migrations_path, "*", "migration.sql"]) |> Path.wildcard()
      my_new_migration = List.first(sql_file_paths)
      migration_name = Path.dirname(my_new_migration) |> Path.basename()

      new_content = """
      CREATE TABLE IF NOT EXISTS items (
        value TEXT PRIMARY KEY
      ) STRICT, WITHOUT ROWID;
      """

      File.write!(my_new_migration, new_content, [:append])

      {:error, msg} =
        Electric.Commands.Migrations.revert(%{
          args: %{migration_name: migration_name},
          flags: [],
          options: %{:dir => migrations_path, env: "default"},
          unknown: nil
        })

      assert msg ==
               "There was 1 errors:\nThe migration #{migration_name} in environment default is not different. Nothing to revert."
    end
  end
end
