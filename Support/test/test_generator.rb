require File.dirname(__FILE__) + '/test_helper'

require 'text_mate_mock'
require "rails/rails_path"
require "rails/generate"

class TestBinGenerate < Test::Unit::TestCase
  def setup
    TextMate.project_directory = File.expand_path(File.dirname(__FILE__) + '/app_fixtures')
  end
  
  def test_known_generators
    expected = %w[scaffold controller model mailer migration plugin]
    actual = Generator.known_generators.map { |gen| gen.name }
    assert_equal(expected, actual)
  end

  def test_known_generators_in_final_list
    Generator.setup
    list = Generator.names
    expected = %w[scaffold controller model mailer migration plugin]
    expected.each { |try| assert(list.include?(try), "Missing generator '#{try}'") }
  end

  def test_find_generator_names
    Generator.setup
    list = Generator.names
    assert_equal(Array, list.class)
    list.each do |name|
      assert_equal(String, name.class)
      assert_no_match(/[ \t\n]/, name, "generator names should not contain spaces")
    end
  end

  def test_generators
    Generator.setup
    generators = Generator.generators
    assert(generators.length > 6, "There should be lots of generators.")
    assert_equal(Array, generators.class)
    generators.each do |gen|
      assert_equal(Generator, gen.class)
      assert_no_match(/[ \t\n]/, gen.name, "generator names should not contain spaces")
    end
  end
  
  def test_question
    model = Generator["model"]
    assert_equal("Usage: script/generate model ModelName [field:type, field:type]", model.question)
  end
end