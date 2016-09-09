require "test_helper"

class CaddyTest < Minitest::Test
  def setup
    Caddy.stop
    Caddy.error_handler = nil

    [:test, :test_two].each do |k|
      Caddy[k].refresher = -> {}
      Caddy[k].refresh_interval = 30
      Caddy[k].error_handler = nil
    end

    sleep(0.05)
  end

  def test_basic_lookup
    Caddy[:test].refresher = -> { {foo: "bar"} }
    Caddy.start
    sleep(0.1)

    assert_equal "bar", Caddy[:test][:foo]
    assert_equal "bar", Caddy[:test].cache[:foo]
  end

  def test_basic_interval_updating
    x = 0
    Caddy[:test].refresher = lambda do
      x += 1
      {baz: x}
    end
    Caddy[:test].refresh_interval = 2
    Caddy.start
    sleep(3)

    assert_operator Caddy[:test][:baz], :>=, 2
  end

  def test_multiple_interval_updating
    x = 0
    y = 0
    Caddy[:test].refresher = lambda do
      x += 1
      {baz: x}
    end
    Caddy[:test].refresh_interval = 2
    Caddy[:test_two].refresher = lambda do
      y += 1
      {biz: y}
    end
    Caddy[:test_two].refresh_interval = 1
    Caddy.start
    sleep(4)

    assert_operator Caddy[:test][:baz], :>=, 2
    assert_operator Caddy[:test_two][:biz], :>=, 4
  end

  def test_stale_value
    ran_once = false
    Caddy[:test].refresher = lambda do
      raise "boom" if ran_once
      ran_once = true
      {baz: "bizz"}
    end
    Caddy[:test].refresh_interval = 2
    Caddy.start
    sleep(3)

    assert_equal "bizz", Caddy[:test][:baz]
  end

  def test_many_readers
    x = 0
    Caddy[:test].refresher = -> { {x: x += 1} }
    Caddy[:test].refresh_interval = 0.1
    Caddy.start
    sleep(0.1)

    Array.new(50) do
      Thread.new do
        200.times do
          x = Caddy[:test][:x]
          sleep(0.01)
          x = Caddy[:test][:x]
        end
      end
    end.each(&:join)
  end

  def test_restart
    Caddy[:test].refresher = -> { {foo: "baz"} }
    Caddy.start
    sleep(0.1)
    Caddy.stop
    Caddy.restart
    sleep(0.1)

    assert_equal "baz", Caddy[:test][:foo]
  end

  def test_global_error_handling
    reported = nil
    Caddy[:test].refresher = -> { raise "boom" }
    Caddy.error_handler = -> (ex) { reported = ex }
    Caddy.start
    sleep(0.1)

    assert_equal "boom", reported.message
  end

  def test_specific_error_handling
    reported = nil
    Caddy[:test].refresher = -> { raise "boom" }
    Caddy[:test].error_handler = -> (ex) { reported = ex }
    Caddy.start
    sleep(0.1)

    assert_equal "boom", reported.message
  end

  def test_incepted_error_handling
    Caddy[:test].refresher = -> { raise "boom" }
    Caddy.error_handler = -> (_) { raise "boomboom" }
    Caddy.start
    sleep(0.1)
  end

  def test_bad_error_handler
    Caddy[:test].refresher = -> { raise "boom" }
    Caddy.error_handler = "no"
    Caddy.start
    sleep(0.1)
  end

  def test_timeout
    timed_out = nil
    Caddy[:test].refresher = -> { sleep 1 }
    Caddy.error_handler = -> (ex) { timed_out = ex }
    Caddy[:test].refresh_interval = 0.5
    Caddy.start
    sleep(2)

    assert_kind_of Concurrent::TimeoutError, timed_out
    Caddy.stop
    sleep(2)
  end

  def test_no_handler_timeout
    Caddy[:test].refresher = -> { sleep 1 }
    Caddy[:test].refresh_interval = 0.5
    Caddy.start
    sleep(2)
    Caddy.stop
    sleep(2)
  end

  def test_no_handler
    Caddy[:test].refresher = -> { raise "boom" }
    Caddy.start
    sleep(0.1)
  end

  def test_requires_refesher
    Caddy[:test].refresher = nil

    assert_raises { Caddy.start }
  end

  def test_requires_positive_interval
    Caddy[:test].refresh_interval = -2

    assert_raises { Caddy.start }
  end
end
