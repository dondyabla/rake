#!/usr/bin/env ruby

require 'test/unit'
require 'fileutils'
require 'rake'
require 'test/filecreation'

######################################################################
class TestRules < Test::Unit::TestCase
  include FileCreation

  SRCFILE  = "testdata/abc.c"
  SRCFILE2 =  "testdata/xyz.c"
  FTNFILE  = "testdata/abc.f"
  OBJFILE  = "testdata/abc.o"

  def setup
    Task.clear
    @runs = []
  end

  def teardown
    FileList['testdata/*'].each do |f| rm_r(f, :verbose=>false) end
  end

  def test_multiple_rules1
    create_file(FTNFILE)
    delete_file(SRCFILE)
    delete_file(OBJFILE)
    rule(/\.o$/ => ['.c']) do @runs << :C end
    rule(/\.o$/ => ['.f']) do @runs << :F end
    t = Task[OBJFILE]
    t.invoke
    Task[OBJFILE].invoke
    assert_equal [:F], @runs
  end

  def test_multiple_rules2
    create_file(FTNFILE)
    delete_file(SRCFILE)
    delete_file(OBJFILE)
    rule(/\.o$/ => ['.f']) do @runs << :F end
    rule(/\.o$/ => ['.c']) do @runs << :C end
    Task[OBJFILE].invoke
    assert_equal [:F], @runs
  end

  def test_create_with_source
    create_file(SRCFILE)
    rule(/\.o$/ => ['.c']) do |t|
      @runs << t.name
      assert_equal OBJFILE, t.name
      assert_equal SRCFILE, t.source
    end
    Task[OBJFILE].invoke
    assert_equal [OBJFILE], @runs
  end

  def test_single_dependent
    create_file(SRCFILE)
    rule(/\.o$/ => '.c') do |t|
      @runs << t.name
    end
    Task[OBJFILE].invoke
    assert_equal [OBJFILE], @runs
  end

  def test_create_by_string
    create_file(SRCFILE)
    rule '.o' => ['.c'] do |t|
      @runs << t.name
    end
    Task[OBJFILE].invoke
    assert_equal [OBJFILE], @runs
  end

  def test_rule_and_no_action_task
    create_file(SRCFILE)
    create_file(SRCFILE2)
    delete_file(OBJFILE)
    rule '.o' => '.c' do |t|
      @runs << t.source
    end
    file OBJFILE => [SRCFILE2]
    Task[OBJFILE].invoke
    assert_equal [SRCFILE], @runs
  end

  def test_string_close_matches
    create_file("testdata/x.c")
    rule '.o' => ['.c'] do |t|
      @runs << t.name
    end
    assert_raises(RuntimeError) { Task['testdata/x.obj'].invoke }
    assert_raises(RuntimeError) { Task['testdata/x.xyo'].invoke }
  end

  def test_precedence_rule_vs_implicit
    create_timed_files(OBJFILE, SRCFILE)
    rule(/\.o$/ => ['.c']) do
      @runs << :RULE
    end
    Task[OBJFILE].invoke
    assert_equal [:RULE], @runs
  end

  def test_too_many_dependents
    assert_raises(RuntimeError) { rule '.o' => ['.c', '.cpp'] }
  end

  def test_proc_dependent
    ran = false
    File.makedirs("testdata/src/jw")
    create_file("testdata/src/jw/X.java")
    rule %r(classes/.*\.class) => [
      proc { |fn| fn.sub(/^classes/, 'testdata/src').sub(/\.class$/, '.java') }
    ] do |task|
      assert_equal task.name, 'classes/jw/X.class'
      assert_equal task.source, 'testdata/src/jw/X.java'
      ran = true
    end
    Task['classes/jw/X.class'].invoke
    assert ran, "Should have triggered rule"
  ensure
    rm_r("testdata/src", :verbose=>false) rescue nil
  end

  def test_recursive_rules
    actions = []
    create_file("testdata/abc.xml")
    rule '.y' => '.xml' do actions << 'y' end
    rule '.c' => '.y' do actions << 'c'end
    rule '.o' => '.c' do actions << 'o'end
    rule '.exe' => '.o' do actions << 'exe'end
    Task["testdata/abc.exe"].invoke
    assert_equal ['y', 'c', 'o', 'exe'], actions
  end

  def test_recursive_overflow
    create_file("testdata/a.a")
    prev = 'a'
    ('b'..'z').each do |letter|
      rule ".#{letter}" => ".#{prev}" do |t| puts "#{t.name}" end
      prev = letter
    end
    ex = assert_raises(Rake::RuleRecursionOverflowError) {
      Task["testdata/a.z"].invoke
    }
    assert_match(/a\.z => testdata\/a.y/, ex.message)
  end

end
