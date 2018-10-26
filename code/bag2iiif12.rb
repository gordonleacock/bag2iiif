require 'bagit'
require 'nokogiri'
require 'optimist'
require 'fastimage' # used for image dimensions
require 'jbuilder'  # see https://github.com/rails/jbuilder

class Baggie

  attr_reader :name, :dir, :data_dir, :files, :files_count, :tag_files, :tagmanifest_files, :manifest_files, \
  :fixed, :info_txt_file, :info, :consistent, :complete, :valid, :name, :mets_file, :files_xml

  def initialize(baggie_dir)
    @bag = BagIt::Bag.new(baggie_dir)

    abort "Code aborted: Bag is not valid " if !@bag.valid?
    abort "Code aborted: Bag is not consistent " if !@bag.consistent?
    abort "Code aborted: Bag is not complete " if !@bag.complete?

    open_bag

  end

  def open_bag
    puts "Opening bag: #{@name}"

    name_split1 = @bag.bag_dir.split("/")
    @name = name_split1.last
    
    # puts "NAME IS #{self.name}"
    # puts "bag public_methods is #{bag.public_methods}"

    @dir = "#{@bag.bag_dir}"
    @data_dir = "#{@bag.data_dir}"
    @files = []
    @files = @bag.bag_files
    @files_count = @bag.bag_files.count
    @tag_files = []
    @tag_files = @bag.tag_files
    @tagmanifest_files = []
    @tagmanifest_files = @bag.tagmanifest_files
    @manifest_files = []
    @manifest_files = @bag.manifest_files
    @fixed = "#{@bag.fixed?}"
    @info_txt_file = "#{@bag.bag_info_txt_file}"
    @info = "#{@bag.bag_info}"
    @consistent = "#{@bag.consistent?}"
    @complete = "#{@bag.complete?}"
    @valid = "#{@bag.valid?}"

    @mets_file = @data_dir + "/#{@name}/#{@name}.mets.xml"
    @files_xml = @data_dir + "/#{@name}/files/#{@name}.xml"

    # puts "The mets file is #{@mets_file}"
    # puts "The files xml file is #{@files_xml}"

    puts "There are #{@files_count} bag files, #{@tag_files.count} tag files, and #{@manifest_files.count} manifest_files."
  end

end


