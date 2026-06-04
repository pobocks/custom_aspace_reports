class ResourceCalculatedExtents < AbstractReport
  require 'uri'
  require 'net/http'
  include JSONModel

  register_report( {
    :params => [['resourceids', 'ResourceIds', 'One or more Resource Identifiers (comma separated) of a resource to get containers for']]
  }  )

  def initialize(params, job, db)
    super
    resourceids = params.fetch('resourceids')
    rids = resourceids
    @ids = ""
    # create array for each id, .to_s it
    for id in rids.split(',') do
      @ids += db.literal('["' + id.strip + '",null,null,null]') + ','
    end
    @ids = @ids.chop
  end

  # since we're only  doing a sql query to get the resource.id, we override get_content!

  def get_content
    array = []
    query.each do |result|
      row = {}
      row[:resourcetitle] = result[:resourcetitle]
      row[:resourceidentifier] = result[:resourceidentifier]
      #/repositories/2/resources/5
      url = "/extent_calculator?record_uri=/repositories/#{@repo_id.to_s}/resources/#{result[:id].to_s}"
      uri = "/repositories/#{@repo_id.to_s}/resources/#{result[:id].to_s}"
      parsed = JSONModel.parse_reference(uri)
      RequestContext.open(:repo_id => JSONModel(:repository).id_for(parsed[:repository])) do
        obj = Kernel.const_get(parsed[:type].to_s.camelize)[parsed[:id]]
        ext_cal = ExtentCalculator.new(obj)
        ext_cal =  ext_cal.to_hash
        pp "total calculated? #{ext_cal[:total_extent]} containers : #{ext_cal[:container_count]}"
      end
    end
  end

    #   extent = JSONModel(:extent).new
    #   extent.number = results['total_extent']
    #   if results['units']
    #       units = results['volume'] ? 'cubic_' : 'linear_'
    #       units += results['units']
    #       extent.extent_type = units
    #   end
    #   container_cardinality = results['container_count'] == 1 ?
    #                               t('extent_calculator.container_summary_type._singular') :
    #                               t('extent_calculator.container_summary_type._plural')
    #   extent.container_summary = "(#{results['container_count']} #{container_cardinality})"
    #   pp extent

 

  def query_string
    <<~SOME_SQL
          SELECT id,
                  REPLACE (title,","," ") AS resourcetitle,
                  REPLACE (identifier,","," ") AS resourceidentifier
                  from resource where identifier IN (#{@ids})
        SOME_SQL
  end
end
