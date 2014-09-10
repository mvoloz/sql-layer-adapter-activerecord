## FoundationDB SQL Layer ActiveRecord Adapter

The [FoundationDB SQL Layer](https://foundationdb.com/layers/sql) is a
fault-tolerant and scalable open source RDBMS, best suited for applications
with high concurrency and short transactional workloads.

This project provides connection adapter integration for ActiveRecord.


### Supported SQL Layer Versions

Version 2.0.0 is the recommended release for use with this adapter.

Releases back to 1.9.3 are supported and any previous are unsupported.

### Supported ActiveRecord Versions

This project currently supports Rails 3.2, 4.0 and 4.1.


### Quick Start

> Important:
> 
> The [SQL Layer](https://foundationdb.com/layers/sql/) installed and running
> before attempting to use this adapter.
> 

1. Add to `Gemfile`
2. Install
3. Update configuration
4. Setup database

For a concrete example, we can easily use this adapter when following the
[Getting Started with Rails](http://guides.rubyonrails.org/v4.0.2/getting_started.html)
guide.

Follow the guide through Step 3.2 and then, before step 4, perform the steps below:

1. Add *one* the following lines to `Gemfile`:
    - Latest stable release:
        - `gem 'activerecord-fdbsql-adapter', '~> 1.2.0'`
    - Unreleased development version:
        - `gem 'activerecord-fdbsql-adapter', github: 'FoundationDB/sql-layer-adapter-activerecord'`
2. Install the new gem
    - `$ bundle install`
3. Edit `config/database.yml` to look like (adjust host as necessary):

    ```yaml
    development:
      adapter: fdbsql
      host: localhost
      database: blog_dev
   ```
4. Setup the database
    - `$ rake db:create`

Continue with the guide at Step 4.


### Migration Helpers

[Table Groups](https://foundationdb.com/layers/sql/GettingStarted/table.groups.html)
are a unique feature to the SQL Layer and can be managed with new
migration options and methods.

> Important:
> 
> Grouping is an adapter specific option and, as described in
> [Types of Schema Dumps](http://guides.rubyonrails.org/migrations.html#types-of-schema-dumps),
> will only be present in `:sql` type schema dumps.

The easiest way is to using the `grouping` option to `references`:

```ruby
class CreatePosts < ActiveRecord::Migration
  def up
    create_table :posts do |t|
      t.name :string
      t.references :user, grouping: true
    end
  end

  def down
    drop_table :posts
  end
end
```

The option is also available during `change_table`:

```ruby
class GroupPostsToUsers < ActiveRecord::Migration
  def up
    change_table :posts do |t|
      t.references :user, grouping: true
    end
  end

  def down
    change_table :posts do |t|
      t.remove_references :user
    end
  end
end
```

If the table already has the reference, `add_grouping` alone can be used:

```ruby
class GroupPostsToUsers < ActiveRecord::Migration
  def up
    change_table :posts do |t|
      t.add_grouping :user
    end
  end

  def down
    change_table :posts do |t|
      t.remove_grouping :user
    end
  end
end
```

Lastly, a global helper is also available:

```ruby
class GroupPostsToUsers < ActiveRecord::Migration
  def up
    add_grouping :posts, :user
  end

  def down
    remove_grouping :posts, :user
  end
end
```


### Contributing

1. Fork
2. Branch
3. Commit
4. Pull Request

If you would like to contribute a feature or fix, thanks! Please make
sure any changes come with new tests to ensure acceptance. Please read
the `test/RUNNING_UNIT_TESTS.md` file for more details.

### Contact

* GitHub: http://github.com/FoundationDB/sql-layer-adapter-activerecord
* Community: http://community.foundationdb.com
* IRC: #FoundationDB on irc.freenode.net

### License

The MIT License (MIT)  
Copyright (c) 2013-2014 FoundationDB, LLC  
It is free software and may be redistributed under the terms specified
in the LICENSE file.

