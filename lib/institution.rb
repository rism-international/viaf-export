# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[ROOT_DIR + 'lib/*.rb'].each {|file| require file }

module Marcxml
  class Institution < Transformator
    NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}
    include Logging
    @refs = {}
    @@without_siglum = {}
    class << self
      attr_accessor :refs
    end
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [ :make_leader, :replace_square_brackets ]
    end

    def replace_square_brackets
      fields = %w(110$a 410$a 510$a 710$a)
      fields.each do |field|
        tag, code = field.split("$")
        links = node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
        links.each do |link| 
          if link.content.include?("[")
            e = link.content.gsub("[", "(").gsub("]", ")")
            link.content = e
          end
        end
      end

    end

# Records have dot or komma at end
    def fix_dots
      fields = %w(100$a 100$d 240$a 300$a 710$a 700$a 700$d)
      fields.each do |field|
        tag, code = field.split("$")
        links = node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
        links.each {|link| link.content = link.content.gsub(/[\.,:]$/, "")}
      end
    end


  end
end
