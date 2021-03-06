require_relative '../test_helper'

class TestBEREncoding < Test::Unit::TestCase
  def test_empty_array
    assert_equal [], [].to_ber.read_ber
  end

  def test_array
    ary = [1,2,3]
    encoded_ary = ary.map { |el| el.to_ber }.to_ber

    assert_equal ary, encoded_ary.read_ber
  end

  def test_true
    assert_equal "\x01\x01\x01", true.to_ber
  end

  def test_false
    assert_equal "\x01\x01\x00", false.to_ber
  end

  # Sample based
  {
    0           => "\x02\x01\x00",
    1           => "\x02\x01\x01",
    127         => "\x02\x01\x7F",
    128         => "\x02\x01\x80",
    255         => "\x02\x01\xFF",
    256         => "\x02\x02\x01\x00",
    65535       => "\x02\x02\xFF\xFF",
    65536       => "\x02\x03\x01\x00\x00",
    16_777_215  => "\x02\x03\xFF\xFF\xFF",
    0x01000000  => "\x02\x04\x01\x00\x00\x00",
    0x3FFFFFFF  => "\x02\x04\x3F\xFF\xFF\xFF",
    0x4FFFFFFF  => "\x02\x04\x4F\xFF\xFF\xFF",

    # Some odd samples...
    5           => "\002\001\005",
    500         => "\002\002\001\364",
    50_000      => "\x02\x02\xC3P",
    5_000_000_000  => "\002\005\001*\005\362\000"
  }.each do |number, expected_encoding|
    define_method "test_encode_#{number}" do
      assert_equal expected_encoding.b, number.to_ber
    end
  end

  # Round-trip encoding: This is mostly to be sure to cover Bignums well.
  def test_powers_of_two
    100.times do |p|
      n = 2 << p

      assert_equal n, n.to_ber.read_ber
    end
  end

  def test_powers_of_ten
    100.times do |p|
      n = 5 * 10**p

      assert_equal n, n.to_ber.read_ber
    end
  end

  if "Ruby 1.9".respond_to?(:encoding)
    def test_encode_utf8_strings
      assert_equal "\x04\x02\xC3\xA5".b, "\u00e5".force_encoding("UTF-8").to_ber
    end

    def test_utf8_encodable_strings
      assert_equal "\x04\nteststring", "teststring".encode("US-ASCII").to_ber
    end

    def test_encode_binary_data
      # This is used for searching for GUIDs in Active Directory
      assert_equal "\x04\x10" + "j1\xB4\xA1*\xA2zA\xAC\xA9`?'\xDDQ\x16".b,
        ["6a31b4a12aa27a41aca9603f27dd5116"].pack("H*").to_ber_bin
    end

    def test_non_utf8_encodable_strings
      assert_equal "\x04\x01\x81".b, "\x81".to_ber
    end
  end
end

class TestBERDecoding < Test::Unit::TestCase
  def test_decode_number
    assert_equal 6, "\002\001\006".read_ber(Net::LDAP::AsnSyntax)
  end

  def test_decode_string
    assert_equal "testing", "\004\007testing".read_ber(Net::LDAP::AsnSyntax)
  end

  def test_decode_ldap_bind_request
    assert_equal [1, [3, "Administrator", "ad_is_bogus"]], "0$\002\001\001`\037\002\001\003\004\rAdministrator\200\vad_is_bogus".read_ber(Net::LDAP::AsnSyntax)
  end
end

class TestBERIdentifiedString < Test::Unit::TestCase
  def test_binary_data
    data = ["6a31b4a12aa27a41aca9603f27dd5116"].pack("H*").force_encoding("ASCII-8BIT")
    bis = Net::BER::BerIdentifiedString.new(data)

    assert bis.valid_encoding?, "should be a valid encoding"
    assert_equal "ASCII-8BIT", bis.encoding.name
  end

  def test_ascii_data_in_utf8
    data = "some text".force_encoding("UTF-8")
    bis = Net::BER::BerIdentifiedString.new(data)

    assert bis.valid_encoding?, "should be a valid encoding"
    assert_equal "UTF-8", bis.encoding.name
  end

  def test_ut8_data_in_utf8
    data = ["e4b8ad"].pack("H*").force_encoding("UTF-8")
    bis = Net::BER::BerIdentifiedString.new(data)

    assert bis.valid_encoding?, "should be a valid encoding"
    assert_equal "UTF-8", bis.encoding.name
  end
end
