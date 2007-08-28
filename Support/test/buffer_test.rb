require 'test_helper'

require 'text_mate_mock'
require 'rails/buffer'

TextMate.line_number = '1'
TextMate.column_number = '1'
TextMate.selected_text = <<-END
def my_method
  puts 'hi'
  # some comment, 'hi'
end

def my_other_method
  # another comment
end
END

class BufferTest < Test::Unit::TestCase
  def test_find
    b = Buffer.new(TextMate.selected_text)
    match = b.find { /'(.+)'/ }
    assert_equal ["hi", 1], match

    match = b.find(:from => 2, :to => 1, :direction => :backwards) { /'(.+)'/ }
    assert_equal ["hi", 2], match

    match = b.find(:from => 2, :to => 1, :direction => :backwards) { /my_method/ }
    assert_nil match
  end
  
  def test_find_method
    b = Buffer.new(TextMate.selected_text)
    match = b.find { /def\s+my_(.+)\W/ }
    assert_equal ['method', 0], match
    
    b.line_number = 4
    match = b.find(:direction => :backwards) { /def\s+my_(.+)\W/ }
    assert_equal ['method', 0], match

    b.line_number = 5
    match = b.find(:direction => :backwards) { /def\s+my_(.+)\W/ }
    assert_equal ['other_method', 5], match
  end
  
  def test_find_nearest_string_or_symbol
    b = Buffer.new "String :with => 'strings', :and, :symbols"
    match = b.find_nearest_string_or_symbol
    assert_equal ["with", 8], match
    
    b.column_number = 8
    match = b.find_nearest_string_or_symbol
    assert_equal ["with", 8], match

    b.column_number = 25
    match = b.find_nearest_string_or_symbol
    assert_equal ["strings", 17], match

    b.column_number = 37
    match = b.find_nearest_string_or_symbol
    assert_equal ["symbols", 34], match
    
    b = Buffer.new "String without symbols or strings"
    match = b.find_nearest_string_or_symbol
    assert_nil match
  end
end