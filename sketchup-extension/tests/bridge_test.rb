require 'minitest/autorun'
require 'tmpdir'
require_relative '../woodworking_ai/server'
module UI
  def self.start_timer(*args, &block); 1; end
  def self.stop_timer(id); end
end
class BridgeTest < Minitest::Test
  def response(server, client)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    data = ''.b
    until data.include?("\n")
      server.tick
      chunk = client.read_nonblock(8192, exception: false)
      data << chunk if chunk.is_a?(String)
      raise 'Timed out waiting for test response' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.001 unless data.include?("\n")
    end
    JSON.parse(data)
  end
  def request(command = 'sketchup_status', params = {})
    {'request_id' => 'test-1', 'command' => command, 'params' => params}
  end
  def test_rejects_execution_and_unknown_fields
    ['eval_ruby', 'send', 'system'].each do |command|
      assert_raises(ArgumentError) { WoodworkingAI::CommandRouter.validate(request(command)) }
    end
    assert_raises(ArgumentError) { WoodworkingAI::CommandRouter.validate(request.merge('token' => 'secret')) }
  end
  def test_board_validation
    params = {'project_id'=>'test', 'id'=>'top', 'name'=>'Top', 'length'=>48,
      'width'=>18, 'thickness'=>1, 'position'=>{'x'=>0,'y'=>0,'z'=>0}}
    assert WoodworkingAI::CommandRouter.validate(request('create_board', params))
    [nil, '48', 0, -1, Float::INFINITY].each do |bad|
      assert_raises(ArgumentError) { WoodworkingAI::CommandRouter.validate(request('create_board', params.merge('length'=>bad))) }
    end
    assert_raises(ArgumentError) do
      WoodworkingAI::CommandRouter.validate(request('create_board', params.merge('position'=>{'x'=>0})))
    end
  end
  def test_socket_fragmentation_errors_limits_and_main_thread
    Dir.mktmpdir do |dir|
      calls = []
      router = Object.new
      router.define_singleton_method(:call) do |req|
        calls << Thread.current
        {request_id: req['request_id'], success: true, result: {connected: true}}
      end
      server = WoodworkingAI::BridgeServer.new(port: 0, router: router, log_path: File.join(dir, 'bridge.jsonl'))
      server.start
      client = TCPSocket.new('127.0.0.1', server.port)
      assert_equal '127.0.0.1', client.peeraddr[3]
      client.write('{"request_id":"test-1",')
      3.times { server.tick }
      assert_empty calls
      client.write('"command":"sketchup_status","params":{}}' + "\n")
      assert response(server, client)['success']
      assert_equal [Thread.current], calls
      assert_equal 'sketchup_status', JSON.parse(File.read(File.join(dir, 'bridge.jsonl')))['command']
      client.close
      client = TCPSocket.new('127.0.0.1', server.port)
      client.write("bad json\n")
      assert_equal 'INVALID_JSON', response(server, client)['error']['code']
      client.close
      client = TCPSocket.new('127.0.0.1', server.port)
      client.write('x' * 65_537)
      assert_equal 'TOO_LARGE', response(server, client)['error']['code']
      assert_equal 1, calls.size
      client.close
      other_thread_error = Thread.new do
        begin
          server.tick
        rescue StandardError => e
          e.message
        end
      end.value
      assert_match(/main thread/, other_thread_error)
    ensure
      client.close if client && !client.closed?
      server.stop if server
    end
  end
end
