class AccessionsWithComponents < AbstractReport
  register_report

  def initialize(params, job, db)
    super
    @counter = 0
    @counts = {:resources =>1, :aos => 1, :dos => 1, :conts => 1, :extents => 1, :docs => 1}
    @subfields = {:resources => ["resource_id", "resource_title"], 
    :aos => ["ao_id","ref_id", "archival_obj_title"], 
    :dos => ["do_id","do_ref_id", "dig_obj_title","is_representative"], 
    :conts => ["instance_type","container", "container_profile"], 
    :extents => ["extent", "container_summary"],
    :docs => ["external_document_title", "external_document_location"]}
    @multifields = {}  # going to contain all the column names for possible multiples
    setup_cell_counts()
    @first_row = true
  end
  
  def fix_row(row)
    clean_row(row)
    add_sub_reports(row)
  end


  def query
    results = db.fetch(query_string)
    info[:number_of_accessions] = results.count
    results
  end

  def query_string
    "select
      id as accession_id,
      identifier as accession_number,
      title as accession_title,
      accession_date as accession_date,
      general_note,
      acquisition_type_id as acquisition_type,
      content_description as description_note,
      inventory
    from accession"
  end

  def clean_row(row)
    ReportUtils.fix_identifier_format(row, :accession_number)
    ReportUtils.get_enum_values(row, [:acquisition_type])
    ReportUtils.fix_boolean_fields(row, %i[restrictions_apply
                                           access_restrictions use_restrictions
                                           rights_transferred
                                           acknowledgement_sent])
  end

  def record_type
    'accession'
  end

  def add_sub_reports(row)
    id = row[:accession_id]
    content = AccessionExtentsSubreport.new(self,id).get_content
    process_multiples(content, row, :extents)
    content = AccessionResourcesSubreport.new(self,id).get_content
    if !content.nil?
      content.each do |c|
        c[:resource_id] = c[:identifier]
        c[:resource_title] = c[:title]
      end
    end
    process_multiples(content, row, :resources)
    content = AccessionContainersSubreport.new(self,id, @do_enum).get_content
    process_multiples(content, row, :conts)
    content = AccessionArchivalObjectsSubreport.new(self,id).get_content
    process_multiples(content, row, :aos)
    content = AccessionDigitalObjectSubreport.new(self,id, @do_enum).get_content
    process_multiples(content, row, :dos)
    content = ExternalDocumentSubreport.new(self,id).get_content
    if !content.nil? then
      content.each do |c|
        c[:external_document_title] = c[:record_title]
        c[:external_document_location] = c[:location]
      end
    end
    process_multiples(content, row, :docs)
    row.delete(:accession_id)
  end
 
  def process_multiples(content, row, type)
    # count for type of content
    row[(type.to_s + " count").to_sym] = content.nil? ? 0 : content.size()

    # create all the cells for this type and row
    (1..@counts[type]).to_a.each do |n|
      @subfields[type].each do |f|
        row[(f.to_s + "_" + n.to_s).to_sym] = ""
      end
    end
    if !content.nil? then
      content.each_with_index do |c, i|
        cntr = i     
        @subfields[type].each do |f|
          row[(f.to_s + "_" + (i + 1).to_s).to_sym] = c[f.to_sym]
        end
      end
    end    
  end
  
  def identifier_field
    :accession_number
  end

  def get_count_results(symb, qry)
    count = 1
    results = db.fetch(qry + "  order by numb desc limit 1")
    if !results.nil? and results.count > 0 then
      results.each do |result|
        row = result.to_hash
        count = row[:numb]
        break
      end    
    elsif symb.to_s == "enum" then 
      raise 'Unable to identify "digital_object" enumeration value'
    end
    return count
  end

  def setup_cell_counts
    # grab the max number of container instances, digital object instances, and archival objects per accession id
    setup = {}
    setup[:enum] = "select id as numb from enumeration_value where value=\"digital_object\" and enumeration_id in (select id from enumeration where name=\"instance_instance_type\")"
    @do_enum = get_count_results(:enum, "select id as numb from enumeration_value where value=\"digital_object\" and enumeration_id in (select id from enumeration where name=\"instance_instance_type\")")
    # if there's no enum value for digital_object, we nope out of this entire report
    setup[:resources] = "select count(resource.id) as numb from resource, spawned_rlshp where spawned_rlshp.resource_id = resource.id group by spawned_rlshp.accession_id"
    setup[:aos] = "select count(archival_object_id) as numb from accession_component_links_rlshp where accession_id is not NULL group by accession_id"
    setup[:dos] = "select count(instance_type_id) as numb  from instance where accession_id is not NULL and instance_type_id = #{db.literal(@do_enum)} group by accession_id"
    setup[:conts] = "select count(instance_type_id) as numb  from instance where accession_id is not NULL and instance_type_id != #{db.literal(@do_enum)} group by accession_id"
    setup[:extents] = "select count(id) as numb from extent where accession_id is not NULL group by accession_id"
    setup[:docs] = "select count(id) as numb from external_document where accession_id is not NULL group by accession_id"
    setup.keys.each do |key|
      count = get_count_results(key,setup[key])
      if !count.nil? and count > 0
        @counts[key] = count
      end
    end
  end

end
