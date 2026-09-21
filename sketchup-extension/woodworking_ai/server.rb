# frozen_string_literal: true
require 'socket'
require 'json'
require 'time'
require 'fileutils'
require_relative 'command_router'
module WoodworkingAI
  # All I/O is nonblocking. UI.start_timer serializes dispatch on SketchUp's main thread.
  # Protocol: one newline-delimited JSON request/response per TCP connection, no HTTP.
  class BridgeServer
    PORT = 48_763
    MAX_BYTES = 65_536
    MAX_CLIENTS = 16
    def initialize(port: PORT, router: CommandRouter, log_path: nil)
      @port, @router = port, router
      @log_path = log_path || File.expand_path('../../logs/bridge.jsonl', File.dirname(File.realpath(__FILE__)))
      @clients = {}
    end

    def start
      return if @listener
      @owner = Thread.current
      @listener = TCPServer.new('127.0.0.1', @port)
      @timer = UI.start_timer(0.05, true) { tick }
      true
    rescue StandardError
      stop
      raise
    end

    def port
      @listener.addr[1]
    end

    def stop
      UI.stop_timer(@timer) if @timer
      @timer = nil
      @clients.each_key { |socket| socket.close rescue nil }
      @clients.clear
      @listener.close if @listener && !@listener.closed?
      @listener = nil
    end

    def tick
      raise 'Bridge must execute on its owning main thread' unless Thread.current == @owner
      return if @ticking || !@listener
      @ticking = true
      begin
        4.times do
          break if @clients.size >= MAX_CLIENTS
          socket = @listener.accept_nonblock(exception: false)
          break if socket == :wait_readable
          @clients[socket] = {input: ''.b, output: nil, started: monotonic}
        end
        @clients.keys.each { |socket| service(socket) }
      ensure
        @ticking = false
      end
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def close_client(socket)
      @clients.delete(socket)
      socket.close unless socket.closed?
    end

    def service(socket)
      state = @clients.fetch(socket)
      return close_client(socket) if monotonic - state[:started] > 10
      unless state[:output]
        chunk = socket.read_nonblock(8192, exception: false)
        return if chunk == :wait_readable
        return close_client(socket) if chunk.nil?
        state[:input] << chunk
        if state[:input].bytesize > MAX_BYTES
          state[:output] = JSON.generate(success: false, request_id: nil,
            error: {code: 'TOO_LARGE', message: 'Request exceeds 64 KiB'}) + "\n"
        elsif state[:input].include?("\n")
          state[:output] = process(state[:input].split("\n", 2).first)
        else
          return
        end
      end
      written = socket.write_nonblock(state[:output], exception: false)
      return if written == :wait_writable
      state[:output] = state[:output].byteslice(written..-1)
      close_client(socket) if state[:output].empty?
    rescue IOError, SystemCallError
      close_client(socket)
    end

    def process(line)
      started = monotonic
      request = JSON.parse(line)
      response = @router.call(request)
      # Only log validated requests: rejected unknown fields might contain secrets.
      begin
        CommandRouter.validate(request)
        record = {timestamp: Time.now.utc.iso8601, request_id: request['request_id'],
          command: request['command'], parameters: request['params'],
          duration_ms: ((monotonic - started) * 1000).round(2), result: response}
        FileUtils.mkdir_p(File.dirname(@log_path))
        File.open(@log_path, 'a', 0600) { |file| file.puts(JSON.generate(record)) }
      rescue ArgumentError
        # Invalid request content is deliberately excluded from logs.
      rescue StandardError => e
        warn "Woodworking AI log failure: #{e.class}"
      end
      JSON.generate(response) + "\n"
    rescue JSON::ParserError, EncodingError
      JSON.generate(request_id: nil, success: false,
        error: {code: 'INVALID_JSON', message: 'Expected one JSON object followed by newline'}) + "\n"
    end
  end

  def self.start_bridge
    @bridge ||= BridgeServer.new
    @bridge.start
    puts "Woodworking AI bridge listening on 127.0.0.1:#{@bridge.port}"
  end

  def self.stop_bridge
    @bridge.stop if @bridge
  end
end
