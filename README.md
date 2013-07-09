Slugalicious -- Easy and powerful URL slugging for Rails 4
==========================================================

_(no monkey-patching required)_

|             |                                 |
|:------------|:--------------------------------|
| **Author**  | Tim Morgan                      |
| **Version** | 2.1 (Jul 9, 2013)               |
| **License** | Released under the MIT license. |

### Note about version 2.0

Version 2.0 is so-versioned because it breaks the API for previous versions.
Previously, where you would have used
{Slugalicious::ClassMethods#find_from_slug find_from_slug}, you would now use
{Slugalicious::ClassMethods#find_from_slug! find_from_slug!}. The old method now
returns `nil` when an object is not found, rather than raising an exception.

About
-----

Slugalicious is an easy-to-use slugging library that helps you generate pretty
URLs for your ActiveRecord objects. It's built for Rails 4 and is cordoned off
in a monkey patching-free zone.

Slugalicious is easy to use and powerful enough to cover all of the most common
use-cases for slugging. Slugs are stored in a separate table, meaning you don't
have to make schema changes to your models, and you can change slugs while still
keeping the old URLs around for redirecting purposes.

Slugalicious is an intelligent slug generator: You can specify multiple ways to
generate slugs, and Slugalicious will try them all until it finds one that
generates a unique slug. If all else fails, Slugalicious will fall back on a
less pretty but guaranteed-unique backup slug generation strategy.

Slugalicious works with the Stringex Ruby library, meaning you get meaningful
slugs via the `String#to_url` method. Below are two examples of how powerful
Stringex is:

```` ruby
"$6 Dollar Burger".to_url #=> "six-dollar-burger"
"新年好".to_url #=> "xin-nian-hao"
````

Installation
------------

*Important Note:* Slugalicious is written for Rails 4.0 and Ruby 1.9 only.

Firstly, add the gem to your Rails project's `Gemfile`:

```` ruby
gem 'slugalicious'
````

Next, use the generator to add the `Slug` model and its migration to your
project:

```` sh
rails generate slugalicious
````

Then run the migration to set up your database.

Usage
-----

For any model you want to slug, include the `Slugalicious` module and call
`slugged`:

```` ruby
class User < ActiveRecord::Base
  include Slugalicious
  slugged ->(user) { "#{user.first_name} #{user.last_name}" }
end
````

Doing this sets the `to_param` method, so you can go ahead and start generating
URLs using your models. You can use the `find_from_slug` method to load a record
from a slug:

```` ruby
user = User.find_from_slug(params[:id])
````

### Multiple slug generators

The `slugged` method takes a list of method names (as symbols) or `Procs` that
each attempt to generate a slug. Each of these generators is tried in order
until a unique slug is generated. (The output of each of these generators is run
through the slugifier to convert it to a URL-safe string. The slugifier is by
default `String#to_url`, provided by the Stringex gem.)

So, if we had our `User` class, and we first wanted to slug by last name only,
but then add in the first name if two people share a last name, we'd call
`slugged` like so:

```` ruby
slugged :last_name, ->(user) { "#{user.first_name} #{user.last_name}" }
````

In the event that none of these generators manages to make a unique slug, a
fallback generator is used. This generator prepends the ID of the record, making
it guaranteed unique. Let's use the example generators shown above. If we create
a user with the name "Sancho Sample", he will get the slug "sample". Create
another user with the same name, and that user will get the slug
"sancho-sample;2". The semicolon is the default ID separator (and it can be
overridden).

### Scoped slugs

Slugs must normally be unique for a single model type. Thus, if you have a
`User` named Hammer and a `Product` named hammer, they can both share the
"hammer" slug.

If you want to decrease the uniqueness scope of a slug, you can do so with the
`:scope` option on the `slugged` method. Let's say you wanted to limit the scope
of a `Product`'s slug to its associated `Department`; that way you could have a
product named "keyboard" in both the Computer Supplies and the Music Supplies
departments. To do so, override the `:scope` option with a method name (as
symbol) or a `Proc` that limits the scope of the uniqueness requirement:

```` ruby
class Product < ActiveRecord::Base
  include Slugalicious
  belongs_to :department
  slugged :name, scope: :department_url_component

  private

  def department_url_component
    department.name.to_url + "/"
  end
end
````

Now, your computer keyboard's slug will be "computer-supplies/keyboard" and your
piano keyboard's slug will be "music-supplies/keyboard". There's an important
thing to notice here: The method or proc you use to scope the slug must return a
proper URL substring. That typically means you need to URL-escape it and add a
slash at the end, as shown in the example above.

When you call `to_param` on your piano keyboard, instead of just "keyboard", you
will get "music-supplies/keyboard". Likewise, you can use the
`find_from_slug_path` method to find a record from its full path, slug and scope
included. You would usually use this method in conjunction with route globbing.
For example, we could set up our `routes.rb` file like so:

```` ruby
get '/products/*path', 'products#show', as: :products
````

Then, in our `ProductsController`, we load the product from the path slug like
so:

```` ruby
def find_product
  @product = Product.find_from_slug_path(params[:path])
end
````

This is why it's very convenient to have your `:scope` method/proc not only
return the uniqueness constraint, but also the scoped portion of the URL
preceding the slug.

### Altering and expiring slugs

When a model is created, it gets one slug, marked as the active slug (by
default). This slug is the first generator that produces a unique slug string.

If a model is updated, its slug is regenerated. Each of the slug generators is
invoked, and if any of them produces an existing slug assigned to the object,
that slug is made the active slug. (Priority goes to the first slug generator
that produces an existing slug [active or inactive]).

If none of the slug generators generates a known, existing slug belonging to the
object, then the first unique slug is used. A new `Slug` instance is created and
marked as active, and any other slugs belonging to the object are marked as
inactive.

Inactive slugs do not act any differently from active slugs. An object can be
found by its inactive slug just as well as its active slug. The flag is there so
you can alter the behavior of your application depending on whether the slug is
current.

A common application of this is to have inactive slugs 301-redirect to the
active slug, as a way of both updating search engines' indexes and ensuring that
people know the URL has changed. As an example of how do this, we alter the
`find_product` method shown above to be like so:

```` ruby
def find_product
  @product = Product.find_from_slug_path(params[:path])
  unless @product.active_slug?(params[:path].split('/').last)
    redirect_to product_url(@product), status: :moved_permanently
    return false
  end
  return true
end
````

The old URL will remain indefinitely, but users who hit it will be redirected to
the new URL. Ideally, links to the old URL will be replaced over time with links
to the new URL.

The problem is that even though the old slug is inactive, it's still "taken." If
you create a product called "Keyboard", but then rename it to "Piano", the
product will claim both the "keyboard" and "piano" slugs. If you had renamed it
to make room for a different product called "Keyboard" (like a computer
keyboard), you'd find its slug is "keyboard;2" or similar.

To prevent the slug namespace from becoming more and more polluted over time,
websites generally expire inactive slugs after a period of time. To do this in
Slugalicious, write a task that periodically checks for and deletes old,
inactive `Slug` records. Such a task could be invoked through a cron job, for
instance. An example:

```` ruby
Slug.inactive.where([ "created_at < ?", 30.days.ago ]).delete_all
````
