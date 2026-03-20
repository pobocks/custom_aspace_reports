class AccessionsWithComponents < AbstractReport
  register_report

  def initialize(params, job, db)
    super
    @counter = 0
    @counts = {:resources =>1, :aos => 1, :dos => 1, :insts => 1, :extents => 1}
    @subfields = {:resources => ["resource_id", "resource_title"], 
    :aos => ["ref_id", "archival_obj_title"], :dos => ["dig_obj_id", "dig_obj_title", "dig_obj_type"], 
    :insts => ["instance_type","container", "container_profile", "container_2", "container_3"], 
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
    (0..count).to_a.each do |n|
      subfields.each do |f|
        name = f + "_" + (n = 1).to_s
        row[name.to_sym] = ""
      end
    end
  end
  def add_sub_reports(row)
    id = row[:accession_id]
    puts "FIRSt ROW?"
    puts @first_row
    if @first_row then
      add_columns(row, @subfields[:extents], @counts[:extents])
      puts row
    end
    content = AccessionExtentsSubreport.new(self,id).get_content
    puts "EXTENT CONTENT"
    puts content
    content.each_with_index do |c,i|
      row[("extent" + "_" + (i + 1).to_s).to_sym] = c[:extent]
      row[("container_summary" + "_" + (i + 1).to_s).to_sym] = c[:container_summary]
    end
    puts row
    # content = AccessionResourcesSubreport.new(self,id).get_content
    # idn = ''
    # ttl = ''
    # if !content.nil? then
    #   content.each_with_index do |el, inx|
    #     if inx > 0
    #       idn += " | "
    #       ttl += " | "
    #     end
    #     idn += el[:identifier]
    #     ttl += el[:title]
    #   end
    # end
    # row[:resource_identifier] = idn
    # row[:resource_title] = ttl
    content = AccessionContainersSubreport.new(self,id, @do_enum).get_content
    puts "CONTAINER"
    puts content
    
    @counter = @counter + 1
    @first_row = false
    puts "ROW"
    puts row
    content = AccessionArchivalObjectsSubreport.new(self,id).get_content
    row.delete(:accession_id)
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
    setup[:resurces] = "select count(resource.id) as numb from resource, spawned_rlshp where spawned_rlshp.resource_id = resource.id group by spawned_rlshp.accession_id"
    setup[:aos] = "select count(archival_object_id) as numb from accession_component_links_rlshp where accession_id is not NULL group by accession_id"
    setup[:dos] = "select count(instance_type_id) as numb  from instance where accession_id is not NULL and instance_type_id = #{db.literal(@do_enum)} group by accession_id"
    setup[:insts] = "select count(instance_type_id) as numb  from instance where accession_id is not NULL and instance_type_id != #{db.literal(@do_enum)} group by accession_id"
    setup[:extents] = "select count(id) as numb from extent where accession_id is not NULL group by accession_id"
    setup.keys.each do |key|
      @counts[key] = get_count_results(key,setup[key])
    end

  end
end
