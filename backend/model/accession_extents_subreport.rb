class AccessionExtentsSubreport < AbstractSubreport

  def initialize(parent_report, accession_id)
    super(parent_report)
    @accession_id = accession_id
  end

  def clean_row(row)
    ReportUtils.get_enum_values(row, [:extent_type])
    ReportUtils.fix_extent_format(row)
    puts "EXTENT CLeAN ROW"
    puts row
  end

  def query_string
    "select number as extent_number, extent_type_id as extent_type, container_summary 
    from extent 
    where accession_id = #{db.literal(@accession_id)}"
  end
end
