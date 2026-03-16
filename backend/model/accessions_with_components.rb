class AccessionsWithComponents < AbstractReport
  register_report

  def fix_row(row)
    clean_row(row)
    puts row
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
      extent_number,
      extent_type,
      general_note,
      container_summary,
      acquisition_type_id as acquisition_type,
      content_description as description_note,
      inventory
    from accession natural left outer join

      (select
        accession_id as id,
        sum(number) as extent_number,
        GROUP_CONCAT(distinct extent_type_id SEPARATOR ', ') as extent_type,
        GROUP_CONCAT(distinct extent.container_summary SEPARATOR ', ') as container_summary
      from extent
      group by accession_id) as extent_cnt

    where accession.repo_id = #{db.literal(@repo_id)}"
  end

  def clean_row(row)
    ReportUtils.fix_identifier_format(row, :accession_number)
    ReportUtils.get_enum_values(row, [:acquisition_type, :extent_type])
    ReportUtils.fix_extent_format(row)
    ReportUtils.fix_boolean_fields(row, %i[restrictions_apply
                                           access_restrictions use_restrictions
                                           rights_transferred
                                           acknowledgement_sent])
  end

  def add_sub_reports(row)
    id = row[:accession_id]
    content = AccessionResourcesSubreport.new(self,id).get_content
    idn = ''
    ttl = ''
    content.each_with_index do |el, inx|
      if inx > 0
        idn += " | "
        ttl += " | "
      end
      idn += el[:identifier]
      ttl += el[:title]
    end
    row[:identifier] = idn
    row[:title] = ttl
    puts row
    row.delete(:accession_id)
  end

  def identifier_field
    :accession_number
  end
end
