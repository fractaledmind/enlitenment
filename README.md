# En*lite*nment

`enlitenment` is a [Rails application template script](https://guides.rubyonrails.org/rails_application_templates.html) that will lead you along the path to SQLite on Rails enlightenment.

Achieving SQLite on Rails nirvana requires 4 critical pieces:

1. properly configured SQLite connections for [optimal performance](https://fractaledmind.github.io/2024/04/15/sqlite-on-rails-the-how-and-why-of-optimal-performance/)
2. properly configured [Solid Queue](https://github.com/rails/solid_queue) for background jobs
3. properly configured [Solid Cache](https://github.com/rails/solid_cache) for caching
4. properly configured [Litestream](https://github.com/fractaledmind/litestream-ruby) for backups

The `enlitenment` script provides all 4 pieces, each carefully tuned to be production-ready.

> [!IMPORTANT]
> Testing the template script while it is private requires you copying the url from the web interface, which includes a `token` query param. Using the URL without that `token` query param results in a 404.

## Usage

You can use a Rails application template script either when scaffolding a new Rails application, or you can apply the template to an existing Rails application.

To apply the template while scaffolding a new Rails application, you pass the location of the template (local or remote) using the `-m` or `--template` option to the `rails new` command:

```bash
rails new my-app \
  --template https://raw.githubusercontent.com/fractaledmind/enlitenment/main/template.rb
```

If you want to apply the template to an existing application, you use the `app:template` command and pass the location of the template via the `LOCATION` environment variable:
```bash
bin/rails app:template \
  LOCATION=https://raw.githubusercontent.com/fractaledmind/enlitenment/main/template.rb
```

Rails accepts a URL to a remote version of the script file, so you can point directly to the template file in this repository.

Regardless of how you apply the template, you can also configure various details of how the script will upgrade your application via environment variables.

You can skip certain sections of the script using the `SKIP_*` environment variables:

| Variable                | Default |
| :---                    | :---:   |
| `SKIP_SOLID_QUEUE`      | `false` |
| `SKIP_SOLID_CACHE`      | `false` |
| `SKIP_LITESTREAM`       | `false` |
| `SKIP_DEV_CACHE`        | `false` |
| `SKIP_LITESTREAM_CREDS` | `false` |

`SKIP_SOLID_QUEUE` will skip the entire process of installing and configuring [Solid Queue](https://github.com/rails/solid_queue). This process consists of 10 steps, which would all be skipped if you set this variable to `true`:

1. add the appropriate solid_queue gem version
2. install the gem
3. define the new database configuration
4. add the new database configuration to all environments
5. run the Solid Queue installation generator
6. run the migrations for the new database
7. configure the application to use Solid Queue in all environments with the new database
8. add the Solid Queue plugin to Puma
9. add the Solid Queue engine to the application
10. mount the Solid Queue engine

`SKIP_SOLID_CACHE` will skip the entire process of installing and configuring [Solid Cache](https://github.com/rails/solid_cache). This process consists of 8 steps, which would all be skipped if you set this variable to `true`:

1. add the appropriate solid_cache gem version
2. install the gem
3. define the new database configuration
4. add the new database configuration to all environments
5. run the Solid Cache installation generator
6. run the migrations for the new database
7. configure Solid Cache to use the new database
8. optionally enable the cache in development

`SKIP_LITESTREAM` will skip the entire process of installing and configuring [Litestream](https://github.com/fractaledmind/litestream-ruby). This process consists of 5 steps, which would all be skipped if you set this variable to `true`:

1. add the litestream gem
2. install the gem
3. run the Litestream installation generator
4. add the Litestream plugin to Puma
5. add the Litestream engine to the application

In comparison, the next two `SKIP_*` environment variables are more granular. `SKIP_DEV_CACHE` will skip the step of enabling the cache in development. This simply means that in step 8 of the Solid Cache configuration process, the `rails dev:cache` action will not be run. Similarly, `SKIP_LITESTREAM_CREDS` will simply skip step 5 of configuring Litestream and not uncomment the lines in the `config/intializers/litestream.rb` file. You will need to configure Litestream yourself by hand.

- - -

When installing and configuring Solid Queue and Solid Cache, `enlitenment` will use a separate SQLite database for each. You can define the names for the those databases using the `*_DB` environment variables:

| Variable   | Default   |
| :---       | :---:     |
| `QUEUE_DB` | `"queue"` |
| `CACHE_DB` | `"cache"` |

These database names will be used in the `config/database.yml` file to define the new database configurations as well as in the Solid Queue and Solid Cache configuration files to ensure that both gems understand that they are supposed to read and write from these separate SQLite databases.

- - -

Finally, the script will also install the [Mission Control — Jobs](https://github.com/rails/mission_control-jobs) gem to provide a web UI for Solid Queue. You can configure the route path that it will be mounted at as well as the name of the controller it will inherit from (this is to ensure that this web dashboard is properly secured and not easily accessible to random visitors). You can configure these details using the `JOBS_*` environment variables:

| Variable          | Default             |
| :---              | :---:               |
| `JOBS_ROUTE`      | `"/jobs"`           |
| `JOBS_CONTROLLER` | `"AdminController"` |

If you do not have an `AdminController` defined in your project, the script will instead generate a `MissionControl::BaseController` for you with HTTP basic authentication enabled. This is simply to ensure that you cannot accidently expose the Mission Control dashboard to the public.

## Reporting issues

If you run into issues running the script, please [open an issue](https://github.com/fractaledmind/enlitenment/issues/new). When detailing your problem, please ensure that you provide the (relevant) contents of the following files as they were **before** you ran the script:

```
├── config
    ├── application.rb
    ├── database.yml
    ├── puma.rb
    └── routes.rb
```

Also, provide a git diff with the problematic diffs. This will allow us to not just improve the script, but write a regression test for this scenario so that the script never has your particular problem again.
