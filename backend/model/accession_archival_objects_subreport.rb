class AccessionArchivalObjectsSubreport < AbstractSubreport
  register_subreport('instance', ['accession'])

  def initialize(parent_report, accession_id)
    super(parent_report)
    @accession_id = accession_id
  end

  def query
    results = db.fetch(query_string)
    results.each do |result|
      puts result
    end

  end
  def query_string
    "select 
      ref_id, 
      title as archival_obj_title
      from archival_object 
      where id in 
        (select archival_object_id from accession_component_links_rlshp 
          where accession_id = #{db.literal(@accession_id)}) ;"
  end
end
