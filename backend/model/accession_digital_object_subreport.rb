class AccessionDigitalObjectSubreport  < AbstractSubreport

  def initialize(parent_report, accession_id, digital_object_type)
    super(parent_report)
    @accession_id = accession_id
    @do_enum = digital_object_type
  end

  def query_string
    "select id, is_representative
        from  instance
        where instance.accession_id = #{db.literal(@accession_id)}
        and instance.instance_type_id = #{db.literal(@do_enum)}"
  end    

  
  def query
    results = db.fetch(query_string)
    contents = []
    results.each do |result|
      result[:is_representative] = result[:is_representative].nil? ? "" : "*"
      dohash = query_digital_object(result[:id])
      result[:dig_obj_id] = dohash[:dig_obj_id]
      result[:dig_obj_title] = dohash[:dig_obj_title]
      contents.push(result)
    end
    contents
  end
  def query_digital_object(instance_id)
    query_string = "select digital_object.digital_object_id as dig_obj_id, title as dig_obj_title
    from digital_object where id in 
    (select digital_object_id 
      from instance_do_link_rlshp where instance_id = #{db.literal(instance_id)})"
    dos = db.fetch(query_string)
    # there should be only one per instance
    dohash = {}
    dos.each_with_index do |dob,i|
      dohash = dob.to_hash
      if i > 0
        break
      end
    end
    return dohash
  end
end
