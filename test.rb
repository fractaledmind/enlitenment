require "pathname"
require "bundler"

Pathname("tests").children.select(&:directory?).each do |scenario|
  next if scenario.basename.to_s == "dummy"
  next unless scenario.basename.to_s == ENV["ONLY"] if ENV["ONLY"]

  Dir.chdir(scenario) do
    Bundler.with_unbundled_env do
      require "bundler/setup"
      load "test.rb"
    end
  end
end
