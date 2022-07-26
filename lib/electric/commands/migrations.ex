defmodule Electric.Commands.Migrations do
  @moduledoc """
  The `Migrations` command.


  # Initialise a new set of migrations and the initial migration file
  electric migrations init --migrations-dir ./local/path/to/migrations

  # Generate an new empty migration file.
  electric migrations new :migration_name --migrations-dir ./local/path/to/migrations

  # Read the migrations source folder. Validate.
  # Create a output folder with patched files
  # containing triggers.
  electric migrations build --migrations-dir ./local/path/to/migrations --manifest --bundle

  # Sync the migrations with the console, so that
  # they can be applied to PG and propagated to
  # satellite clients.
  electric migrations push :database_id --migrations-dir ./local/path/to/migrations
  """
  use Electric, :command

  @migration_title [
    migration_title: [
      value_name: "MIGRATION_TITLE",
      help: "Title of a new migration",
      required: true,
      parser: :string
    ]
  ]

  @migration_name [
    migration_name: [
      value_name: "MIGRATION_NAME",
      help: "The name of an existing migration",
      required: true,
      parser: :string
    ]
  ]

  @app [
    app: [
      value_name: "APP_ID",
      help: "Globally unique slug generated when you create an application",
      required: true,
      parser: :string
    ]
  ]

  @dir [
    dir: [
      value_name: "MIGRATIONS_DIR",
      short: "-d",
      long: "--dir",
      help: "Migrations directory where the migration files live.",
      parser: :string,
      default: "./migrations"
    ]
  ]

  @env [
    env: [
      value_name: "ENVIRONMENT_NAME",
      short: "-e",
      long: "--env",
      help: "The name of the app environment you want to use.",
      parser: :string,
      default: "default"
    ]
  ]

  @postgres [
    postgres: [
      long: "--postgres",
      short: "-p",
      help: "Also generate PostgresSQL when building",
      required: false
    ]
  ]

  @satellite [
    satellite: [
      long: "--satellite",
      short: "-s",
      help: "Also generate satellite SQL when building",
      required: false
    ]
  ]

  def spec do
    [
      name: "migrations",
      about: "Manage database schema migrations",
      subcommands: [
        init: [
          name: "init",
          about: """
          Initializes a 'migrations' folder for your app.

          Creates a new folder for migrations in your current directory called 'migrations' and adds a new migration
          folder to it with a name automatically derived from the current time in UTC and the title 'init' e.g. '20221116162204816_init'

          Inside this folder will be a file called `migration.sql`. You should write your initial SQLite DDL SQL into this file.

          The APP_ID you give should be the slug of the app previous created in the web console.
          You give it once here and the CLI stores it in the 'migrations/manifest.json' so you don't have to keep re-typing it.
          """,
          args: @app,
          options: @dir,
          flags: default_flags()
        ],
        app: [
          name: "app",
          about: """
          Updates the app used.

          Changes the stored APP_ID that is used by all the other CLI migrations commands.
          """,
          args: @app,
          options: @dir,
          flags: default_flags()
        ],
        new: [
          name: "new",
          about: """
          Creates a new migration.

          MIGRATION_TITLE should be a short human readable description of the new migration.

          This adds a new migration to the 'migrations' folder with a name automatically derived from the current
          time in UTC and the given title.

          """,
          args: @migration_title,
          options: @dir,
          flags: default_flags()
        ],
        build: [
          name: "build",
          about: """
          Builds a javascript file at `dist/index.js`.

          This file bundles all your migrations with Electric DB's added DDL and some additional metadata.

          The metadata in this file will have a `"env": "local" to indicate the it was built from your local files
          rather that one of the named app environments.

          Add this file to your mobile or web project to configure your SQLite database.
          """,
          options: @dir,
          flags: default_flags() |> Keyword.merge(@postgres) |> Keyword.merge(@satellite)
        ],
        sync: [
          name: "sync",
          about: """
          Synchronises migrations with the server.

          Synchronises changes you have made to migration SQL files in your local `migrations` folder up to the Electric SQl servers,
          and builds a new javascript file at `dist/index.js` that matches the newly synchronised set of migrations.

          The metadata in this file will have a `"env": ENVIRONMENT_NAME to indicate that it was built directly from and matches
          the named app environment.

          By default this will sync to the `default` environment for your app. If you want to use a different one give its name
          with `--env ENVIRONMENT_NAME`

          If the app environment on our servers already has a migration with the same name but different sha256 then this
          synchronisation will fail because a migration cannot be modified once it has been applied.
          If this happens you have two options, either revert the local changes you have made to the conflicted migration using
          the `revert` command below or, if you are working in a development environment that you are happy to reset,
          you can reset the whole environment's DB using the web control panel.

          Also if a migration has a name that is lower in sort order than one already applied on the server this sync will fail.
          """,
          options: @dir ++ @env,
          flags: default_flags()
        ],
        #        apply: [
        #          name: "apply",
        #          about: """
        #          Applies all migrations
        #          """,
        #          options: @dir,
        #          flags: default_flags()
        #        ],
        list: [
          name: "list",
          about: """
          Lists all migrations.

          Shows a list of all the migrations and their status in every env in the app.
          """,
          options: @dir,
          flags: default_flags()
        ],
        revert: [
          name: "revert",
          about: """
          Copies the named migration from the server to replace the local one.
          """,
          args: @migration_name,
          options: @dir ++ @env,
          flags: default_flags()
        ]
      ]
    ]
  end

  def format_messages(type_of_message, messages) when is_list(messages) do
    "There were #{length(messages)} #{type_of_message}:\n" <> Enum.join(messages, "\n")
  end

  def format_messages(type_of_message, messages) do
    "There was 1 #{type_of_message}:\n" <> messages
  end

  def init(%{args: %{app: app_id}, flags: _flags, options: options, unknown: _unknown}) do
    Progress.run("Initializing", fn ->
      case Electric.Migrations.init_migrations(app_id, options) do
        {:ok, nil} ->
          {:success, "Migrations initialised"}

        {:error, errors} ->
          {:error, format_messages("errors", errors)}
      end
    end)
  end

  def new(%{args: args, flags: _flags, options: options, unknown: _unknown}) do
    Progress.run("Creating new migration", fn ->
      case Electric.Migrations.new_migration(args.migration_title, options) do
        {:ok, nil} ->
          {:success, "New migration created"}

        {:error, errors} ->
          {:error, format_messages("errors", errors)}
      end
    end)
  end

  def build(%{options: options, flags: flags, unknown: _unknown}) do
    Progress.run("Building satellite migrations", fn ->
      case Electric.Migrations.build_migrations(options, flags) do
        {:ok, nil} ->
          {:success, "Migrations built successfully"}

        {:ok, warnings} ->
          #        IO.inspect(warnings)
          {:success, format_messages("warnings", warnings)}

        {:error, errors} ->
          {:error, format_messages("errors", errors)}
      end
    end)
  end

  #  def apply(%{options: options, unknown: _unknown}) do
  #    environment = Map.get(options, :env, "default")
  #
  #    Progress.run("Applying satellite migrations", fn ->
  #      case Electric.Migrations.apply_migrations(environment, options) do
  #        {:ok, nil} ->
  #          {:success, "Migrations applied successfully"}
  #        {:ok, warnings} ->
  #          #        IO.inspect(warnings)
  #          {:success, format_messages("warnings", warnings)}
  #
  #        {:error, errors} ->
  #          {:error, format_messages("errors", errors)}
  #      end
  #    end)
  #  end

  def sync(%{args: _args, flags: _flags, options: options, unknown: _unknown}) do
    environment = Map.get(options, :env, "default")

    Progress.run("Synchronizing migrations", fn ->
      case Electric.Migrations.sync_migrations(environment, options) do
        {:ok, nil} ->
          {:success, "Migrations synchronized with server successfully"}

        {:ok, warnings} ->
          #        IO.inspect(warnings)
          {:success, format_messages("warnings", warnings)}

        {:error, errors} ->
          {:error, format_messages("errors", errors)}
      end
    end)
  end

  def list(%{options: options}) do
    case Electric.Migrations.list_migrations(options) do
      {:ok, listing, _mismatched} ->
        {:success, listing}

      {:error, errors} ->
        {:error, format_messages("errors", errors)}
    end
  end

  def app(%{args: %{app: app_id}, options: options}) do
    case Electric.Migrations.update_app_id(app_id, options) do
      {:ok, _} ->
        {:success, "Changed to using app #{app_id}"}

      {:error, errors} ->
        {:error, format_messages("errors", errors)}
    end
  end

  def revert(%{args: %{migration_name: migration_name}, options: options}) do
    environment = Map.get(options, :env, "default")

    Progress.run("Reverting migration", fn ->
      case Electric.Migrations.revert_migration(environment, migration_name, options) do
        {:ok, nil} ->
          {:success, "Migration reverted successfully"}

        {:ok, warnings} ->
          #        IO.inspect(warnings)
          {:success, format_messages("warnings", warnings)}

        {:error, errors} ->
          {:error, format_messages("errors", errors)}
      end
    end)
  end
end
