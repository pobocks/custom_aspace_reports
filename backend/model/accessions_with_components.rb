class AccessionsWithComponents < AbstractReport
  register_report

  def initialize(params, job, db)
    super
    @counter = 0
    @counts = {:resources =>1, :aos => 1, :dos => 1, :conts => 1, :extents => 1}
    @subfields = {:resources => ["identifier", "title"], 
    :aos => ["ref_id", "archival_obj_title"], :dos => ["dig_obj_id", "dig_obj_title","is_representative"], 
    :conts => ["instance_type","container", "container_profile"], 
    :extents => ["extent", "container_summary"]}
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
      title as record_title,
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
  #need to set up repeating columns in first row
  def add_columns(row,subfields, count)
    (1..count).to_a.each do |n|
      subfields.each do |f|
        name = f + "_" + n.to_s
        row[name.to_sym] = ""
      end
    end
  end
  def add_sub_reports(row)
    id = row[:accession_id]
    if @first_row then
      add_columns(row, @subfields[:extents], @counts[:extents])
    end
    content = AccessionExtentsSubreport.new(self,id).get_content
    process_multiples(content, row, :extents)
    if @first_row then
      add_columns(row, @subfields[:resources], @counts[:resources])
    end
    content = AccessionResourcesSubreport.new(self,id).get_content
    process_multiples(content, row, :resources)
    if @first_row then
      add_columns(row, @subfields[:conts], @counts[:conts])
    end
    content = AccessionContainersSubreport.new(self,id, @do_enum).get_content
    process_multiples(content, row, :conts)
    
    content = AccessionArchivalObjectsSubreport.new(self,id).get_content
    process_multiples(content, row, :aos)

    content = AccessionDigitalObjectSubreport.new(self,id, @do_enum).get_content
    process_multiples(content, row, :dos)
    row.delete(:accession_id)
    
    @counter = @counter + 1
    @first_row = false
  end
 
  def process_multiples(content, row, type)
    if !content.nil? then
      content.each_with_index do |c, i|        
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
      hit = false
      results.each do |result|
        row = result.to_hash
        count = row[:numb]
        hit = true
        break if hit
      end    
    elsif symb.to_s = "enum" then 
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
    setup.keys.each do |key|
      count = get_count_results(key,setup[key])
      if !count.nil? and count > 0
        @counts[key] = count
      end
    end
  end

end
