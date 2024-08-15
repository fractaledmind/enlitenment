# En*lite*nment

`enlitenment` is a [Rails application template script](https://guides.rubyonrails.org/rails_application_templates.html) that will automatically upgrade your application to production-ready. It leads you along the path to SQLite on Rails enlightenment.

Achieving SQLite on Rails nirvana requires 4 critical pieces:

1. properly configured SQLite connections for [optimal performance](https://fractaledmind.github.io/2024/04/15/sqlite-on-rails-the-how-and-why-of-optimal-performance/)
2. properly configured [Solid Queue](https://github.com/rails/solid_queue) for background jobs
3. properly configured [Solid Cache](https://github.com/rails/solid_cache) for caching
4. properly configured [Litestream](https://github.com/fractaledmind/litestream-ruby) for backups

The `enlitenment` script provides all 4 pieces, each carefully tuned to be production-ready.

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

| Variable           | Default |
| :---               | :---:   |
| `SKIP_SOLID_QUEUE` | `false` |
| `SKIP_SOLID_CACHE` | `false` |
| `SKIP_LITESTREAM`  | `false` |

When installing and configuring Solid Queue and Solid Cache, `enlitenment` will use a separate SQLite database for each. You can define the names for the those databases using the `*_DB` environment variables:

| Variable   | Default   |
| :---       | :---:     |
| `QUEUE_DB` | `"queue"` |
| `CACHE_DB` | `"cache"` |

Finally, the script will also install the [Mission Control — Jobs](https://github.com/rails/mission_control-jobs) gem to provide a web UI for Solid Queue. You can configure the route path that it will be mounted at as well as the name of the controller it will inherit from (this is to ensure that this web dashboard is properly secured and not easily accessible to random visitors). You can configure these details using the `JOBS_*` environment variables:

| Variable          | Default             |
| :---              | :---:               |
| `JOBS_ROUTE`      | `"/jobs"`           |
| `JOBS_CONTROLLER` | `"AdminController"` |

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
