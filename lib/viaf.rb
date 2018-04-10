# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[File.dirname(__FILE__) + '../*.rb'].each {|file| require file }

module Marcxml
  class Iccu < Transformator
    NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}
    include Logging
    @refs = {}
    @@without_siglum = {}
    @@isil_codes = YAML.load_file("./utils/isil_codes.yml")
    @ids = YAML.load_file("./ids.yml")
    @relator_codes = YAML.load_file("./lib/unimarc_relator_codes.yml")
    class << self
      attr_accessor :refs, :ids, :relator_codes, :isil_codes, :without_siglum
    end
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [:map, :replace_rism_siglum, :fix_id, :add_original_entry, 
                 #:fix_id, :change_attribution, :prefix_performance,
                 #:split_730, :change_243, :change_593_abbreviation, :change_009, 
                  :concat_personal_name, :remove_whitespace_from_incipit, 
                 #:add_original_entry, :add_material_layer, :fix_incipit_zeros, :change_relator_codes, 
                 #:fix_852, :remove_pipe
      ]
    end

    def replace_rism_siglum
      subfields=node.xpath("//marc:datafield[@tag='852']/marc:subfield[@code='a']", NAMESPACE)
      subfields.each do |sf|
        if @@isil_codes[sf.content]
          sf.content = @@isil_codes[sf.content]      
        else
          unless @@without_siglum[sf.content]
            @@without_siglum[sf.content] = 1
          else
            @@without_siglum[sf.content] += 1
          end
        end
      end
      #uts @@without_siglum

    end

    def change_relator_codes
      px = node.xpath("//marc:subfield[@code='4']", NAMESPACE)
      px.each do |p|
        p.content = BNF.relator_codes[p.content]
      end

    end


    def fix_id
      controlfield = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first
      if ((Integer(controlfield.content) rescue false) == false)
        controlfield.content = Iccu.ids[controlfield.content]
      end
      #TODO find linking field
      datafield = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE).first rescue nil
      if datafield
        datafield.content = Iccu.ids[datafield.content]
      end
      #links = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE)
      #links.each {|link| link.content = link.content.gsub("(OCoLC)", "1")}
    end

    def remove_whitespace_from_incipit
      incipits = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      incipits.each do |incipit|
        sfx = incipit.xpath("marc:subfield", NAMESPACE) rescue nil
        sfx.each do |sf|
          if sf && sf.content
            sf.content = sf.content.strip
          end
        end
      end
    end


    def fix_incipit_zeros
      codes = %w(a b c)
      incipits = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      incipits.each do |incipit|
        codes.each do |code|
          sf = incipit.xpath("marc:subfield[@code='#{code}']", NAMESPACE).first rescue nil
          if sf && sf.content
            sf.content = sf.content.sub(/^0/, "")
          end
        end
      end

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

    def change_009
      cfield = node.xpath("//marc:controlfield[@tag='009']", NAMESPACE).empty? ? nil : node.xpath("//marc:controlfield[@tag='009']", NAMESPACE)
      return 0 unless cfield
      local_id = cfield.first.content
      tag = Nokogiri::XML::Node.new "datafield", node
      tag['tag'] = '035'
      tag['ind1'] = ' '
      tag['ind2'] = ' '
      sfa = Nokogiri::XML::Node.new "subfield", node
      sfa['code'] = 'a'
      sfa.content = local_id
      tag << sfa
      node.root << tag
      cfield.remove
    end


    def insert_773_ref
      if BNF.refs.empty?
        BNF.correspondance
      end
      
      subfields=node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='a']", NAMESPACE)
      return 0 if subfields.empty?
      local_ref = subfields.first.content
      rism_ref = BNF.refs[local_ref]
      sfw = Nokogiri::XML::Node.new "subfield", node
      sfw['code'] = 'w'
      sfw.content = rism_ref
      subfields.first.parent << sfw
    end

    def check_material
      result = Hash.new
      subfield=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if subfield.text=='Collection' || subfield.empty?
        result[:level] = "c"
      else
        result[:level] = "m"
      end
      subfield=node.xpath("//marc:datafield[@tag='762']", NAMESPACE)
      unless subfield.empty?
        result[:level] = "c"
      end

      subfield=node.xpath("//marc:datafield[@tag='773']", NAMESPACE)
      unless subfield.empty?
        result[:level] = "d"
      end

      subfields=node.xpath("//marc:datafield[@tag='593']/marc:subfield[@code='a']", NAMESPACE)
      material = []
      subfields.each do |sf|
        if (sf.text =~ /Ms/) || (sf.text =~ /autog/)
          material << :manuscript
        elsif sf.text =~ /print/
          material << :print
        else
          material << :other
        end
      end
      case
      when material.include?(:manuscript) && material.include?(:print)
        result[:type] = "p"
      when material.include?(:manuscript) && !material.include?(:print)
        result[:type] = "d"
      else
        result[:type] = "c"
      end
      return result
    end

    def change_leader
      leader=node.xpath("//marc:leader", NAMESPACE)[0]
      result=check_material
      code = "n#{result[:type]}#{result[:level]}"
      raise "Leader code #{code} false" unless code.size == 3
      if leader
        leader.content="00000#{code} a2200000   4500"
      else
        leader = Nokogiri::XML::Node.new "leader", node
        leader.content="00000#{code} a2200000   4500"
        node.root.children.first.add_previous_sibling(leader)
      end
      leader
    end


    def change_attribution
      subfield100=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='j']", NAMESPACE)
      subfield700=node.xpath("//marc:datafield[@tag='700']/marc:subfield[@code='j']", NAMESPACE)
      subfield710=node.xpath("//marc:datafield[@tag='710']/marc:subfield[@code='g']", NAMESPACE)
      subfield100.each { |sf| sf.content = convert_attribution(sf.content) }
      subfield700.each { |sf| sf.content = convert_attribution(sf.content) }
      subfield710.each { |sf| sf.content = convert_attribution(sf.content) }
    end

    def convert_attribution(str)
      case str
      when "e"
        return "Ascertained"
      when "z"
        return "Doubtful"
      when "g"
        return "Verified"
      when "f"
        return "Misattributed"
      when "l"
        return "Alleged"
      when "m"
        return "Conjectural"
      else
        return str
      end
    end

    def prefix_performance
      subfield=node.xpath("//marc:datafield[@tag='518']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = "Performance date: #{sf.content}" }
    end

    def split_730
      datafields = node.xpath("//marc:datafield[@tag='730']", NAMESPACE)
      return 0 if datafields.empty?
      datafields.each do |datafield|
        hs = datafield.xpath("marc:subfield[@code='a']", NAMESPACE)
        title = split_hs(hs.map(&:text).join(""))
        hs.each { |sf| sf.content = title[:hs] }
        sfk = Nokogiri::XML::Node.new "subfield", node
        sfk['code'] = 'g'
        sfk.content = "RISM"
        datafield << sfk
        if title[:sub]
          sfk = Nokogiri::XML::Node.new "subfield", node
          sfk['code'] = 'k'
          sfk.content = title[:sub]
          datafield << sfk
        end
        if title[:arr]
          sfk = Nokogiri::XML::Node.new "subfield", node
          sfk['code'] = 'o'
          sfk.content = title[:arr]
          datafield << sfk
        end
      end
    end

    def fix_852
     tags=node.xpath("//marc:datafield[@tag='852']", NAMESPACE)
      if tags.size >= 1
        siglum_field = tags.first.xpath("//marc:subfield[@code='5']", NAMESPACE).first.content rescue nil
        sigl, shelfmark = siglum_field.split(":")
 
        siglum = tags.first
        if siglum.xpath("marc:subfield[@code='a']", NAMESPACE).empty?
          sfa = Nokogiri::XML::Node.new "subfield", node
          sfa['code'] = 'a'
          sfa.content = convert_siglum(sigl)
          siglum << sfa
          sfc = Nokogiri::XML::Node.new "subfield", node
          sfc['code'] = 'c'
          sfc.content = shelfmark
          siglum << sfc
        end
        tags[1..-1].each {|t| t.remove}
      end
      if tags.empty?
        tag = Nokogiri::XML::Node.new "datafield", node
        tag['tag'] = '852'
        tag['ind1'] = ' '
        tag['ind2'] = ' '
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'a'
        sfa.content = "F-Pn"
        tag << sfa
        sfc = Nokogiri::XML::Node.new "subfield", node
        sfc['code'] = 'c'
        sfc.content = "[without shelfmark]"
        tag << sfc
        node.root << tag
      end
    end

    def change_243
      tags=node.xpath("//marc:datafield[@tag='243']", NAMESPACE)
      tags.each do |sf|
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'g'
        sfa.content = "RAK"
        sf << sfa
        tags.attr("tag", "730")
      end
    end

    def remove_pipe
      subfields=node.xpath("//marc:datafield[@tag='240']/marc:subfield[@code='a']", NAMESPACE)
      subfields.each do |sf|
        if sf.content.include?("|")
          sf.content = sf.content.gsub("|", "")
        end
      end

    end


    def change_593_abbreviation
      subfield=node.xpath("//marc:datafield[@tag='593']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_593_abbreviation(sf.content) }
    end

 




    def convert_593_abbreviation(str)
      case str
      when "mw"
        return "Other"
      when "mt"
        return "Treatise, handwritten"
      when "ml"
        return "Libretto, handwritten"
      when "mu"
        return "Treatise, printed"
      when "mv"
        return "unknown"
      when "autograph"
        return "Autograph manuscript"
      when "partly autograph"
        return "Partial autograph"
      when "manuscript"
        return "Manuscript copy"
      when "probably autograph"
        return "Possible autograph manuscript"
      when "mk"
        return "Libretto, printed"
      when "mz"
        return "Music periodical"
      when "4"
        return "Other"
      else
        return str
      end
    end
    
    def convert_siglum(str)
      case str
      when "FR-751131010" 
        return "F-Pnla"
      when "FR-751021003" 
        return "F-Pn"
      when "FR-751131011" 
        return "F-Pnlr"
      when "FR-751041002" 
        return "F-Pa"
      when "FR-751091001" 
        return "F-Po"
      when "FR-751041001" 
        return "F-Pnas"
      when "FR-751041006" 
        return "F-Pnm"
      end
    end




















    

  end
end

