# frozen_string_literal: true

require 'spec_helper'

describe Que::ConnectionPool do
  let :pool do
    QUE_POOL
  end

  describe ".checkout" do
    it "should yield a connection" do
      pool.checkout do |conn|
        assert_instance_of PG::Connection, conn
      end
    end

    # This will matter when we iterate over these specs for different adapters.
    it "should be reentrant" do
      id1 = id2 = nil

      pool.checkout do |c1|
        pool.checkout do |c2|
          id1 = c1.object_id
          id2 = c2.object_id
        end
      end

      refute_nil id1
      refute_nil id2
      assert_equal id1, id2
    end
  end

  describe ".in_transaction?" do
    it "should know when it is in a transaction" do
      pool.checkout do |c|
        refute pool.in_transaction?
        c.async_exec "BEGIN"
        assert pool.in_transaction?
        c.async_exec "COMMIT"
        refute pool.in_transaction?
      end
    end
  end

  describe ".execute" do
    it "should cast JSON params correctly"

    it "should cast timestamp params correctly" do
      [
        Time.now.localtime,
        Time.now.utc,
      ].each do |t|
        # Round to the nearest microsecond, because Postgres doesn't get any
        # more accurate than that anyway. We could use Time.at(t.to_i, t.usec),
        # but that would lose timezone data :/

        time = Time.iso8601(t.iso8601(6))
        r = pool.execute("SELECT $1::timestamptz AS time", [time])
        assert_equal({time: time}, r.first)
      end
    end

    it "should typecast the results of the SQL statement" do
      result =
        pool.execute <<-SQL
          SELECT
            1                                   AS integer_value,
            1::bigint                           AS bigint_value,
            1::smallint                         AS smallint_value,
            'string'                            AS string_value,
            '2017-06-30T23:29:32Z'::timestamptz AS timestamp_value,
            2 + 2 = 4                           AS boolean_value,
            '{"key":"value"}'::json             AS json_value,
            '{"key":"value"}'::jsonb            AS jsonb_value
        SQL

      assert_equal(
        {
          integer_value: 1,
          bigint_value: 1,
          smallint_value: 1,
          string_value: 'string',
          timestamp_value: Time.iso8601('2017-06-30T23:29:32Z'),
          boolean_value: true,
          json_value: {key: 'value'},
          jsonb_value: {key: 'value'},
        },
        result.first,
      )
    end

    it "should typecast timestamps regardless of the output format"

    it "should reuse the same connection when inside a checkout block" do
      pool.checkout do
        assert_equal(
          pool.execute("SELECT pg_backend_pid()"),
          pool.execute("SELECT pg_backend_pid()"),
        )
      end
    end
  end
end