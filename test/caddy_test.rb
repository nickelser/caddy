require "test_helper"

class CaddyTest < Minitest::Test
  def setup
    Caddy.stop
    Caddy.refresher = -> {}
    Caddy.refresh_interval = 30
    Caddy.error_handler = nil
  end

  def test_basic_lookup
    Caddy.refresher = -> { {foo: "bar"} }
    Caddy.start
    sleep(0.1)

    assert_equal "bar", Caddy[:foo]
  end

  def test_basic_interval_updating
    x = 0
    Caddy.refresher = lambda do
      x += 1
      {baz: x}
    end
    Caddy.refresh_interval = 2
    Caddy.start
    sleep(3)

    assert_operator Caddy[:baz], :>=, 2
  end

  def test_restart
    Caddy.refresher = -> { {foo: "baz"} }
    Caddy.start
    sleep(0.1)
    Caddy.stop
    Caddy.restart

    assert_equal "baz", Caddy[:foo]
  end

  def test_error_handling
    reported = nil
    Caddy.refresher = -> { raise "boom" }
    Caddy.error_handler = -> (ex) { reported = ex }
    Caddy.start
    sleep(0.1)

    assert_equal "boom", reported.message
  end

  def test_incepted_error_handling
    Caddy.refresher = -> { raise "boom" }
    Caddy.error_handler = -> (_) { raise "boomboom" }
    Caddy.start
  end

  def test_bad_error_handler
    Caddy.refresher = -> { raise "boom" }
    Caddy.error_handler = "no"
    Caddy.start
  end

  def test_timeout
    Caddy.refresher = -> { sleep 5 }
    Caddy.refresh_interval = 1
    Caddy.start
  end

  def test_no_handler
    Caddy.refresher = -> { raise "boom" }
    Caddy.start
  end

  def test_requires_refesher
    Caddy.refresher = nil

    assert_raises { Caddy.start }
  end

  def test_requires_positive_interval
    Caddy.refresh_interval = -2

    assert_raises { Caddy.start }
  end
end
