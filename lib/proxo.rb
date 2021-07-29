# frozen_string_literal: true

require "socket"
require "logger"

require_relative "proxo/version"

module Proxo
  class Error < StandardError; end
  # Your code goes here...

  class Proxomaton
    VALID_LOG_LEVELS = %i[unknown fatal error warn info].freeze

    attr_reader(*%i[
                  input_host
                  input_port
                  output_host
                  output_port
                  logger
                  outbound_middleman
                  inbound_middleman
                ])

    def initialize(input_port:, input_host: "127.0.0.1", output_host: nil, output_port: nil, verbose: false, logger: nil)
      # The host to listen to
      @input_host = input_host

      # The port to listen on
      @input_port = input_port.to_i

      # The host to publish to
      @output_host = output_host || input_host

      # The port to publish to (`nil` if you don't want to republish)
      @output_port = output_port.to_i unless output_port.nil?

      # Print all received data before running middleman, and some other info
      @verbose = !!verbose

      # Logger for printing (defaults to STDOUT)
      @logger = logger || Logger.new(STDOUT)
      @logger.level = Logger::INFO

      # If no middlemen are given, it'll just pass the data through unmodified
      @outbound_middleman = proc(&:itself)
      @inbound_middleman = proc(&:itself)
    end

    # The given block will be called when data is received from the "input"
    # socket. The block takes one argument: the data received.
    def on_the_way_there(&block)
      @outbound_middleman = block
    end

    # The given block will be called when data is received back from the
    # "output" socket. The block takes one argument: the data received.
    def on_the_way_back(&block)
      @inbound_middleman = block
    end

    def start!
      Thread.abort_on_exception = true

      input_server = TCPServer.new(input_host, input_port)

      loop do
        Thread.start(input_server.accept) do |input_socket|
          output_socket = TCPSocket.new(output_host, output_port)

          loop do
            # Waiting for sockets to be ready...
            ready_sockets, * = IO.select([input_socket, output_socket], nil, nil)

            if ready_sockets && ready_sockets.include?(input_socket)
              # Waiting for output to be writable...
              _, write_sockets, * = IO.select(nil, [output_socket], nil, 0)

              if write_sockets && write_sockets.include?(output_socket)
                # Receiving data from input port...
                data = input_socket.gets
                break if data.nil?

                log("Received data from input port: #{data.chomp}")
                new_data = outbound_middleman.call(data)
                log("Writing transformed data to output port: #{new_data.chomp}")
                output_socket.write(new_data)
              end
            end

            next unless ready_sockets && ready_sockets.include?(output_socket)

            # Waiting for input to be writable...
            _, write_sockets, * = IO.select(nil, [input_socket], nil, 0)

            next unless write_sockets && write_sockets.include?(input_socket)

            # Receiving data from output port...
            data = output_socket.gets
            break if data.nil?

            log("Received data from output port: #{data.chomp}")
            new_data = inbound_middleman.call(data)
            log("Writing transformed data to input port: #{new_data.chomp}")
            input_socket.write(new_data)
          end

          input_socket.close
          output_socket.close
        end
      end
    end

    private

    def verbose?
      @verbose
    end

    def should_republish?
      !output_port.nil?
    end

    def log(message, level: :info)
      return unless verbose?

      log_level = level.to_s.downcase.to_sym

      unless VALID_LOG_LEVELS.include?(level.to_sym)
        raise ArgumentError,
              "Invalid log level '#{level}'. Valid levels are #{listify(VALID_LOG_LEVELS, connect: "or")}"
      end

      logger.public_send(level, message)
    end

    def listify(raw_list, connect: "and")
      list = raw_list.reduce([]) do |memo, item|
        item_string = item.to_s.strip
        item_string.empty? ? memo : [*memo, item]
      end

      return "" if list.empty?
      return list.first if list.count == 1
      return list.join(connect) if list.count == 2

      *first_items, last_item = list
      "#{first_items.join(",")}, #{connect} #{last_item}"
    end
  end
end
