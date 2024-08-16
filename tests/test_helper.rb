# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "rails/generators/rails/app/app_generator"
require "minitest/autorun"
require "fileutils"

class DummyApp
  def initialize(root)
    @root = root
    @paths = {}
  end

  def expand(path)
    @paths[path] ||= File.join(@root, path)
  end

  def write(path, contents, mode = "w")
    file_name = expand(path)
    FileUtils.mkdir_p File.dirname(file_name)
    File.open(file_name, mode) do |f|
      f.puts contents
    end
    file_name
  end

  def read(path)
    File.read(expand(path))
  end

  def exist?(path)
    File.exist?(expand(path))
  end
end

class TestCase < Minitest::Test
  def app()
    @app ||= DummyApp.new(@app_path)
  end

  private

    def apply_rails_template(template = template_path)
      generator = Rails::Generators::AppGenerator.new [@app_path], {}, { destination_root: @app_path }
      generator.source_paths << @app_path
      generator.apply template, verbose: true
    end

    def build_app
      FileUtils.mkdir_p @app_path
      source_folder = File.join(__dir__, "dummy")
      FileUtils.cp_r(Dir["#{source_folder}/*"], @app_path)
    end

    def template_path
      @template_path ||= File.join(File.expand_path("."), "template.rb")
    end

    def fake_lockfile!
      head = <<~TXT
        GEM
          remote: https://rubygems.org/
          specs:
      TXT
      gemfile = app.read("Gemfile")
      specs = gemfile.scan(/gem "(.*?)"/).map {|(it)| "    " + it}.join("\n")
      app.write("Gemfile.lock", head + specs)
    end

    def re(string)
      Regexp.new(Regexp.escape(string))
    end

    def create_app_dir
      FileUtils.mkdir_p @app_path
    end

    def remove_app_dir
      FileUtils.rm_rf @app_path
    end
end
