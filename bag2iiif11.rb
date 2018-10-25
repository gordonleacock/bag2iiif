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

    # puts "The bag files are:"
    # @files.each { |f| puts f }

    # puts "The tag files are:"
    # @tag_files.each { |f| puts f }

    # puts "The tag manifest files are:"
    # @tagmanifest_files.each { |f| puts f }

    # puts "The manifest files are:"
    # @manifest_files.each { |f| puts f }

    puts "There are #{@files_count} bag files, #{@tag_files.count} tag files, and #{@manifest_files.count} manifest_files."
  end

end


class Metsie

  attr_reader :xml_file, :doc, :header, :common, :collection, :is_part_of, \
  :object_mdref, :filegroups, :structure, :file_nodes, :filename, :get_image_str

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

  # Get header metadata
  def header
    node = @doc.xpath('.//METS:metsHdr')
    return nil if node.length == 0 # no metadata
      
    putsd "GETTING 'METS HEADER' METADATA"
    header = {}
    header['node'] = 'mets header'
    header['agent'] = {}

    ["CREATEDATE", "LASTMODDATE", "RECORDSTATUS"].each do |attribute|
      header[attribute] = node.xpath("@#{attribute}")
      putsd "header #{attribute}: #{header[attribute]}"
    end


    ["ROLE", "TYPE"].each do |attribute|
      agent_node = node.xpath(".//METS:agent")
      header['agent'][attribute] = agent_node.xpath("@#{attribute}")
      putsd "header agent #{attribute}: #{header['agent'][attribute]}"
    end

    header['agent']['name'] = node.xpath(".//METS:agent/METS:name").text
    putsd "header agent name: #{header['agent']['name']}"
    
    header
  end

  # Get common metadata
  def common
    node = @doc.xpath('.//METS:xmlData')
    return nil if node.length == 0 # no metadata
    
    putsd "GETTING 'COMMON' METADATA"
    common = {}
    common['node'] = 'mets common'

    ["type", "conformsTo", "identifier", "title", "date", "description"].each do |term|
      common[term] = node.xpath(".//dcterms:#{term}").text
      putsd "common #{term}: #{common[term]}"
    end

    common
  end

  # Get collection metadata
  def collection
    node = @doc.xpath('//METS:dmdSec[@ID="DMDCOLLECTIONS"]')
    return nil if node.length == 0 # no metadata

    putsd "GETTING 'DMD COLLECTION' METADATA"
    collection = {}
    collection['node'] = 'mets collection'

    memberOf_node = node.xpath('.//dcam:memberOf')

    collection["memberOf"] = memberOf_node.xpath("@xlink:href")
    
    collection["memberOf"] = memberOf_node.text if collection["memberOf"].length == 0

    putsd "collection memberOf: #{collection["memberOf"]}"
    
    collection
  end

  # Get partOf metadata [Roger said the definition of this element was in flux.]
  # def is_part_of

  #   #SHORTCURCUIT FOR NOW
  #   puts "NO 'IS PART OF' METADATA AVAILABLE"
  #   return nil

  #   node = @doc.xpath('//METS:dmdSec[@ID="DMDPARTS"]/METS:mdWrap')

  #   if node.length == 0
  #     puts "NO 'IS PART OF' METADATA AVAILABLE"
  #     return nil
  #   end
  
  #   putsd "GETTING 'IS PART OF' METADATA"
  #   is_part_of = {}
  #   is_part_of['node'] = 'mets is_part_of'

  #   ["isPartOf", "type"].each do |term|
  #     is_part_of[term] = node.xpath(".//dcterms:#{term}").text
  #     putsd "is_part_of term #{term}: #{is_part_of[term]}"
  #   end
    
  #   is_part_of
  # end

  # Get object metadata via mdref
  def object_mdref
    node = @doc.xpath('//METS:dmdSec/METS:mdRef[@LABEL="Object Metadata"]')
    return nil if node.length == 0 # no metadata

    putsd "GETTING 'MDREF OBJECT' METADATA"
    object_mdref = {}
    object_mdref['node'] = 'mets object_mdref'

    node.each_with_index do |obj, obj_index|
      object_mdref[obj_index] = {}
      ["LOCTYPE", "MDTYPE", "LABEL", "XPTR", "xlink:href"].each do |attribute| 
        object_mdref[obj_index][attribute] = obj.xpath("@#{attribute}")
        putsd "object_mdref number #{obj_index} has attribute #{attribute}: #{object_mdref[obj_count][attribute]}"
      end
    end
    object_mdref
  end

  # Get object metadata via mdwrap - DO WE NEED THIS?
  def object_mdwrap
    puts "NO 'MDWRAP OBJECT' METADATA AVAILABLE"
    return nil
  end


 # get filegroups
  def filegroups
    node = @doc.xpath('.//METS:fileSec/METS:fileGrp')
    return nil if node.length == 0 # no metadata

    putsd "GETTING 'FILEGROUPS and FILES' METADATA"
    filegroups = {}
    filegroups['filegroups_total'] = node.count
    filegroups['node'] = 'mets filegroups'

    putsd "- Filegroups: #{filegroups}", true

    node.each do |fg_node|
      fgroup = {}
      fgroup['attrs'] = {}

      ["ID", "USE"].each do |attribute|
        fgroup['attrs'][attribute] = fg_node.at_xpath("@#{attribute}")
        putsd "-- fgroup attribute #{attribute}: #{fg_node.at_xpath("@#{attribute}")} ", true
      end

      fgroup["#{fgroup['attrs']['ID']}"] = files_nested(fg_node, "#{fgroup['attrs']['ID']}")

      filegroups < fgroup
    end
    
  end

  # get files in a filegroup
  def files_nested(fg_node, fg_id)
    node = fg_node.xpath('.//METS:file')
    files = {}
    files['files_total'] = node.count

    putsd "filegroup with ID #{fg_id} has #{files['files_total']} files"

    node.each do |file_node|

      f = {}
      f['attrs'] = {}
      ["ID", "SEQ", "CHECKSUM", "CHECKSUMTYPE", "SIZE", "CREATED", "MIMETYPE"].each do |attribute|
        f['attrs'][attribute] = file_node.xpath("@#{attribute}")
        putsd "--- fgroup id #{fg_id} file id #{f['attrs']['ID']} attribute #{attribute}: #{f['attrs'][attribute]}"
      end
      
      # Add file location
      loc_path = file_node.xpath("./METS:FLocat")

      f['fileloc'] = {}

      if f['attrs']["MIMETYPE"] == "text/xml"
        ["LOCTYPE", "xlink:href"].each do |attribute|
          f['fileloc'][attribute] = loc_path.xpath("@#{attribute}").first
          putsd "--- fgroup id #{fg_id} file id #{f['attrs']['ID']} location attribute #{attribute}: #{f['fileloc'][attribute]}"
        end
      else
        ["LOCTYPE", "xlink:href"].each do |attribute|
          f['fileloc'][attribute] = loc_path.xpath("@#{attribute}")
          putsd "--- fgroup id #{fg_id} file id #{f['attrs']['ID']} location attribute #{attribute}: #{f['fileloc'][attribute]}"
        end
      end

      if file_node.count > 1
        putsd "NESTED FILES FOR file #{f['attrs']['ID']} file_node.count is #{file_node.count}"
        files_nested(file_node, fg_id)
      else
        files < f
      end
    end

    files
  end

  def structure
    node = @doc.xpath('.//METS:structMap')
    return nil if node.length == 0 # no metadata

    putsd "GETTING 'STRUCTMAP' METADATA"
    putsd "smaps count is #{node.count}"

    smaps = {}
    smaps['smaps_total'] = node.count
    smaps['node'] = 'mets smaps'
    putsd "smaps['smaps_total']: #{smaps['smaps_total']}"

    node.each do |sm_node|
      smap = {}
      smap['attrs'] = {}

      smap['attrs']['TYPE'] = sm_node.xpath("@TYPE")
      putsd "- smap attribute TYPE: #{smap['attrs']['TYPE']} "

      smap['labels'] = labels(sm_node, smap['attrs']['TYPE'])
      smaps < smap
    end

    smaps
  end 

  def labels(sm_node, sm_type)
    nodes = sm_node.xpath('./METS:div[@LABEL]')

    return nil if node.length == 0 # no metadata

    putsd "'STRUCTMAP LABELS' METADATA AVAILABLE"
    putsd "-- structMap type #{sm_type} label_divs count: #{nodes.count}"

    labels = {}
    labels['total_labels'] = nodes.count

    nodes.each do |ln_node|
      label = {}
      label['attrs'] = {}

      ["LABEL", "TYPE"].each do |attribute|
        label['attrs'][attribute] = ln_node.xpath("@#{attribute}")
        putsd "--- structMap type #{sm_type} label attribute #{attribute}: #{label['attrs'][attribute]}"
      end

      putsd "  "
      label['orders'] = orders(ln_node)
      labels < label
    end

    labels
  end

  def orders(ln)
    node = ln.xpath('./METS:div[@ORDER]')
    return nil if node.length == 0 # no metadata

    orders = {}
    putsd "---- structMap orders count: #{node.count}"
    orders['total_orders'] = node.count

    node.each do |order_node|
      order = {}
      order['attrs'] = {}

      ["ORDER", "ORDERLABEL", "TYPE"].each do |attribute|
        order['attrs'][attribute]  = order_node.xpath("@#{attribute}") # if order_node.xpath("@#{attribute}").length > 0
        putsd "--- order attribute #{attribute}: #{order['attrs'][attribute]}"

        order['fptrs'] = fptrs(order_node)
        orders < order
      end
    end

    orders
  end

  def fptrs(order_node)
    node = order_node.xpath('./METS:fptr')

    # "NO 'STRUCTMAP LABELS ORDERS FPTRS' METADATA AVAILABLE"
    return nil if node.length == 0 # no metadata

    fptrs = {}
    fptrs['total_fptrs'] = node.count
    putsd "-- fptrs node count: #{fptrs['total_fptrs']}"

    node.each do |fp_node|
      fptr = {}
      fptr['attrs'] = {}
      fptr['attrs']['FILEID'] = fp_node.xpath('@FILEID')
      putsd "--- fptr attribute FILEID: #{fptr['attrs']['FILEID']}"

      fptrs < fptr
    end

    fptrs
  end

 # get filegroups
  def get_filegroups_by_use
    node = @doc.xpath('.//METS:fileSec/METS:fileGrp')

    # "NO 'FILEGROUPS' METADATA AVAILABLE"
    return nil if node.length == 0 # no metadata


    putsd "GETTING 'FILEGROUPS' METADATA"

    filegroups = {}
    filegroups['filegroups_total'] = node.count

    putsd "- Filegroups: #{filegroups}", true

    node.each do |fg_node|
      use = fg_node.at_xpath("@USE")
      filegroups[use] = {} # either bitonal or encoded_text
      filegroups[use]["ID"] = fg_node.at_xpath("@ID")
      filegroups[use]["node"] = fg_node
      putsd "-- fgroup with USE #{use} has ID: #{fgroup[use]["ID"]} ", true
    end
    
    filegroups
  end

  def coll_id
    memof = "memberof: #{self.collection["memberOf"]}"
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

    # we will build canvases by iterating over fileids in mets
    # get file pointers or fptrs where the parent is a 'physical' structMap
    physical_sMap_fptrs = @doc.xpath(".//METS:structMap[@TYPE='physical']//METS:fptr")

    # get the fileids of those pointers
    canvas_files = bitonal_files
    
    mani = Jbuilder.encode do |json|
      json.set! :@id, "http://localhost:3000/#{self.manifest_name}"
      json.set! :@context, "http://iiif.io/api/presentation/2/context.json"
      json.set! :@type, "sc:Manifest"
      json.label "#{self.common['title']}"
      json.description "#{self.common['type']}"
      json.attribution 'University of Michigan Library Digital Collections'
      json.metadata Jbuilder.new.array!(['']) do |metadata|      
        json.label "Role"
        json.value "#{self.header['agent']['ROLE']}"
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
    # get file pointers or fptrs where the parent is a 'physical' structMap
    physical_sMap_fptrs = @doc.xpath(".//METS:structMap[@TYPE='physical']//METS:fptr")

    # get the fileids of those pointers
    physical_sMap_files = physical_sMap_fptrs.xpath("./@FILEID")

    # get only the fileid of those pointer that belong to the filegroup with use 'bitonal'
    bitonal_files = []
    physical_sMap_files.each do | fid |
      file_node = @doc.xpath(".//METS:fileGrp/METS:file[@ID=\"#{fid}\"]")
      fgroup = file_node.xpath("ancestor::METS:fileGrp")
      fgroup_use = fgroup.xpath("@USE")

      bitonal_files << fid if (fgroup_use.to_s == "bitonal")
    end

    bitonal_files
  end


  # Get canvas and file data from mets for a single file
  # Use the file to get data from both it's METS:structMap ancestor and it's METS:fileGrp ancestor
  # NOTE: Assumes the files is in a bitonal file group but we get data from the other file in
  # our subject file's <METS:structMap TYPE="physical">/<METS:div ORDER="00000001" TYPE="page"> group
  def canvas_doc(fid)

    #### DATA FROM METS:structMap ####

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
    
    putsd "Order info for file id #{fid}, order: #{order}, label: #{order_label}, type: #{order_type}, count: #{order_count}"


    #### DATA FROM METS:fileGrp ####

    # get file node from METS:fileGrp for this fptr id
    filegroup_file_node = @doc.xpath(".//METS:fileGrp/METS:file[@ID=\"#{fid}\"]")

    #  get matching node
    matching_order_node = @doc.xpath(".//METS:fileGrp/METS:file[@ID=\"#{matching_order_fid}\"]")

    # seq_test = file_node.xpath("@SEQ")

    # if seq_test.length == 0 # if seq.length is zero, get file_node from filegroup 2
    #   file_node = @doc.xpath(".//METS:fileSec/METS:fileGrp/METS:file/METS:file[@ID=\"#{fid}\"]")
    # end
    # puts "For id #{id} file_node class is: #{file_node.class}"
    # puts "For id #{id} file_node is: #{file_node}"

    # Get METS:fileGrp ID and USE attributes
    fgroup = filegroup_file_node.xpath("ancestor::METS:fileGrp")
    fgroup_id = fgroup.xpath("@ID")
    fgroup_use = fgroup.xpath("@USE")

    seq = filegroup_file_node.xpath("@SEQ")
    checksum = filegroup_file_node.xpath("@CHECKSUM")
    checksum_type = filegroup_file_node.xpath("@CHECKSUMTYPE")
    size = filegroup_file_node.xpath("@SIZE")
    created = filegroup_file_node.xpath("@CREATED")
    mimetype = filegroup_file_node.xpath("@MIMETYPE")

    # Here we get the locations and xlinks for the image and text file nodes
    flocat_node = filegroup_file_node.xpath("./METS:FLocat")
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

    # create hash to pass to manifest
    canv = {}
    canv['img_order']          = img_order.to_s
    canv['img_width']          = img_width.to_i
    canv['img_height']         = img_height.to_i
    canv['canvas_width']       = (img_width*1.2).to_i
    canv['canvas_height']      = (img_height*1.2).to_i
    canv['img_filename']       = img_filename.to_s
    canv['order_group_label']  = order_group_label.to_s
    canv['img_anno_id']        = img_anno_id.to_i
    canv['img_anno_text']      = img_anno_text  # Not used yet


    puts "In canvas doc canvas width x height: #{canv['canvas_width']} x #{canv['canvas_height']}"

    return canv
  end


  def show
    # puts "---------------- METS DATA ----------------"

    mystuff = self.complete_manifest
    # @header = self.header
    # show_nested_hash(@header).reverse_each
    # puts "----------------"

    # @common = self.common
    # show_nested_hash(@common)
    # puts "----------------"
    
    # @collection = self.collection
    # show_nested_hash(@collection)        
    # puts "----------------"
    
    # @is_part_of = self.is_part_of
    # show_nested_hash(@is_part_of)
    # puts "----------------"

    # @object_mdref = self.object_mdref
    # show_nested_hash(@object_mdref)
    # puts "----------------" 

    # @filegroups = self.filegroups
    # show_nested_hash(@filegroups)
    # puts "----------------" 

    # @structure = self.structure
    # show_nested_hash(@structure)
    # puts "----------------" 

  end

  def show_nested_hash(hash, parent = nil)
    # puts "hash has class #{hash.class}"
    if hash.nil?
      puts "Nil hash param value in show_nested_hash"
      return
    end

    if hash == 0
      puts "Zero hash param value in show_nested_hash"
      return
    end

    hash.each do |key, value|
      if value.kind_of?(Hash) 
        show_nested_hash(value, key)
      else
        puts "#{parent} #{key}: #{value}"
      end
    end
  end

  def putsd( dstr, dbug = false )
    puts dstr if dbug
  end

end # Metsie


opts = Optimist::options do
  opt :bag, "File name of bag to process", :type => :string, :deafult => "taj1895.0001.001"
  opt :bags_dir, "Bag directory", :type => :string,  :default =>  "../bags/"
  opt :manifest_dir, "Manifests output directory", :type => :string,  :default =>  "../manifests/"
end

puts "opts are: #{opts}"

bag_at = opts[:bags_dir] + opts[:bag]

puts "bag_at: #{bag_at}"
baggie = Baggie.new(bag_at)

metsie = Metsie.new(baggie, opts[:manifest_dir])

metsie.show
