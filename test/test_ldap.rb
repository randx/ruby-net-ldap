require 'test_helper'

class TestLDAPInstrumentation < Test::Unit::TestCase
  def setup
    @connection = flexmock(:connection, :close => true)
    flexmock(Net::LDAP::Connection).should_receive(:new).and_return(@connection)

    @service = MockInstrumentationService.new
    @subject = Net::LDAP.new \
      :host => "test.mocked.com", :port => 636,
      :force_no_page => true, # so server capabilities are not queried
      :instrumentation_service => @service
  end

  def test_instrument_bind
    events = @service.subscribe "bind.net_ldap"

    bind_result = flexmock(:bind_result, :success? => true)
    flexmock(@connection).should_receive(:bind).with(Hash).and_return(bind_result)

    assert @subject.bind

    payload, result = events.pop
    assert result
    assert_equal bind_result, payload[:bind]
  end

  def test_instrument_search
    events = @service.subscribe "search.net_ldap"

    flexmock(@connection).should_receive(:bind).and_return(flexmock(:bind_result, :result_code => 0))
    flexmock(@connection).should_receive(:search).with(Hash, Proc).
                yields(entry = Net::LDAP::Entry.new("uid=user1,ou=users,dc=example,dc=com")).
                and_return(flexmock(:search_result, :success? => true, :result_code => 0))

    refute_nil @subject.search(:filter => "(uid=user1)")

    payload, result = events.pop
    assert_equal [entry], result
    assert_equal [entry], payload[:result]
    assert_equal "(uid=user1)", payload[:filter]
  end
end
