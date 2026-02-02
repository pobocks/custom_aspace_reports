class ArchivalObjectsAssociatedWithDigitalObjects < AbstractReport
  # find digital objects given a search pattern, then display the archival objects IDs

  register_report( {
      :params => [['doidsearch', 'DOIDSearch', 'Digital Object ID Wildcard']]
  } ) 

  def initialize(params, job, db)
    super

    doidsearch=params.fetch('doidsearch')
    @doidsearch = doidsearch.gsub('*', '%')
   
  end

  def query_string
    <<~SOME_SQL
      select         
        digital_object.digital_object_id as identifier,
        digital_object.title as DO_title,
        digital_object.digital_object_type_id as object_type,
        group_concat(distinct ao.ref_id separator '~~') as AOID,        
        group_concat(distinct ao.title separator ',,,') as AONAME 
        from digital_object 
        left outer join instance_do_link_rlshp idlr
          on idlr.digital_object_id = digital_object.id 
        left outer join instance 
          on instance.id = idlr.instance_id 
        left outer join archival_object ao
          on ao.id = instance.archival_object_id 
        where digital_object.digital_object_id like #{db.literal(@doidsearch)}  
        group by digital_object.id
    SOME_SQL
  end
end
