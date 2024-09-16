# En*lite*nment

`enlitenment` is a [Rails application template script](https://guides.rubyonrails.org/rails_application_templates.html) that will lead you along the path to SQLite on Rails enlightenment.

Achieving SQLite on Rails nirvana requires 4 critical pieces:

1. properly configured SQLite connections for [optimal performance](https://fractaledmind.github.io/2024/04/15/sqlite-on-rails-the-how-and-why-of-optimal-performance/)
2. properly configured [Solid Queue](https://github.com/rails/solid_queue) for background jobs
3. properly configured [Solid Cache](https://github.com/rails/solid_cache) for caching
4. properly configured [Solid Cable](https://github.com/rails/solid_cable) for web sockets
5. properly configured [Litestream](https://github.com/fractaledmind/litestream-ruby) for backups
6. properly configured [Solid Errors](https://github.com/fractaledmind/solid_errors) for error monitoring


The `enlitenment` script provides all 6 pieces, each carefully tuned to be production-ready.

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

### Configuration

Regardless of how you apply the template, you can also configure various details of how the script will upgrade your application via environment variables.

#### Global vs Production Installation

You can decide whether to install the gems into all environments or just the production environment by setting the `INSTALL_INTO` environment variable:

```
INSTALL_INTO = "production" | "application"
```

This determines whether configuration is written to the `config/application.rb` file or the `config/environments/production.rb` file as well as whether the databases are configured for all environments or just the production environment in `config/database.yml`.

#### Skipping Sections

You can skip certain sections of the script using the `SKIP_*` environment variables:

| Variable                | Default |
| :---                    | :---:   |
| `SKIP_SOLID_QUEUE`      | `false` |
| `SKIP_SOLID_CACHE`      | `false` |
| `SKIP_SOLID_CABLE`      | `false` |
| `SKIP_LITESTREAM`       | `false` |
| `SKIP_SOLID_ERRORS`     | `false` |

`SKIP_SOLID_QUEUE` will skip the entire process of installing and configuring [Solid Queue](https://github.com/rails/solid_queue). This process consists of 10 steps, which would all be skipped if you set this variable to `true`:

1. add the `solid_queue` gem to the Gemfile
2. install the gem
3. define a new database configuration
4. add the new database configuration to all environments
5. run the Solid Queue installation generator
6. run the migrations for the new database
7. configure the application to use Solid Queue in all environments with the new database
8. add the Solid Queue plugin to Puma
9. add the Solid Queue engine to the application
10. mount the Solid Queue engine

`SKIP_SOLID_CACHE` will skip the entire process of installing and configuring [Solid Cache](https://github.com/rails/solid_cache). This process consists of 9 steps, which would all be skipped if you set this variable to `true`:

1. add the `solid_cache` gem to the Gemfile
2. install the gem
3. define the new database configuration
4. add the new database configuration to all environments
5. run the Solid Cache installation generator
6. run the migrations for the new database
7. configure Solid Cache to use the new database
8. configure Solid Cache as the cache store
9. optionally enable the cache in development

`SKIP_SOLID_CABLE` will skip the entire process of installing and configuring [Solid Cable](https://github.com/rails/solid_cable). This process consists of 7 steps, which would all be skipped if you set this variable to `true`:

1. add the `solid_cable` gem to the Gemfile
2. install the gem
3. define the new database configuration
4. add the new database configuration to all environments
5. run the Solid Cable installation generator
6. run the migrations for the new database
7. configure Solid Cable to use the new database

`SKIP_LITESTREAM` will skip the entire process of installing and configuring [Litestream](https://github.com/fractaledmind/litestream-ruby). This process consists of 8 steps, which would all be skipped if you set this variable to `true`:

1. add the `litestream` gem
2. install the gem
3. run the Litestream installation generator
4. add the Litestream plugin to Puma
5. mount the Litestream engine
6. Secure the Litestream dashboard
7. Add a recurring task to verify Litestream backups
8. at the end of the Rails process, configure the Litestream engine

`SKIP_SOLID_ERRORS` will skip the entire process of installing and configuring [Solid Errors](https://github.com/fractaledmind/solid_errors). This process consists of 10 steps, which would all be skipped if you set this variable to `true`:

1. add the `solid_errors` gem to the Gemfile
2. install the gem
3. define the new database configuration
4. add the new database configuration to all environments
5. run the Solid Errors installation generator
6. prepare the new database
7. configure the application to use Solid Errors in all environments with the new database
8. configure Solid Errors to send emails when errors occur
9. mount the Solid Errors engine
10. secure the Solid Errors web dashboard

#### Skipping Steps

For some sections, there are also certain individual steps that can be skipped:

| Variable                | Default |
| :---                    | :---:   |
| `SKIP_DEV_CACHE`        | `false` |
| `SKIP_LITESTREAM_CREDS` | `false` |

`SKIP_DEV_CACHE` will skip the step of enabling the cache in development. This simply means that in step 8 of the Solid Cache configuration process, the `rails dev:cache` action will not be run. Similarly, `SKIP_LITESTREAM_CREDS` will simply skip step 5 of configuring Litestream and not uncomment the lines in the `config/intializers/litestream.rb` file. You will need to configure Litestream yourself by hand.

### Database Configuration

When installing and configuring Solid Queue and Solid Cache, `enlitenment` will use a separate SQLite database for each. You can define the names for the those databases using the `*_DB` environment variables:

| Variable    | Default    |
| :---        | :---:      |
| `QUEUE_DB`  | `"queue"`  |
| `CACHE_DB`  | `"cache"`  |
| `CABLE_DB`  | `"cable"`  |
| `ERRORS_DB` | `"errors"` |

These database names will be used in the `config/database.yml` file to define the new database configurations as well as in the Solid Queue/Cache/Cable/Errors configuration files to ensure that both gems understand that they are supposed to read and write from these separate SQLite databases.

### Web Dashboards

The script will also install and configure any related web dashboards for the components. Solid Queue uses the separate [Mission Control — Jobs](https://github.com/rails/mission_control-jobs) gem for its web dashboard, but Litestream and Solid Errors come with their own web dashboards. You can configure the route path that each will be mounted at via the `*_ROUTE` environment variables:

| Variable           | Default         |
| :---               | :---:           |
| `JOBS_ROUTE`       | `"/jobs"`       |
| `LITESTREAM_ROUTE` | `"/litestream"` |
| `ERRORS_ROUTE`     | `"/errors"`     |

It is important that each web dashboard has at least basic security measures in place. But the different components provide different ways to secure their web dashboards. For Solid Queue, the Mission Control — Jobs gem allows you to configure the controller that the gem inherits from. For Litestream and Solid Errors, you can set a password that will be required via basic HTTP authentication to access the web dashboards. For all three, however, you could simply secure the dashboards by updating the `config/routes.rb` file to restrict access to the web dashboards under a route constraint, like:

```ruby
authenticate :user, -> (user) { user.admin? } do
  mount SolidErrors::Engine, at: "/errors"
  mount Litestream::Engine, at: "/litestream"
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
```

But, to ensure that the generated code is secure by default, the script provides the following environment variables to control the basic security measures that the gems provide:

| Variable              | Default             |
| :---                  | :---:               |
| `JOBS_CONTROLLER`     | `"AdminController"` |
| `LITESTREAM_PASSWORD` | `"lite$tr3am"`      |
| `ERRORS_PASSWORD`     | `"3rr0r$"`          |

For the `JOBS_CONTROLLER` in particular, if you do not have an `AdminController` defined in your project, the script will instead generate a `MissionControl::BaseController` for you with HTTP basic authentication enabled. This is simply to ensure that you cannot accidently expose the Mission Control dashboard to the public.

## Solid Gems

If you want to confirm that the Solid gems have been installed and configured correctly, you can run the following commands in the Rails console and verify that the output matches the following:

```
> ActionCable.server.config.cable['adapter']
=> "solid_cable"
> Rails.application.config.cache_store
=> :solid_cache_store
> Rails.application.config.active_job.queue_adapter
=> :solid_queue
```

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
