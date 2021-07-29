# Proxo

Proxy one port to another port, and intercept/transform/log inbound and outbound TCP messages.

## Installation

### In your application

Add this line to your application's `Gemfile`:

```ruby
gem 'proxo'
```

And then execute:

```sh
bundle install
```

### Globally (to your system)

Or install it globally:

```sh
gem install proxo
```

## Usage

### On the command line

#### Option flags

```
> proxo --help
Usage: proxo [options]
    -h, --help                       Show this help message
    -v, --verbose                    Log all data received and republished, as well as lifecycle events
    -i, --input-host INPUT_HOST      Host to listen to (default: 127.0.0.1)
    -p, --input-port INPUT_PORT      Port to listen on (required)
    -o, --output-host OUTPUT_HOST    Host to republish to (default: 127.0.0.1)
    -q, --output-port OUTPUT_PORT    Port to republish to (will NOT republish if no output port is given)
    -l, --log LOG_FILE               File to log to (default: logs to STDOUT)
```

#### Common examples

Listen to all messages and activity sent to port 5000:

```bash
proxo --verbose --input-port 5000
```

Proxy messages from port 5000 to 8080, and log the contents of all messages and activity:

```bash
proxo --verbose --input-port 5000 --output-port 8080
```

### In an application

```rb
require "proxo"
require "json"
require "logger"

logger = Logger.new("log/log_file.log")
logger.level = Logger::INFO

proxy = Proxo::Proxomaton.new(
  input_port: 5000,
  output_port: 8080,
  verbose: true,
  logger: logger
)

proxy.on_the_way_there do |data|
  puts "I'm sending this data: #{data}."
  puts "I'm also throttling this request."
  sleep 0.5

  puts "I'm also remembering to return data to send to the output port."
  puts "If I didn't return any data, the output port wouldn't receive any."
  data
end

proxy.on_the_way_back do |data|
  puts "I'm adding an unexpected field to the data coming back from the"
  puts "application running on the output port."
  payload = JSON.parse(data)
  payload["foobar"] = "whoa"
  payload.to_json
end

proxy.start!
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kjleitz/proxo.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