class Metsie

  attr_reader :xml_file, :doc, :file_nodes, :filename

  def initialize(bag, manifest_out_dir)
    putsd "--- BAG XML FOLLOWS ---"

    @bag = bag
    @manifest_out_dir = manifest_out_dir

    abort "Code aborted: In class Metsie @bag.mets_file is nil" if @bag.mets_file.nil?
    abort "Code aborted: In class Metsie @manifest_out_dir is nil" if @manifest_out_dir.nil?

    puts "Reading mets for bag #{bag.name}"

    # Get mets data for bag
    @xml_file = File.read(@bag.mets_file)

    @doc = Nokogiri::XML.parse(@xml_file) do |config|
      config.noblanks
    end

    abort "Code aborted: WARNING xml_file and/or doc is NIL" if @xml_file.nil? || @doc.nil?

    puts "Reading files xml for bag #{bag.name}"

    # puts "files xml from bag is: #{@bag.files_xml}"

    # Get files xml for bag
    @files_xml = File.read(@bag.files_xml)

    @files_xml_doc = Nokogiri::XML.parse(@files_xml) do |config|
      config.noblanks
    end

    # puts"@files_xml_doc: #{@files_xml_doc}"

    abort "Code aborted: WARNING files_xml and/or files_doc is NIL" if @files_xml.nil? || @files_xml_doc.nil?

    # puts "@files_doc is >>#{@files_doc}<<<"

  end

  def mets_attr(xp, attr)
    node = @doc.xpath("#{xp}")
    node.xpath("@#{attr}")  
  end

  def mets_body(xp)
    @doc.xpath("#{xp}").text
  end

  def obj_id
    node = @doc.xpath('METS:mets')
    node.xpath("@OBJID")
  end

  def header_role
    mets_attr('.//METS:metsHdr//METS:agent', "ROLE")
  end

  def common_type
    mets_body('.//METS:xmlData//dcterms:type')
  end

  def common_title
    mets_body('.//METS:xmlData//dcterms:title')
  end

  def collection_member_of_xlink
    mets_body('//METS:dmdSec[@ID="DMDCOLLECTIONS"]//dcam:memberOf')
  end

  def coll_id
    memof = collection_member_of_xlink
    memof.split(':').last
  end

  def manifest_name
    bag_name_with_underscores = @bag.name.gsub(/\./, '_')
    # puts "bag_name_with_underscores: #{bag_name_with_underscores}"
    "manifest_" + bag_name_with_underscores + '.json'
  end

  def ldadd(attribute_name, attribute_value, attribute_separator="" )
    puts " \"" + attribute_name + "\": \"" + attribute_value + "\"" + attribute_separator
    " \"" + attribute_name + "\": \"" + attribute_value + "\"" + attribute_separator
  end

  def complete_manifest

    # puts "Manifest is:"
    # puts self.iiif_manifest
    bag_name_with_underscores = @bag.name.gsub(/\./, '_')
    # puts "bag_name_with_underscores: #{bag_name_with_underscores}"
    manifest_name = "#{@manifest_out_dir}manifest_" + bag_name_with_underscores + '.json'
    # puts "manifest_name: #{manifest_name}"
    File.open(manifest_name, "w"){ |manifest_file| manifest_file.puts self.iiif_manifest}
    puts "New manifest writen to file #{manifest_name}"
  end

  def iiif_manifest

    # get file pointers or fptrs where the parent is a 'physical' structMap
    # get the fileids of those pointers
    canvas_files = bitonal_files
    
    mani = Jbuilder.encode do |json|
      json.set! :@id, "http://localhost:3000/#{self.manifest_name}"
      json.set! :@context, "http://iiif.io/api/presentation/2/context.json"
      json.set! :@type, "sc:Manifest"
      json.label "#{self.common_title}"
      json.description "#{self.common_type}"
      json.attribution 'University of Michigan Library Digital Collections'
      json.metadata Jbuilder.new.array!(['']) do |metadata|      
        json.label "Role"
        json.value "#{self.header_role}"
      end
      json.license "http://rightsstatements.org/vocab/CNE/1.0/"
      json.logo "http://localhost:3000/logo.jpg"
      json.sequences Jbuilder.new.array!(['']) do |sequence|
        json.set! :@id, "http://localhost:3000/#{self.coll_id}:#{@bag.name}/sequence/1"
        json.set! :@type, "sc:Sequence"
        json.label "Current Page Order"
        json.viewingDirection "left-to-right"
        json.viewingHint "paged"
        json.canvases Jbuilder.new.array!(canvas_files) do |fid|
          canv = canvas_doc(fid)
          json.set! :@id, "http://localhost:3000/#{canv['img_filename']}/canvas/1"
          json.set! :@type, "sc:Canvas"
          json.set! :@context, "http://iiif.io/api/presentation/2/context.json"
          json.label "#{canv['order_group_label']}"
          json.width canv['canvas_width']
          json.height canv['canvas_height']
          json.images Jbuilder.new.array!(['']) do |image|
            json.set! :@id, "https://quod.lib.umich.edu/cgi/t/text/api/tile/#{self.coll_id}:#{self.obj_id}:#{canv['img_order']}/annotation/#{canv['image_anno_id']}"
            json.set! :@type, "sc:annotation"
            json.motivation "sc:painting"
            json.on "http://localhost:3000/#{canv['image_filename']}/canvas/1"
            json.resource do
              json.set! :@id, "https://quod.lib.umich.edu/cgi/t/text/api/tile/#{self.coll_id}:#{self.obj_id}:#{canv['img_order']}"
              json.set! :@type, "dctypes:Image"
              json.format "image/jpeg"
              json.width  canv['img_width']
              json.height canv['img_height']
              json.service do
                json.set! :@id, "https://quod.lib.umich.edu/cgi/t/text/api/tile/#{self.coll_id}:#{self.obj_id}:#{canv['img_order']}"
                json.set! :@context, "http://iiif.io/api/image/2/context.json"
                json.profile "http://iiif.io/api/image/2/level1.json"
              end
            end
          end
        end
      end
    end

    mani
  end

  def bitonal_files
    # 1. get file pointers or fptrs where the parent is a 'physical' structMap 2. get the fileids of those pointers
    physical_sMap_files = @doc.xpath(".//METS:structMap[@TYPE='physical']//METS:fptr/@FILEID")

    # 2. get only the fileid of those pointer that belong to the filegroup with use 'bitonal'
    bitonal_files = []

    physical_sMap_files.each do | fid |
      file_node = @doc.xpath(".//METS:fileGrp/METS:file[@ID=\"#{fid}\"]")
      fgroup_use = file_node.xpath("ancestor::METS:fileGrp/@USE")

      bitonal_files << fid if (fgroup_use.to_s == "bitonal")
    end

    bitonal_files
  end


  def get_struct_map_data(fid)
    #### DATA FROM METS:structMap for this FILEID ####

    struct_file_node =  @doc.xpath(".//METS:structMap[@TYPE='physical']//METS:fptr[@FILEID=\"#{fid}\"]")

    # get label info for this METS:structMap
    label_node = struct_file_node.xpath("../..")
    struct_group_label = label_node.xpath('@LABEL')

    # get order info for this METS:fptr
    order_node = struct_file_node.xpath("..")
    img_order = order = order_node.xpath('@ORDER')
    order_label = order_node.xpath('@ORDERLABEL')
    order_type = order_node.xpath('@TYPE')

    # get matching file node
    # get FILEID for matching file in <METS:div ORDER=...>
    order_count = order_node.xpath("METS:fptr").count
    if order_count == 2
      matching_order_fid = nil
      order_files = order_node.xpath("./METS:fptr")
      order_files_ids = order_files.xpath("@FILEID")
      order_files_ids.each { |id| matching_order_fid = id if id != fid }
    end

    # get label for order group
    order_group_label = order_label.length > 0 ? order_label : order

    # following roger https://quod.lib.umich.edu/cgi/t/text/api/manifest/amjewess:taj1895.0001.001
    # calculate an annotation id
    int_order = "0d#{order}".to_i
    img_anno_number = int_order - 1
    img_anno_id = img_anno_number.to_i
    
    putsd "Order info for file id #{fid}, order: #{order}, order label: #{order_label}, type: #{order_type}, count: #{order_count}"

    return order, matching_order_fid, order_group_label, img_anno_id

  end

  def get_filegroup_data(fid)
    #### DATA FROM METS:fileGrp for this FILEID ####

    # grad stuct map data since we need some items
    order, matching_order_fid, order_group_label, img_anno_id = get_struct_map_data(fid)


    # get file node from METS:fileGrp for this fptr id
    fg_file_node = @doc.xpath(".//METS:fileGrp/METS:file[@ID=\"#{fid}\"]")

    #  get matching node from order node
    matching_order_node = @doc.xpath(".//METS:fileGrp/METS:file[@ID=\"#{matching_order_fid}\"]")

    # Get METS:fileGrp ID and USE attributes
    fgroup = fg_file_node.xpath("ancestor::METS:fileGrp")
    fgroup_id = fgroup.xpath("@ID")
    fgroup_use = fgroup.xpath("@USE")

    seq = fg_file_node.xpath("@SEQ")
    checksum = fg_file_node.xpath("@CHECKSUM")
    checksum_type = fg_file_node.xpath("@CHECKSUMTYPE")
    size = fg_file_node.xpath("@SIZE")
    created = fg_file_node.xpath("@CREATED")
    mimetype = fg_file_node.xpath("@MIMETYPE")

    # Here we get the locations and xlinks for the image and text file nodes
    flocat_node = fg_file_node.xpath("./METS:FLocat")
    image_loctype = flocat_node.xpath("@LOCTYPE").to_s
    image_xlink = flocat_node.xpath("@xlink:href")
    img_filename = image_xlink.to_s.split('/').last

    flocat_node = matching_order_node.xpath("./METS:FLocat")
    anno_text_loctype = flocat_node.xpath("@LOCTYPE").to_s
    anno_text_xlink = flocat_node.xpath("@xlink:href")

    putsd "For file id #{fid}, filename: #{filename}, seq: #{seq}, checksum: #{checksum}, checksum_type: #{checksum_type}, size: #{size}, created: #{created}, mimetype: #{mimetype}, image_xlink: #{image_xlink}, anno_text_xlink: #{anno_text_xlink}, fgroup_id: #{fgroup_id}, fgroup_use: #{fgroup_use}"

    # Defaults for conditional values below
    img_dimensions = [0, 0]
    img_width = img_height = 0
    img_anno_text = ""

    # get image info
    if mimetype.to_s.downcase.include? "image"
      img_temp_loc      = "#{@bag.data_dir}/#{@bag.name}/#{image_xlink}"

      img_dimensions    = FastImage.size(img_temp_loc) # array of [width, height]
      img_width         = img_dimensions.first
      img_height        = img_dimensions.last

      img_type          = FastImage.type(img_temp_loc)

      putsd "For file id #{fid} named #{filename} where mimetype includes 'image', image width: #{img_width}, image height: #{img_height}, image dimensions: #{img_dimensions}, image type: #{img_type}"
    end

    # get possible annotation text. @files_xml_doc points to xml for files in bag data/files directory
    if anno_text_xlink.to_s.downcase.include? "xpointer"
      unwrapped_anno_text_xlink = anno_text_xlink.to_s.gsub("#xpointer(", "")
      unwrapped_anno_text_xlink = unwrapped_anno_text_xlink.gsub(")", "")
      unwrapped_anno_text_xlink = unwrapped_anno_text_xlink.gsub("DIV", "DIV1") #fix for DIV
      img_anno_text             = @files_xml_doc.xpath(unwrapped_anno_text_xlink)
    end

    return img_width, img_height, img_filename, img_anno_text

  end

  # Get canvas and file data from mets for a single file
  # Use the file to get data from both it's METS:structMap ancestor and it's METS:fileGrp ancestor
  # NOTE: Assumes the files is in a bitonal file group but we get data from the other file in
  # our subject file's <METS:structMap TYPE="physical">/<METS:div ORDER="00000001" TYPE="page"> group
  def canvas_doc(fid)

    order, matching_order_fid, order_group_label, img_anno_id = get_struct_map_data(fid)


    img_width, img_height, img_filename, img_anno_text = get_filegroup_data(fid)

    # create hash to pass to manifest
    canv = {}
    canv['img_order']          = order.to_s
    canv['img_width']          = img_width.to_i
    canv['img_height']         = img_height.to_i
    canv['canvas_width']       = (img_width*1.2).to_i
    canv['canvas_height']      = (img_height*1.2).to_i
    canv['img_filename']       = img_filename.to_s
    canv['order_group_label']  = order_group_label.to_s
    canv['img_anno_id']        = img_anno_id.to_i
    canv['img_anno_text']      = img_anno_text  # Not used yet

    return canv
  end

  def putsd( dstr, dbug = false )
    puts dstr if dbug
  end

end # Metsie


opts = Optimist::options do
  opt :bag, "File name of bag to process", :type => :string, :default => "taj1895.0001.001"
  opt :bags_dir, "Bag directory", :type => :string,  :default =>  "../bags/"
  opt :manifest_dir, "Manifests output directory", :type => :string,  :default =>  "../manifests/"
end

puts "opts are: #{opts}"

bag_at = opts[:bags_dir] + opts[:bag]

puts "bag_at: #{bag_at}"
baggie = Baggie.new(bag_at)

metsie = Metsie.new(baggie, opts[:manifest_dir])

metsie.complete_manifest
