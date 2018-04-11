# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[File.dirname(__FILE__) + '../*.rb'].each {|file| require file }

module Marcxml
  class Viaf < Transformator
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
      @methods = [ :map, :make_leader, :replace_square_brackets ]
    end


    def make_leader
      leader_string = "00000nz a2200037n 45 0"
      tag = Nokogiri::XML::Node.new "leader", node
      tag.content = leader_string
      node.root.children.first.add_previous_sibling(tag)
    end

    def replace_square_brackets

    end

    def add_original_entry
      oce = node.xpath("//marc:controlfield[@tag='003']", NAMESPACE).first rescue nil
      if oce
        tag = Nokogiri::XML::Node.new "datafield", node
        tag['tag'] = '856'
        tag['ind1'] = ' '
        tag['ind2'] = ' '
        sfu = Nokogiri::XML::Node.new "subfield", node
        sfu['code'] = 'u'
        sfu.content = oce.content rescue ""
        tag << sfu
        sfz = Nokogiri::XML::Node.new "subfield", node
        sfz['code'] = 'z'
        sfz.content = "Original catalogue entry"
        tag << sfz
        node.root << tag
      end
    end

  end
end
