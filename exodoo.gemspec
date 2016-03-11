# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "exodoo/version"

Gem::Specification.new do |s|
  s.name = "exodoo"
  s.version = Exodoo::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Rapha\u{eb}l Valyi"]
  s.date = "2016-02-29"
  s.summary = "Allows to expose Odoo entities in a LocomotiveCMS website"
  s.email = "rvalyi@akretion.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    "Gemfile",
    "LICENSE.txt",
    "README.md",
    "VERSION",
    "lib/exodoo.rb",
    "exodoo.gemspec"
  ]
  s.homepage = "http://github.com/akretion/exodoo"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"

  s.add_dependency(%q<erpify>, [">= 0"])
  s.add_dependency(%q<locomotivecms_steam>, [">= 0"])
  s.add_dependency(%q<rack-reverse-proxy>, [">=0"])
end

