# FromJson

TODO: Write a gem description

## Requirements

ORMs:
- ActiveRecord

ODMs:
- Mongoid

## Installation

Add this line to your application's Gemfile:

    gem 'from_json'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install from_json

## Usage

To use `from_json`, FromJson needs basic information about your models to be available.

The minimum required method is:

```ruby
class MyModel < ActiveRecord::Base

  # unique_keys: Define whichever keys in your hash can be matched to existing records.
  def self.unique_keys
    ['id','post_slug'] 
  end

end
```

This would correspond to a model with two unique keys: `id` and `post_slug`, or a SQL table like this:

```sql
CREATE TABLE `posts` (id INTEGER, post_slug varchar(255));
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
