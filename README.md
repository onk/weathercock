# Weathercock

Hit counter and popularity tracking using Valkey/Redis Sorted Sets.

Records hit counts for arbitrary resources across hourly, daily, and monthly time windows. Aggregates them with `ZUNIONSTORE` to build popularity rankings.

## Installation

```bash
bundle add weathercock
```

## Usage

### Configuration

```ruby
Weathercock.configure do |c|
  c.redis     = RedisClient.new(host: "localhost", port: 6379)
  c.namespace = "myapp"  # default: "weathercock"
end
```

### Tracking

Include `Weathercock::Scorable` in any class that has an `id`:

```ruby
class Article
  include Weathercock::Scorable
end
```

Record a hit:

```ruby
article.hit(:views)
article.hit(:views, increment: 5)
```

Each call writes to three Sorted Sets:

```
myapp:article:views:2026-04-15-09   # hourly
myapp:article:views:2026-04-15      # daily
myapp:article:views:2026-04         # monthly
```

### Ranking

`top` aggregates time-window Sorted Sets via `ZUNIONSTORE` and returns IDs ordered by total score.

```ruby
# Top article IDs by views over the last 7 days
# Runs ZUNIONSTORE over 7 daily Sorted Sets
Article.top(:views, days: 7)
# => ["42", "7", "133", ...]

# Using hours or months
Article.top(:views, hours: 24)
Article.top(:views, months: 3)

# Exponential time decay (recent hits weighted higher)
Article.top(:views, days: 7, decay_factor: 0.9)
```

### Counting

Get the total hit count for a single instance over a time window:

```ruby
article.hit_count(:views, days: 7)
# => 42
```

Get hit counts for multiple instances at once (useful for list views):

```ruby
Article.hit_counts(:views, ids: [1, 2, 3], days: 7)
# => {"1" => 42, "2" => 15, "3" => 7}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/weathercock.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
