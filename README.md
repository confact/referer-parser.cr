# referer-parser

An crystal implementation of [referer-parser](https://github.com/snowplow/referer-parser), an library for extracting search marketing data from  referer (sic) URL.

This one is huge inspired and borrowed code from the ruby implementation: https://github.com/snowplow-referer-parser/ruby-referer-parser

This one only support YAML for now.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     referer-parser:
       github: confact/referer-parser
   ```

2. Run `shards install`

## Usage

```crystal
require "referer-parser"
```

### Use parser

create an instance of the parser:

```crystal
parser = RefererParser::Parser.new
```

And then you can start parsing the urls like this:

```
parser.parse('http://www.google.com/search?q=gateway+oracle+cards+denise+linn&hl=en&client=safari')
  # => {
    :known=>true,
    :uri=>"http://www.google.com/search?q=gateway+oracle+cards+denise+linn&hl=en&client=safari",
    :source=>"Google",
    :medium=>"search",
  }
```

## What is left
Right now this implementation don't return:
1. parameters
2. terms

We also don't support the JSON of the data file snowplow is giving away.

## Development

```
shards install
```
You can then add require on an test file or use the specs for test functionality.

You run the tests like this:
```
crystal spec
```

## Contributing

1. Fork it (<https://github.com/confact/referer-parser/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Håkan Nylén](https://github.com/confact) - creator and maintainer
