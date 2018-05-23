# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'

module Helper
  # Adding some prefixes for VIAF export
  def add_id_prefix  
    hash = {
      "Marcxml::Person" => {"pe" => ["500$0"], "ks" => ["510$0"], "lit" => ["670$w"], prefix: "pe"},
      "Marcxml::Source" => {"pe" => ["700$0", "100$0"], "ks" => ["710$0", "852$x"], "lit" => ["690$0", "691$0"], prefix: ""},
    }
    id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE)[0]
    id.content = "#{hash[self.class.to_s][:prefix]}#{id.content}"

    hash[self.class.to_s].each do |k,fields|
      next if k == :prefix
      fields.each do |field|
        tag, code = field.split("$")
        links = node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
        links.each {|link| link.content = "#{k}#{link.content}"}
      end

    end
  end
end

